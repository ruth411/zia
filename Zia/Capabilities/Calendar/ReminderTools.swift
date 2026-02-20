//
//  ReminderTools.swift
//  Zia
//
//

import EventKit
import Foundation

/// Tool: reminders_list
struct RemindersListTool: Tool {
    let name = "reminders_list"
    let remindersService: RemindersService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "List the user's reminders. By default shows only incomplete reminders.",
            inputSchema: ToolInputSchema(
                properties: [
                    "show_completed": PropertySchema(
                        type: "boolean",
                        description: "Whether to show all reminders including completed ones. Defaults to false."
                    )
                ]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let granted = try await remindersService.requestAccess()
        guard granted else {
            throw ToolError.permissionDenied("Reminders access not granted. Please enable Reminders access in System Settings > Privacy & Security.")
        }

        let showCompleted = input.optionalBool("show_completed")
        let reminders: [EKReminder]

        if showCompleted {
            reminders = try await remindersService.getAllReminders()
        } else {
            reminders = try await remindersService.getIncompleteReminders()
        }

        return "{\"reminders\": \(RemindersService.formatReminders(reminders))}"
    }
}

/// Tool: reminders_create
struct RemindersCreateTool: Tool {
    let name = "reminders_create"
    let remindersService: RemindersService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Create a new reminder. Requires a title. Optionally set a due date and notes.",
            inputSchema: ToolInputSchema(
                properties: [
                    "title": PropertySchema(type: "string", description: "Reminder title"),
                    "due_datetime": PropertySchema(type: "string", description: "Due date in YYYY-MM-DDTHH:MM:SS format (optional)"),
                    "notes": PropertySchema(type: "string", description: "Additional notes (optional)")
                ],
                required: ["title"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let granted = try await remindersService.requestAccess()
        guard granted else {
            throw ToolError.permissionDenied("Reminders access not granted")
        }

        let title = try input.requiredString("title")

        var dueDate: Date?
        if let dueDateStr = input.optionalString("due_datetime") {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            dueDate = df.date(from: dueDateStr)
        }

        let reminder = try remindersService.createReminder(
            title: title,
            dueDate: dueDate,
            notes: input.optionalString("notes")
        )

        return "{\"success\": true, \"identifier\": \(jsonEscape(reminder.calendarItemIdentifier)), \"title\": \(jsonEscape(title))}"
    }
}

/// Tool: reminders_complete
struct RemindersCompleteTool: Tool {
    let name = "reminders_complete"
    let remindersService: RemindersService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Mark a reminder as completed by its identifier.",
            inputSchema: ToolInputSchema(
                properties: [
                    "identifier": PropertySchema(type: "string", description: "The reminder identifier")
                ],
                required: ["identifier"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let granted = try await remindersService.requestAccess()
        guard granted else {
            throw ToolError.permissionDenied("Reminders access not granted")
        }

        let id = try input.requiredString("identifier")
        let completed = try remindersService.completeReminder(identifier: id)
        return "{\"success\": \(completed)}"
    }
}
