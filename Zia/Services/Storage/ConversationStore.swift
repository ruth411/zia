//
//  ConversationStore.swift
//  Zia
//
//

import Foundation

/// Persistent storage for conversation history using JSON files on disk.
/// Data is stored in ~/Library/Application Support/com.ruthwikdovala.Zia/conversations/
class ConversationStore {

    // MARK: - Types

    /// A saved conversation session
    struct Conversation: Codable, Identifiable {
        let id: String
        var messages: [Message]
        let createdAt: Date
        var updatedAt: Date
    }

    // MARK: - Properties

    private let directory: URL
    private let maxConversationsOnDisk = 100

    // MARK: - Initialization

    init(directory: URL = Configuration.Storage.conversationsDirectory) {
        self.directory = directory
        ensureDirectoryExists()
    }

    // MARK: - Public Methods

    /// Save a conversation to disk
    func save(_ conversation: Conversation) throws {
        let fileURL = directory.appendingPathComponent("\(conversation.id).json")
        let data = try JSONEncoder().encode(conversation)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Load all conversations, sorted by most recent first
    func loadAll() throws -> [Conversation] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }

        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" }

        var conversations: [Conversation] = []
        for file in files {
            do {
                let data = try Data(contentsOf: file)
                let conversation = try JSONDecoder().decode(Conversation.self, from: data)
                conversations.append(conversation)
            } catch {
                print("ConversationStore: Skipping corrupt file \(file.lastPathComponent): \(error)")
            }
        }

        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Load the most recent N messages across all conversations (for AI context injection)
    func loadRecentMessages(limit: Int = 50) throws -> [Message] {
        let conversations = try loadAll()
        var allMessages: [Message] = []

        for conversation in conversations {
            allMessages.append(contentsOf: conversation.messages)
            if allMessages.count >= limit { break }
        }

        return Array(allMessages.prefix(limit))
    }

    /// Load the current (most recent) conversation, or create a new one
    func loadOrCreateCurrent() throws -> Conversation {
        let conversations = try loadAll()

        // If there's a conversation from today, reuse it
        if let latest = conversations.first {
            let calendar = Calendar.current
            if calendar.isDateInToday(latest.updatedAt) {
                return latest
            }
        }

        // Create a new conversation
        return Conversation(
            id: UUID().uuidString,
            messages: [],
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    /// Delete old conversations beyond the limit
    func compact() throws {
        let conversations = try loadAll()
        if conversations.count > maxConversationsOnDisk {
            let toDelete = conversations.suffix(from: maxConversationsOnDisk)
            for conversation in toDelete {
                let fileURL = directory.appendingPathComponent("\(conversation.id).json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// Delete all stored conversations
    func deleteAll() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directory.path) {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - Private

    private func ensureDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
