//
//  ClaudeResponse.swift
//  Zia
//
//

import Foundation

/// Response from Claude API /v1/messages endpoint
struct ClaudeResponse: Codable {

    let id: String
    let type: String
    let role: String
    let content: [ClaudeContentBlock]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: Usage

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }

    /// Token usage information
    struct Usage: Codable {
        let inputTokens: Int
        let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    /// Extract text content from response
    var textContent: String {
        content.compactMap { block in
            if case .text(let text) = block {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// Extract tool uses from response
    var toolUses: [(id: String, name: String, input: [String: AnyCodable])] {
        content.compactMap { block in
            if case .toolUse(let id, let name, let input) = block {
                return (id, name, input)
            }
            return nil
        }
    }

    /// Check if response contains tool uses
    var hasToolUses: Bool {
        !toolUses.isEmpty
    }
}

/// Error response from Claude API
struct ClaudeError: Codable, Error, LocalizedError {
    let type: String
    let message: String

    var errorDescription: String? {
        message
    }

    enum CodingKeys: String, CodingKey {
        case type
        case message
    }
}

/// Wrapper for Claude API error responses
struct ClaudeErrorResponse: Codable {
    let error: ClaudeError
}
