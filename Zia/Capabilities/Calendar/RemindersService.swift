//
//  RemindersService.swift
//  Zia
//
//

import EventKit
import Foundation

/// Service wrapping EventKit for reminders operations
class RemindersService {

    private let eventStore = EKEventStore()

    /// Request reminders access
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToReminders()
    }

    /// Get incomplete reminders
    func getIncompleteReminders() async throws -> [EKReminder] {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Get all reminders
    func getAllReminders() async throws -> [EKReminder] {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Create a new reminder
    func createReminder(
        title: String,
        dueDate: Date?,
        notes: String?
    ) throws -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let due = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: due
            )
        }

        try eventStore.save(reminder, commit: true)
        return reminder
    }

    /// Mark a reminder as completed
    func completeReminder(identifier: String) throws -> Bool {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            return false
        }
        item.isCompleted = true
        try eventStore.save(item, commit: true)
        return true
    }

    /// Format reminders as JSON string for Claude
    static func formatReminders(_ reminders: [EKReminder]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        let formatted: [[String: Any]] = reminders.map { r in
            var dict: [String: Any] = [
                "title": r.title ?? "Untitled",
                "is_completed": r.isCompleted,
                "priority": r.priority,
                "identifier": r.calendarItemIdentifier
            ]
            if let notes = r.notes, !notes.isEmpty {
                dict["notes"] = notes
            }
            if let dueComps = r.dueDateComponents,
               let due = Calendar.current.date(from: dueComps) {
                dict["due_date"] = dateFormatter.string(from: due)
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
