//
//  OpenAIService.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation

/// Service for communicating with OpenAI Chat Completions API
class OpenAIService: AIProvider {

    // MARK: - Properties

    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"
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
        // Get API key
        guard let apiKey = try? keychainService.retrieveString(for: "openai_api_key"),
              !apiKey.isEmpty else {
            throw OpenAIServiceError.missingAPIKey
        }

        // Build messages array
        var openAIMessages: [[String: Any]] = []

        // System message
        if let system = system {
            openAIMessages.append(["role": "system", "content": system])
        }

        // Conversation messages
        for message in messages {
            let text = message.content.compactMap { block -> String? in
                if case .text(let t) = block { return t }
                return nil
            }.joined(separator: "\n")

            if !text.isEmpty {
                openAIMessages.append([
                    "role": message.role.rawValue,
                    "content": text
                ])
            }
        }

        // Build request body
        var body: [String: Any] = [
            "model": model,
            "messages": openAIMessages,
            "max_tokens": 4096
        ]

        // Add tools if provided
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { tool -> [String: Any] in
                [
                    "type": "function",
                    "function": [
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": [
                            "type": tool.inputSchema.type,
                            "properties": tool.inputSchema.properties.mapValues { prop -> [String: Any] in
                                var schema: [String: Any] = [
                                    "type": prop.type,
                                    "description": prop.description
                                ]
                                if let enumVals = prop.enumValues {
                                    schema["enum"] = enumVals
                                }
                                return schema
                            },
                            "required": tool.inputSchema.required ?? []
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            }
        }

        // Create URL request
        guard let url = URL(string: apiEndpoint) else {
            throw OpenAIServiceError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Send request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("OpenAI API error: \(errorString)")
            }
            throw OpenAIServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIServiceError.invalidResponse
        }

        return AIResponse(
            textContent: content,
            contentBlocks: [.text(content)],
            hasToolUses: false
        )
    }
}

// MARK: - Errors

enum OpenAIServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not found. Please add it in Settings."
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
}
