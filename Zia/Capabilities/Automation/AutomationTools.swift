//
//  AutomationTools.swift
//  Zia
//
//

import Foundation

// MARK: - Create Automation

/// Tool that lets Claude create saved automations via natural language
struct CreateAutomationTool: Tool {
    let name = "create_automation"
    let store: AutomationStore

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Create a saved automation that runs a prompt on a schedule or on demand. Example: 'Every weekday at 9am, check calendar and summarize my day.'",
            inputSchema: ToolInputSchema(
                properties: [
                    "name": PropertySchema(type: "string", description: "Short name for the automation (e.g. 'Morning Summary')"),
                    "prompt": PropertySchema(type: "string", description: "The full prompt to send to Zia when this automation runs"),
                    "frequency": PropertySchema(type: "string", description: "How often to run: 'daily', 'weekdays', 'weekly', 'hourly', or 'manual' (on-demand only)", enumValues: ["daily", "weekdays", "weekly", "hourly", "manual"]),
                    "time": PropertySchema(type: "string", description: "Time of day to run in HH:mm format (e.g. '09:00'). Optional for hourly/manual.")
                ],
                required: ["name", "prompt"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        guard let name = input["name"]?.value as? String else {
            throw ToolError.missingParameter("name")
        }
        guard let prompt = input["prompt"]?.value as? String else {
            throw ToolError.missingParameter("prompt")
        }

        let frequency = input["frequency"]?.value as? String ?? "manual"
        let time = input["time"]?.value as? String

        let schedule: Automation.Schedule?
        if frequency != "manual",
           let freq = Automation.Schedule.Frequency(rawValue: frequency) {
            schedule = Automation.Schedule(frequency: freq, timeOfDay: time)
        } else {
            schedule = nil
        }

        let automation = store.create(name: name, prompt: prompt, schedule: schedule)

        let scheduleDesc = schedule.map { "\($0.frequency.rawValue)\(time.map { " at \($0)" } ?? "")" } ?? "manual (on-demand)"
        return "{\"success\": true, \"id\": \"\(automation.id)\", \"name\": \"\(automation.name)\", \"schedule\": \"\(scheduleDesc)\"}"
    }
}

// MARK: - List Automations

struct ListAutomationsTool: Tool {
    let name = "list_automations"
    let store: AutomationStore

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "List all saved automations with their names, schedules, and enabled status.",
            inputSchema: ToolInputSchema(properties: [:])
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let automations = store.automations
        if automations.isEmpty {
            return "{\"automations\": [], \"message\": \"No automations saved yet.\"}"
        }

        let items = automations.map { a -> String in
            let schedule = a.schedule.map { "\($0.frequency.rawValue)\($0.timeOfDay.map { " at \($0)" } ?? "")" } ?? "manual"
            return "{\"id\": \"\(a.id)\", \"name\": \"\(jsonEscape(a.name))\", \"prompt\": \"\(jsonEscape(String(a.prompt.prefix(50))))\", \"schedule\": \"\(schedule)\", \"enabled\": \(a.enabled)}"
        }

        return "{\"automations\": [\(items.joined(separator: ", "))], \"count\": \(automations.count)}"
    }
}

// MARK: - Run Automation

struct RunAutomationTool: Tool {
    let name = "run_automation"
    let store: AutomationStore

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Run a saved automation by name. This executes the automation's prompt immediately.",
            inputSchema: ToolInputSchema(
                properties: [
                    "name": PropertySchema(type: "string", description: "Name of the automation to run")
                ],
                required: ["name"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        guard let name = input["name"]?.value as? String else {
            throw ToolError.missingParameter("name")
        }

        guard let automation = store.find(name: name) else {
            return "{\"success\": false, \"error\": \"Automation '\(jsonEscape(name))' not found. Use list_automations to see available automations.\"}"
        }

        // Return the prompt to be executed — the agent loop will process it
        return "{\"success\": true, \"automation_name\": \"\(jsonEscape(automation.name))\", \"prompt_to_execute\": \"\(jsonEscape(automation.prompt))\"}"
    }
}

// MARK: - Delete Automation

struct DeleteAutomationTool: Tool {
    let name = "delete_automation"
    let store: AutomationStore

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Delete a saved automation by name.",
            inputSchema: ToolInputSchema(
                properties: [
                    "name": PropertySchema(type: "string", description: "Name of the automation to delete")
                ],
                required: ["name"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        guard let name = input["name"]?.value as? String else {
            throw ToolError.missingParameter("name")
        }

        guard let automation = store.find(name: name) else {
            return "{\"success\": false, \"error\": \"Automation '\(jsonEscape(name))' not found.\"}"
        }

        store.delete(id: automation.id)
        return "{\"success\": true, \"deleted\": \"\(jsonEscape(automation.name))\"}"
    }
}
