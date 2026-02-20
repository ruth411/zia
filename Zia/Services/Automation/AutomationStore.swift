//
//  AutomationStore.swift
//  Zia
//
//

import Combine
import Foundation

/// Persists saved automations to ~/.zia/automations.json.
/// Each automation is a named prompt that can be run on demand or on a schedule.
class AutomationStore: ObservableObject {

    // MARK: - Published

    @Published private(set) var automations: [Automation] = []

    // MARK: - Storage

    private let fileURL: URL = {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent(".zia/automations.json")
    }()

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - CRUD

    /// Create a new automation
    @discardableResult
    func create(name: String, prompt: String, schedule: Automation.Schedule? = nil) -> Automation {
        let automation = Automation(
            name: name,
            prompt: prompt,
            schedule: schedule,
            enabled: true
        )
        automations.append(automation)
        save()
        return automation
    }

    /// Update an existing automation
    func update(id: String, name: String? = nil, prompt: String? = nil, schedule: Automation.Schedule? = nil, enabled: Bool? = nil) -> Bool {
        guard let index = automations.firstIndex(where: { $0.id == id }) else { return false }
        if let name = name { automations[index].name = name }
        if let prompt = prompt { automations[index].prompt = prompt }
        if let schedule = schedule { automations[index].schedule = schedule }
        if let enabled = enabled { automations[index].enabled = enabled }
        save()
        return true
    }

    /// Delete an automation by ID
    @discardableResult
    func delete(id: String) -> Bool {
        let count = automations.count
        automations.removeAll { $0.id == id }
        if automations.count != count {
            save()
            return true
        }
        return false
    }

    /// Get an automation by name (case-insensitive)
    func find(name: String) -> Automation? {
        automations.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Get all enabled automations with schedules
    func scheduledAutomations() -> [Automation] {
        automations.filter { $0.enabled && $0.schedule != nil }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            automations = try JSONDecoder().decode([Automation].self, from: data)
            print("AutomationStore: Loaded \(automations.count) automations")
        } catch {
            print("AutomationStore: Failed to load: \(error)")
        }
    }

    private func save() {
        do {
            // Ensure ~/.zia/ directory exists
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let data = try JSONEncoder().encode(automations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("AutomationStore: Failed to save: \(error)")
        }
    }
}

// MARK: - Automation Model

struct Automation: Identifiable, Codable {
    let id: String
    var name: String
    var prompt: String
    var schedule: Schedule?
    var enabled: Bool
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        prompt: String,
        schedule: Schedule? = nil,
        enabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.schedule = schedule
        self.enabled = enabled
        self.createdAt = createdAt
    }

    /// Schedule for recurring automations
    struct Schedule: Codable {
        let frequency: Frequency
        let timeOfDay: String? // "HH:mm" format, e.g. "09:00"

        enum Frequency: String, Codable, CaseIterable {
            case daily
            case weekdays
            case weekly
            case hourly
        }
    }
}
