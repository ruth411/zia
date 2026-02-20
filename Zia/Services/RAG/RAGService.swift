//
//  RAGService.swift
//  Zia
//
//

import Foundation

/// Orchestrates RAG (Retrieval-Augmented Generation) for Zia.
/// Combines FTS5 keyword search with NLEmbedding semantic re-ranking
/// to find relevant past conversations and inject them into AI context.
class RAGService {

    // MARK: - Types

    struct RAGResult {
        let conversationId: String
        let messageId: String
        let content: String
        let role: String
        let timestamp: Date
        let score: Double
    }

    struct IndexStats {
        let totalMessages: Int
        let dbSizeBytes: Int64
    }

    // MARK: - Properties

    private let searchIndex: SearchIndex
    private let embeddingService: EmbeddingService
    private let maxResults: Int
    private let ftsLimit: Int
    private let bm25Weight: Double
    private let embeddingWeight: Double
    private let minScore: Double

    // MARK: - Initialization

    init(
        searchIndex: SearchIndex = SearchIndex(),
        embeddingService: EmbeddingService = EmbeddingService(),
        maxResults: Int = Configuration.RAG.maxSearchResults,
        ftsLimit: Int = Configuration.RAG.ftsResultLimit,
        bm25Weight: Double = Configuration.RAG.bm25Weight,
        embeddingWeight: Double = Configuration.RAG.embeddingWeight,
        minScore: Double = Configuration.RAG.minRelevanceScore
    ) {
        self.searchIndex = searchIndex
        self.embeddingService = embeddingService
        self.maxResults = maxResults
        self.ftsLimit = ftsLimit
        self.bm25Weight = bm25Weight
        self.embeddingWeight = embeddingWeight
        self.minScore = minScore
    }

    // MARK: - Lifecycle

    /// Open the search index and auto-reindex if needed
    func initialize(conversationStore: ConversationStore? = nil) throws {
        try searchIndex.open()

        // Auto-reindex if DB is empty but conversations exist
        if let store = conversationStore {
            let indexCount = (try? searchIndex.count()) ?? 0
            if indexCount == 0 {
                let conversations = (try? store.loadAll()) ?? []
                if !conversations.isEmpty {
                    print("RAG: Auto-reindexing \(conversations.count) existing conversations...")
                    do {
                        try reindexAll(conversationStore: store)
                    } catch {
                        print("RAG: Auto-reindex failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Search

    /// Search past conversations for content relevant to the query.
    /// Returns results ranked by a combined BM25 + semantic similarity score.
    func search(query: String) throws -> [RAGResult] {
        // 1. FTS5 keyword search
        let ftsResults = try searchIndex.search(query: query, limit: ftsLimit)
        guard !ftsResults.isEmpty else { return [] }

        // 2. Normalize BM25 scores (FTS5 returns negative scores; more negative = better match)
        let bm25Scores = ftsResults.map { $0.bm25Score }
        let minBM25 = bm25Scores.min() ?? 0
        let maxBM25 = bm25Scores.max() ?? 0
        let bm25Range = maxBM25 - minBM25

        let normalizedBM25: [Double] = bm25Scores.map { score in
            if bm25Range == 0 { return 1.0 }
            // Invert because FTS5 BM25 is negative (lower = better)
            return (maxBM25 - score) / bm25Range
        }

        // 3. Semantic re-ranking via NLEmbedding
        let candidates = ftsResults.map { $0.content }
        let embeddingScores = embeddingService.computeSimilarity(query: query, candidates: candidates)

        // Build a lookup: index -> embedding score
        var embeddingScoreMap: [Int: Double] = [:]
        for item in embeddingScores {
            embeddingScoreMap[item.index] = item.score
        }

        // 4. Combine scores
        var scoredResults: [RAGResult] = []
        for (index, ftsResult) in ftsResults.enumerated() {
            let bm25Normalized = normalizedBM25[index]
            let embScore = embeddingScoreMap[index] ?? 0.5
            let combinedScore = bm25Weight * bm25Normalized + embeddingWeight * embScore

            guard combinedScore >= minScore else { continue }

            scoredResults.append(RAGResult(
                conversationId: ftsResult.conversationId,
                messageId: ftsResult.messageId,
                content: ftsResult.content,
                role: ftsResult.role,
                timestamp: ftsResult.timestamp,
                score: combinedScore
            ))
        }

        // 5. Sort by combined score (descending) and limit
        scoredResults.sort { $0.score > $1.score }
        return Array(scoredResults.prefix(maxResults))
    }

    // MARK: - Context Formatting

    /// Format RAG results into a string suitable for injection into the AI system prompt
    func formatContextForPrompt(results: [RAGResult]) -> String {
        guard !results.isEmpty else { return "" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var lines: [String] = []
        for result in results {
            let dateStr = dateFormatter.string(from: result.timestamp)
            let roleLabel = result.role == "user" ? "User" : "Assistant"
            // Truncate long content to avoid bloating the prompt
            let content = result.content.count > 300
                ? String(result.content.prefix(300)) + "..."
                : result.content
            lines.append("[\(dateStr)] \(roleLabel): \(content)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Indexing

    /// Index a single message (called after each new message)
    func indexMessage(conversationId: String, message: Message) throws {
        try searchIndex.indexMessage(conversationId: conversationId, message: message)
    }

    /// Full rebuild: delete index, then re-index all conversations from the store
    func reindexAll(conversationStore: ConversationStore) throws {
        try searchIndex.deleteAll()

        let conversations = try conversationStore.loadAll()
        for conversation in conversations {
            try searchIndex.indexConversation(conversation)
        }

        print("RAG: Re-indexed \(conversations.count) conversations")
    }

    // MARK: - Stats

    /// Get indexing statistics
    func indexingStats() throws -> IndexStats {
        let count = try searchIndex.count()
        let size = searchIndex.dbSizeBytes()
        return IndexStats(totalMessages: count, dbSizeBytes: size)
    }
}
