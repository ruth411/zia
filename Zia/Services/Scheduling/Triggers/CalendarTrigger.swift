//
//  CalendarTrigger.swift
//  Zia
//
//

import EventKit
import Foundation

/// Thread-safe store for calendar event notification tracking
private actor NotifiedEventStore {
    private var notifiedEvents = Set<String>()

    func contains(_ id: String) -> Bool { notifiedEvents.contains(id) }
    func insert(_ id: String) { notifiedEvents.insert(id) }
}

/// Checks for upcoming calendar events and notifies 10 minutes before meetings.
struct CalendarTrigger: ContextTrigger {

    let id = "calendar_upcoming"
    let name = "Upcoming Meeting Alert"
    let checkInterval: TimeInterval = 60 // Check every minute

    private let calendarService: CalendarService
    /// Thread-safe tracking of which events we've already notified about
    private static let eventStore = NotifiedEventStore()

    init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }

    func evaluate() async -> ProactiveNotification? {
        // Request access silently — if denied, just return nil
        guard (try? await calendarService.requestAccess()) == true else { return nil }

        let now = Date()
        let lookAhead = now.addingTimeInterval(10 * 60) // 10 minutes ahead

        let events = calendarService.getEvents(from: now, to: lookAhead)

        for event in events {
            let identifier = event.eventIdentifier ?? UUID().uuidString

            // Skip if already notified
            guard await !Self.eventStore.contains(identifier) else { continue }

            // Only notify for events starting in the next 10 minutes (not already started)
            guard event.startDate > now else { continue }

            let minutesUntil = Int(event.startDate.timeIntervalSince(now) / 60)

            await Self.eventStore.insert(identifier)

            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let timeStr = formatter.string(from: event.startDate)

            var body = "Starting at \(timeStr) (\(minutesUntil) min from now)"
            if let location = event.location, !location.isEmpty {
                body += "\nLocation: \(location)"
            }

            return ProactiveNotification(
                title: event.title ?? "Upcoming Event",
                body: body,
                category: .calendar,
                actionURL: event.url?.absoluteString
            )
        }

        return nil
    }
}
