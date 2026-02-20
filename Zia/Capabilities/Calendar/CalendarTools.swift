//
//  CalendarTools.swift
//  Zia
//
//

import EventKit
import Foundation

/// Tool: calendar_get_events
struct CalendarGetEventsTool: Tool {
    let name = "calendar_get_events"
    let calendarService: CalendarService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Get calendar events for a specific date or date range. Returns events with title, time, location, and notes.",
            inputSchema: ToolInputSchema(
                properties: [
                    "date": PropertySchema(
                        type: "string",
                        description: "Date to get events for in YYYY-MM-DD format. Defaults to today."
                    ),
                    "end_date": PropertySchema(
                        type: "string",
                        description: "Optional end date for range query in YYYY-MM-DD format. If omitted, returns events for the single date."
                    )
                ]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let granted = try await calendarService.requestAccess()
        guard granted else {
            throw ToolError.permissionDenied("Calendar access not granted. Please enable Calendar access in System Settings > Privacy & Security.")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startDate: Date
        if let dateStr = input.optionalString("date"),
           let parsed = dateFormatter.date(from: dateStr) {
            startDate = Calendar.current.startOfDay(for: parsed)
        } else {
            startDate = Calendar.current.startOfDay(for: Date())
        }

        let endDate: Date
        if let endStr = input.optionalString("end_date"),
           let parsed = dateFormatter.date(from: endStr) {
            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: parsed)) else {
                throw ToolError.executionFailed("Failed to compute end date from: \(endStr)")
            }
            endDate = nextDay
        } else {
            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: startDate) else {
                throw ToolError.executionFailed("Failed to compute end date")
            }
            endDate = nextDay
        }

        let events = calendarService.getEvents(from: startDate, to: endDate)

        if events.isEmpty {
            return "{\"events\": [], \"message\": \"No events found for the specified date range.\"}"
        }

        return "{\"events\": \(CalendarService.formatEvents(events))}"
    }
}

/// Tool: calendar_create_event
struct CalendarCreateEventTool: Tool {
    let name = "calendar_create_event"
    let calendarService: CalendarService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Create a new calendar event. Requires title and start time. Always confirm with the user before creating.",
            inputSchema: ToolInputSchema(
                properties: [
                    "title": PropertySchema(type: "string", description: "Event title"),
                    "start_datetime": PropertySchema(type: "string", description: "Start date and time in YYYY-MM-DDTHH:MM:SS format"),
                    "end_datetime": PropertySchema(type: "string", description: "End date and time in YYYY-MM-DDTHH:MM:SS format. Defaults to 1 hour after start."),
                    "location": PropertySchema(type: "string", description: "Event location (optional)"),
                    "notes": PropertySchema(type: "string", description: "Event notes (optional)")
                ],
                required: ["title", "start_datetime"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let granted = try await calendarService.requestAccess()
        guard granted else {
            throw ToolError.permissionDenied("Calendar access not granted")
        }

        let title = try input.requiredString("title")
        let startStr = try input.requiredString("start_datetime")

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        guard let start = df.date(from: startStr) else {
            throw ToolError.invalidParameter("start_datetime", expected: "YYYY-MM-DDTHH:MM:SS format")
        }

        let end: Date
        if let endStr = input.optionalString("end_datetime"),
           let parsed = df.date(from: endStr) {
            end = parsed
        } else {
            end = start.addingTimeInterval(3600)
        }

        let event = try calendarService.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            notes: input.optionalString("notes"),
            location: input.optionalString("location")
        )

        return "{\"success\": true, \"event_id\": \(jsonEscape(event.eventIdentifier ?? "")), \"title\": \(jsonEscape(title))}"
    }
}

/// Tool: calendar_delete_event
struct CalendarDeleteEventTool: Tool {
    let name = "calendar_delete_event"
    let calendarService: CalendarService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Delete a calendar event by its identifier. Always confirm with the user before deleting.",
            inputSchema: ToolInputSchema(
                properties: [
                    "event_id": PropertySchema(type: "string", description: "The event identifier to delete")
                ],
                required: ["event_id"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let granted = try await calendarService.requestAccess()
        guard granted else {
            throw ToolError.permissionDenied("Calendar access not granted")
        }

        let eventId = try input.requiredString("event_id")
        let deleted = try calendarService.deleteEvent(identifier: eventId)

        return "{\"success\": \(deleted), \"event_id\": \(jsonEscape(eventId))}"
    }
}
