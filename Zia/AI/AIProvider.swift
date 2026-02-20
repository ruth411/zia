//
//  AIProvider.swift
//  Zia
//
//

import Foundation

/// Protocol defining the AI service interface.
/// Both Claude and OpenAI conform to this, allowing the app to swap providers.
protocol AIProvider {
    /// Send messages and get a text response
    func sendMessage(
        messages: [Message],
        system: String?,
        tools: [ToolDefinition]?
    ) async throws -> AIResponse
}

/// Default implementation to make `tools` optional at call sites
extension AIProvider {
    func sendMessage(
        messages: [Message],
        system: String?
    ) async throws -> AIResponse {
        try await sendMessage(messages: messages, system: system, tools: nil)
    }
}

/// Unified response from any AI provider
struct AIResponse {
    let textContent: String
    let contentBlocks: [ContentBlock]
    let hasToolUses: Bool
}
