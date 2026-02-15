//
//  ChatViewModel.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation
import Combine

/// View model for the chat interface
@MainActor
class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let aiProvider: AIProvider
    private let conversationManager: ConversationManager
    private let ragService: RAGService?

    // Expose messages from ConversationManager
    var messages: [Message] {
        conversationManager.messages
    }

    // MARK: - Initialization

    init(aiProvider: AIProvider, conversationManager: ConversationManager, ragService: RAGService? = nil) {
        self.aiProvider = aiProvider
        self.conversationManager = conversationManager
        self.ragService = ragService
    }

    // MARK: - Public Methods

    /// Send a message to the AI provider
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userMessage = inputText
        inputText = "" // Clear input immediately
        isLoading = true
        errorMessage = nil

        // Add user message to conversation
        conversationManager.addUserMessage(userMessage)

        do {
            // Build system prompt with RAG context
            var systemPrompt = conversationManager.getSystemPrompt()
            if let ragService = ragService,
               let results = try? ragService.search(query: userMessage),
               !results.isEmpty {
                let ragContext = ragService.formatContextForPrompt(results: results)
                systemPrompt += "\n\nRelevant context from past conversations:\n\(ragContext)"
            }

            // Send to AI provider
            let response = try await aiProvider.sendMessage(
                messages: conversationManager.messages,
                system: systemPrompt
            )

            // Add assistant response to conversation
            conversationManager.addAssistantMessage(content: response.contentBlocks)

            // TODO: Phase 4 - Handle tool uses if present
            if response.hasToolUses {
                print("Response contains tool uses, but tool execution not yet implemented")
            }

        } catch {
            print("Error sending message: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Clear conversation history
    func clearHistory() {
        conversationManager.clearHistory()
    }

    /// Dismiss error message
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Helpers

    /// Get display text for a message
    func displayText(for message: Message) -> String {
        message.content.compactMap { block in
            if case .text(let text) = block {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }

    /// Check if a message has tool uses
    func hasToolUses(_ message: Message) -> Bool {
        message.content.contains { block in
            if case .toolUse = block {
                return true
            }
            return false
        }
    }

    /// Get tool uses from a message
    func getToolUses(from message: Message) -> [ToolUse] {
        message.content.compactMap { block in
            if case .toolUse(let toolUse) = block {
                return toolUse
            }
            return nil
        }
    }
}
