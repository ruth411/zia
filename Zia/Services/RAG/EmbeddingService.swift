//
//  EmbeddingService.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation
import NaturalLanguage

/// On-device semantic similarity using Apple's NLEmbedding.
/// Used to re-rank FTS5 search results by semantic closeness to the query.
/// Falls back gracefully if embeddings aren't available for the user's language.
class EmbeddingService {

    // MARK: - Properties

    private lazy var embedding: NLEmbedding? = {
        NLEmbedding.sentenceEmbedding(for: .english)
    }()

    // MARK: - Public Methods

    /// Whether NLEmbedding is available on this device/language
    var isAvailable: Bool {
        embedding != nil
    }

    /// Compute cosine similarity between a query and a list of candidate strings.
    /// Returns an array of (index, score) pairs, sorted by score descending.
    /// Scores range from 0.0 (no similarity) to 1.0 (identical).
    func computeSimilarity(query: String, candidates: [String]) -> [(index: Int, score: Double)] {
        guard let embedding = embedding else {
            // If embeddings unavailable, return neutral scores
            return candidates.enumerated().map { (index: $0.offset, score: 0.5) }
        }

        var results: [(index: Int, score: Double)] = []

        for (index, candidate) in candidates.enumerated() {
            let distance = embedding.distance(between: query, and: candidate)
            // NLEmbedding.distance returns cosine distance (0 = identical, 2 = opposite)
            // Convert to similarity: 1.0 - (distance / 2.0) maps [0,2] -> [1.0, 0.0]
            let similarity = max(0, 1.0 - (distance / 2.0))
            results.append((index: index, score: similarity))
        }

        return results.sorted { $0.score > $1.score }
    }
}
