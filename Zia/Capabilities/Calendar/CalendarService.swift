//
//  CalendarService.swift
//  Zia
//
//

import EventKit
import Foundation

/// Service wrapping EventKit for calendar operations
class CalendarService {

    private let eventStore = EKEventStore()

    /// Request calendar access
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToEvents()
    }

    /// Get events for a date range
    func getEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        return eventStore.events(matching: predicate)
    }

    /// Create a new calendar event
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String?,
        location: String?
    ) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
        return event
    }

    /// Delete an event by identifier
    func deleteEvent(identifier: String) throws -> Bool {
        guard let event = eventStore.event(withIdentifier: identifier) else {
            return false
        }
        try eventStore.remove(event, span: .thisEvent)
        return true
    }

    /// Format events as JSON string for Claude
    static func formatEvents(_ events: [EKEvent]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let formatted: [[String: Any]] = events.map { event in
            var dict: [String: Any] = [
                "title": event.title ?? "Untitled",
                "start": dateFormatter.string(from: event.startDate),
                "end": dateFormatter.string(from: event.endDate),
                "is_all_day": event.isAllDay,
                "identifier": event.eventIdentifier ?? ""
            ]
            if let location = event.location, !location.isEmpty {
                dict["location"] = location
            }
            if let notes = event.notes, !notes.isEmpty {
                dict["notes"] = notes
            }
            return dict
        }

        if let data = try? JSONSerialization.data(withJSONObject: formatted, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }
}
