//
//  ClaudeService.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation

/// Service for communicating with Claude API
class ClaudeService: AIProvider {

    // MARK: - Properties

    private let apiEndpoint = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let keychainService: KeychainService

    // MARK: - Initialization

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    // MARK: - AIProvider Conformance

    func sendMessage(
        messages: [Message],
        system: String? = nil,
        tools: [ToolDefinition]? = nil
    ) async throws -> AIResponse {
        let claudeResponse = try await sendClaudeRequest(messages: messages, system: system, tools: tools)
        let contentBlocks = claudeResponse.content.map { block -> ContentBlock in
            switch block {
            case .text(let text):
                return .text(text)
            case .toolUse(let id, let name, let input):
                return .toolUse(ToolUse(id: id, name: name, input: input))
            case .toolResult(let toolUseId, let content, let isError):
                return .toolResult(ToolResult(toolUseId: toolUseId, content: content, isError: isError))
            }
        }
        return AIResponse(
            textContent: claudeResponse.textContent,
            contentBlocks: contentBlocks,
            hasToolUses: claudeResponse.hasToolUses
        )
    }

    // MARK: - Internal Claude API

    /// Send raw request to Claude API
    private func sendClaudeRequest(
        messages: [Message],
        system: String? = nil,
        tools: [ToolDefinition]? = nil
    ) async throws -> ClaudeResponse {
        // Get API key from Keychain
        print("🔑 Attempting to retrieve Claude API key from Keychain...")
        guard let apiKey = try? keychainService.retrieveString(for: "claude_api_key"),
              !apiKey.isEmpty else {
            print("❌ Claude API key not found or empty!")
            throw ClaudeServiceError.missingAPIKey
        }
        print("✅ Claude API key found (length: \(apiKey.count) chars)")

        // Convert domain messages to API format
        let claudeMessages = messages.map { message in
            ClaudeMessage(
                role: message.role.rawValue,
                content: convertContentBlocks(message.content)
            )
        }

        // Build request
        let request = ClaudeRequest(
            messages: claudeMessages,
            system: system,
            tools: tools
        )

        // Create URL request
        guard let url = URL(string: apiEndpoint) else {
            throw ClaudeServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

        // Encode request body (CodingKeys handle snake_case mapping)
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        print("🤖 Sending request to Claude API...")
        print("📊 Messages count: \(messages.count)")
        print("🔧 Tools count: \(tools?.count ?? 0)")

        // Send request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw ClaudeServiceError.invalidResponse
        }

        print("📡 Response status code: \(httpResponse.statusCode)")

        // Handle errors
        if httpResponse.statusCode != 200 {
            // Try to decode error response
            let decoder = JSONDecoder()
            if let errorResponse = try? decoder.decode(ClaudeErrorResponse.self, from: data) {
                print("❌ Claude API error: \(errorResponse.error.message)")
                throw errorResponse.error
            }

            // Try to print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Raw error response: \(responseString)")
            }

            // Generic error
            print("❌ HTTP error: \(httpResponse.statusCode)")
            throw ClaudeServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        // Decode response (CodingKeys handle snake_case mapping)
        let decoder = JSONDecoder()
        let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)

        print("✅ Received response from Claude")
        print("📝 Response text: \(claudeResponse.textContent.prefix(100))...")
        print("🔧 Tool uses: \(claudeResponse.toolUses.count)")
        print("🪙 Tokens - Input: \(claudeResponse.usage.inputTokens), Output: \(claudeResponse.usage.outputTokens)")

        return claudeResponse
    }

    // MARK: - Private Helpers

    /// Convert domain ContentBlocks to API format
    private func convertContentBlocks(_ blocks: [ContentBlock]) -> [ClaudeContentBlock] {
        blocks.map { block in
            switch block {
            case .text(let text):
                return .text(text)
            case .toolUse(let toolUse):
                return .toolUse(id: toolUse.id, name: toolUse.name, input: toolUse.input)
            case .toolResult(let toolResult):
                return .toolResult(
                    toolUseId: toolResult.toolUseId,
                    content: toolResult.content,
                    isError: toolResult.isError
                )
            }
        }
    }
}

// MARK: - Errors

enum ClaudeServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not found. Please add it in Settings."
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
