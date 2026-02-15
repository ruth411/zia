//
//  SearchIndex.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation
import SQLite3

/// SQLite FTS5 wrapper for full-text search over conversation messages.
/// Uses the built-in SQLite C API — no external dependencies.
class SearchIndex {

    // MARK: - Types

    struct SearchResult {
        let conversationId: String
        let messageId: String
        let role: String
        let content: String
        let timestamp: Date
        let bm25Score: Double
    }

    // MARK: - Properties

    private let dbPath: URL
    private var db: OpaquePointer?

    // MARK: - Initialization

    init(dbPath: URL = Configuration.Storage.searchDatabaseFile) {
        self.dbPath = dbPath
    }

    deinit {
        close()
    }

    // MARK: - Open / Close

    /// Open the SQLite database and create the FTS5 table if needed
    func open() throws {
        // Ensure parent directory exists
        let dir = dbPath.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let status = sqlite3_open(dbPath.path, &db)
        guard status == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw SearchIndexError.openFailed(message)
        }

        try createTableIfNeeded()
    }

    /// Close the database connection
    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    // MARK: - Indexing

    /// Index a single message
    func indexMessage(conversationId: String, message: Message) throws {
        guard let db = db else { throw SearchIndexError.notOpen }

        let textContent = extractText(from: message)
        guard !textContent.isEmpty else { return }

        let sql = "INSERT INTO messages_fts(conversation_id, message_id, role, content, timestamp) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchIndexError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        let timestampStr = ISO8601DateFormatter().string(from: message.timestamp)

        sqlite3_bind_text(stmt, 1, (conversationId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (message.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (message.role.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (textContent as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 5, (timestampStr as NSString).utf8String, -1, nil)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SearchIndexError.queryFailed(errorMessage())
        }
    }

    /// Index all messages in a conversation
    func indexConversation(_ conversation: ConversationStore.Conversation) throws {
        guard db != nil else { throw SearchIndexError.notOpen }

        // Use a transaction for batch inserts
        try exec("BEGIN TRANSACTION")
        do {
            for message in conversation.messages {
                try indexMessage(conversationId: conversation.id, message: message)
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    // MARK: - Search

    /// Search for messages matching the query using FTS5 MATCH
    func search(query: String, limit: Int = 30) throws -> [SearchResult] {
        guard let db = db else { throw SearchIndexError.notOpen }

        // Sanitize query for FTS5: escape special characters, wrap tokens in quotes
        let sanitized = sanitizeFTSQuery(query)
        guard !sanitized.isEmpty else { return [] }

        let sql = """
            SELECT conversation_id, message_id, role, content, timestamp, bm25(messages_fts)
            FROM messages_fts
            WHERE messages_fts MATCH ?
            ORDER BY bm25(messages_fts)
            LIMIT ?
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchIndexError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (sanitized as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        let dateFormatter = ISO8601DateFormatter()
        var results: [SearchResult] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let conversationId = String(cString: sqlite3_column_text(stmt, 0))
            let messageId = String(cString: sqlite3_column_text(stmt, 1))
            let role = String(cString: sqlite3_column_text(stmt, 2))
            let content = String(cString: sqlite3_column_text(stmt, 3))
            let timestampStr = String(cString: sqlite3_column_text(stmt, 4))
            let bm25 = sqlite3_column_double(stmt, 5)

            let timestamp = dateFormatter.date(from: timestampStr) ?? Date()

            results.append(SearchResult(
                conversationId: conversationId,
                messageId: messageId,
                role: role,
                content: content,
                timestamp: timestamp,
                bm25Score: bm25
            ))
        }

        return results
    }

    // MARK: - Maintenance

    /// Delete all entries for a specific conversation
    func deleteConversation(id: String) throws {
        guard db != nil else { throw SearchIndexError.notOpen }
        try exec("DELETE FROM messages_fts WHERE conversation_id = '\(id.replacingOccurrences(of: "'", with: "''"))'")
    }

    /// Drop and recreate the FTS table (for full rebuild)
    func deleteAll() throws {
        guard db != nil else { throw SearchIndexError.notOpen }
        try exec("DROP TABLE IF EXISTS messages_fts")
        try createTableIfNeeded()
    }

    /// Get total number of indexed messages
    func count() throws -> Int {
        guard let db = db else { throw SearchIndexError.notOpen }

        let sql = "SELECT COUNT(*) FROM messages_fts"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw SearchIndexError.queryFailed(errorMessage())
        }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return 0
        }

        return Int(sqlite3_column_int(stmt, 0))
    }

    /// Get the database file size in bytes
    func dbSizeBytes() -> Int64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath.path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }

    // MARK: - Private Helpers

    private func createTableIfNeeded() throws {
        let sql = """
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
                conversation_id,
                message_id,
                role,
                content,
                timestamp,
                tokenize='porter unicode61'
            )
            """
        try exec(sql)
    }

    private func exec(_ sql: String) throws {
        guard let db = db else { throw SearchIndexError.notOpen }
        var errMsg: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if status != SQLITE_OK {
            let message = errMsg.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errMsg)
            throw SearchIndexError.queryFailed(message)
        }
    }

    private func errorMessage() -> String {
        db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Database not open"
    }

    /// Extract plain text from a message's content blocks
    private func extractText(from message: Message) -> String {
        message.content.compactMap { block in
            if case .text(let text) = block {
                return text
            }
            return nil
        }.joined(separator: " ")
    }

    /// Sanitize a user query for FTS5 MATCH syntax
    /// Splits into words and joins with OR for a forgiving search
    private func sanitizeFTSQuery(_ query: String) -> String {
        let words = query
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return "" }

        // Use OR between words so partial matches work
        // Wrap each word in quotes to escape FTS5 operators
        return words.map { "\"\($0)\"" }.joined(separator: " OR ")
    }
}

// MARK: - Errors

enum SearchIndexError: LocalizedError {
    case openFailed(String)
    case notOpen
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg):
            return "Failed to open search index: \(msg)"
        case .notOpen:
            return "Search index is not open"
        case .queryFailed(let msg):
            return "Search query failed: \(msg)"
        }
    }
}
