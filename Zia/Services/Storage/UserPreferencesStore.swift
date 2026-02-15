//
//  UserPreferencesStore.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation

/// Persistent user preferences that the AI learns over time.
/// Stored as JSON at ~/Library/Application Support/com.ruthwikdovala.Zia/preferences.json
class UserPreferencesStore {

    // MARK: - Types

    struct UserPreferences: Codable {
        var preferredName: String?
        var musicTaste: [String]
        var communicationStyle: String?
        var customPreferences: [String: String]
        var lastUpdated: Date

        static var empty: UserPreferences {
            UserPreferences(
                preferredName: nil,
                musicTaste: [],
                communicationStyle: nil,
                customPreferences: [:],
                lastUpdated: Date()
            )
        }
    }

    // MARK: - Properties

    private let fileURL: URL
    private var cached: UserPreferences?

    // MARK: - Initialization

    init(fileURL: URL = Configuration.Storage.preferencesFile) {
        self.fileURL = fileURL
        ensureDirectoryExists()
    }

    // MARK: - Public Methods

    /// Load user preferences from disk
    func load() -> UserPreferences {
        if let cached = cached { return cached }

        guard let data = try? Data(contentsOf: fileURL),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return .empty
        }

        cached = prefs
        return prefs
    }

    /// Save user preferences to disk
    func save(_ preferences: UserPreferences) throws {
        var prefs = preferences
        prefs.lastUpdated = Date()
        let data = try JSONEncoder().encode(prefs)

        // Ensure parent directory exists
        ensureDirectoryExists()

        try data.write(to: fileURL, options: .atomic)
        cached = prefs
    }

    /// Update a single preference key
    func updatePreference(key: String, value: String) throws {
        var prefs = load()
        prefs.customPreferences[key] = value
        try save(prefs)
    }

    /// Set the user's preferred name
    func setPreferredName(_ name: String) throws {
        var prefs = load()
        prefs.preferredName = name
        try save(prefs)
    }

    /// Add a music genre preference
    func addMusicTaste(_ genre: String) throws {
        var prefs = load()
        if !prefs.musicTaste.contains(genre) {
            prefs.musicTaste.append(genre)
            try save(prefs)
        }
    }

    /// Generate a summary string for injection into AI system prompt
    func generateContextSummary() -> String? {
        let prefs = load()
        var parts: [String] = []

        if let name = prefs.preferredName {
            parts.append("The user's name is \(name).")
        }
        if !prefs.musicTaste.isEmpty {
            parts.append("Music preferences: \(prefs.musicTaste.joined(separator: ", ")).")
        }
        if let style = prefs.communicationStyle {
            parts.append("Preferred communication style: \(style).")
        }
        for (key, value) in prefs.customPreferences {
            parts.append("\(key): \(value).")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Delete all preferences
    func deleteAll() throws {
        try? FileManager.default.removeItem(at: fileURL)
        cached = nil
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
