//
//  BackendAIService.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation

/// AI provider that proxies requests through the Zia backend.
/// The backend holds the Claude API key — the client never needs one.
class BackendAIService: AIProvider {

    // MARK: - Properties

    private let keychainService: KeychainService
    private let backendAuthService: BackendAuthService
    private let accessTokenKey = "backend_access_token"

    private var baseURL: String {
        Configuration.Backend.baseURL
    }

    // MARK: - Initialization

    init(keychainService: KeychainService, backendAuthService: BackendAuthService) {
        self.keychainService = keychainService
        self.backendAuthService = backendAuthService
    }

    // MARK: - AIProvider Conformance

    func sendMessage(
        messages: [Message],
        system: String? = nil,
        tools: [ToolDefinition]? = nil
    ) async throws -> AIResponse {
        let claudeResponse = try await sendBackendRequest(messages: messages, system: system, tools: tools)

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

    // MARK: - Private

    private func sendBackendRequest(
        messages: [Message],
        system: String?,
        tools: [ToolDefinition]?
    ) async throws -> ClaudeResponse {
        // Convert domain messages to API format
        let claudeMessages = messages.map { message in
            ClaudeMessage(
                role: message.role.rawValue,
                content: convertContentBlocks(message.content)
            )
        }

        // Build request body matching the backend's ChatRequest schema
        let request = ClaudeRequest(
            messages: claudeMessages,
            system: system,
            tools: tools
        )

        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)

        // The backend only needs messages, system, and tools — it sets model/max_tokens itself.
        // But we send the full ClaudeRequest because the backend ignores unknown fields and
        // the schema accepts messages/system/tools which is what matters.

        let data = try await authenticatedRequest(path: "/chat/message", body: requestData)

        let decoder = JSONDecoder()
        return try decoder.decode(ClaudeResponse.self, from: data)
    }

    /// Make an authenticated POST request with automatic token refresh on 401.
    private func authenticatedRequest(path: String, body: Data) async throws -> Data {
        let data = try await doRequest(path: path, body: body)
        return data
    }

    private func doRequest(path: String, body: Data, isRetry: Bool = false) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendAIServiceError.invalidURL
        }

        guard let token = try? keychainService.retrieveString(for: accessTokenKey),
              !token.isEmpty else {
            throw BackendAIServiceError.notAuthenticated
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = body
        urlRequest.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAIServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            // Try refreshing the token once
            if !isRetry {
                _ = try await backendAuthService.refreshAccessToken()
                return try await doRequest(path: path, body: body, isRetry: true)
            }
            throw BackendAIServiceError.notAuthenticated
        case 502:
            throw BackendAIServiceError.aiServiceUnavailable
        case 503:
            throw BackendAIServiceError.aiServiceUnavailable
        default:
            // Try to extract error detail from the backend
            if let errorBody = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw BackendAIServiceError.serverError(errorBody.detail)
            }
            throw BackendAIServiceError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }

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

// MARK: - Types

private struct BackendErrorResponse: Codable {
    let detail: String
}

// MARK: - Errors

enum BackendAIServiceError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case aiServiceUnavailable
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .notAuthenticated:
            return "Please log in to use the AI assistant"
        case .invalidResponse:
            return "Invalid response from server"
        case .aiServiceUnavailable:
            return "AI service is temporarily unavailable. Please try again."
        case .serverError(let msg):
            return "Server error: \(msg)"
        }
    }
}
