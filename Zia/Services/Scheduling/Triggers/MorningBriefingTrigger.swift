//
//  MorningBriefingTrigger.swift
//  Zia
//
//

import EventKit
import Foundation

/// On first activation after 5 AM, summarizes today's calendar + reminders + weather.
struct MorningBriefingTrigger: ContextTrigger {

    let id = "morning_briefing"
    let name = "Morning Briefing"
    let checkInterval: TimeInterval = 300 // Check every 5 minutes

    private let calendarService: CalendarService
    private let remindersService: RemindersService

    /// Track if we've already sent today's briefing.
    /// nonisolated(unsafe) — evaluate() is only ever called from the scheduler's serial queue.
    nonisolated(unsafe) private static var lastBriefingDate: Date?

    init(calendarService: CalendarService, remindersService: RemindersService) {
        self.calendarService = calendarService
        self.remindersService = remindersService
    }

    func evaluate() async -> ProactiveNotification? {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)

        // Only trigger between 5 AM and 10 AM
        guard hour >= 5 && hour < 10 else { return nil }

        // Only trigger once per day
        if let lastDate = Self.lastBriefingDate,
           calendar.isDate(lastDate, inSameDayAs: now) {
            return nil
        }

        // Build briefing
        var lines: [String] = []

        // Calendar events
        if (try? await calendarService.requestAccess()) == true {
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            let events = calendarService.getEvents(from: now, to: endOfDay)

            if events.isEmpty {
                lines.append("No events today")
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                lines.append("\(events.count) event\(events.count == 1 ? "" : "s") today")
                for event in events.prefix(3) {
                    let time = formatter.string(from: event.startDate)
                    lines.append("  \(time) — \(event.title ?? "Event")")
                }
                if events.count > 3 {
                    lines.append("  +\(events.count - 3) more")
                }
            }
        }

        // Reminders
        if (try? await remindersService.requestAccess()) == true {
            let reminders = (try? await remindersService.getIncompleteReminders()) ?? []
            let dueTodayCount = reminders.filter { reminder in
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return calendar.isDate(dueDate, inSameDayAs: now)
            }.count

            if dueTodayCount > 0 {
                lines.append("\(dueTodayCount) reminder\(dueTodayCount == 1 ? "" : "s") due today")
            }
        }

        guard !lines.isEmpty else { return nil }

        Self.lastBriefingDate = now

        return ProactiveNotification(
            title: "Good Morning",
            body: lines.joined(separator: "\n"),
            category: .briefing
        )
    }
}
