//
//  ChatViewModel.swift
//  Zia
//
//

import Foundation
import Combine

/// View model for the chat interface with autonomous agent loop
@MainActor
class ChatViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentToolAction: String?

    // MARK: - Dependencies

    private let aiProvider: AIProvider
    private let conversationManager: ConversationManager
    private let ragService: RAGService?
    private let toolRegistry: ToolRegistry
    private let toolExecutor: ToolExecutor

    // MARK: - Constants

    private let maxAgentIterations = 10
    private let maxAgentDuration: TimeInterval = 120 // 2-minute wall-clock limit

    // Expose messages from ConversationManager
    var messages: [Message] {
        conversationManager.messages
    }

    // MARK: - Initialization

    init(
        aiProvider: AIProvider,
        conversationManager: ConversationManager,
        ragService: RAGService? = nil,
        toolRegistry: ToolRegistry,
        toolExecutor: ToolExecutor
    ) {
        self.aiProvider = aiProvider
        self.conversationManager = conversationManager
        self.ragService = ragService
        self.toolRegistry = toolRegistry
        self.toolExecutor = toolExecutor
    }

    // MARK: - Public Methods

    /// Send a message to the AI provider with autonomous tool execution loop
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let userMessage = inputText
        inputText = ""
        isLoading = true
        errorMessage = nil

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

            // Get tool definitions (nil if no tools registered)
            let tools = toolRegistry.allDefinitions.isEmpty ? nil : toolRegistry.allDefinitions

            // === AGENT LOOP ===
            var iterationCount = 0
            var hitTimeLimit = false
            let startTime = Date()

            while iterationCount < maxAgentIterations {
                iterationCount += 1

                if Date().timeIntervalSince(startTime) > maxAgentDuration {
                    hitTimeLimit = true
                    break
                }

                let response = try await aiProvider.sendMessage(
                    messages: conversationManager.messages,
                    system: systemPrompt,
                    tools: tools
                )

                // Add assistant response (with any tool_use blocks) to conversation
                conversationManager.addAssistantMessage(content: response.contentBlocks)

                // If no tool uses, we're done
                guard response.hasToolUses else { break }

                // Extract tool uses from response
                let toolUses = response.contentBlocks.compactMap { block -> ToolUse? in
                    if case .toolUse(let tu) = block { return tu }
                    return nil
                }

                // Execute each tool and collect results
                var toolResults: [ToolResult] = []
                for toolUse in toolUses {
                    currentToolAction = "Running \(toolUse.name)..."
                    let result = await toolExecutor.execute(toolUse)
                    toolResults.append(result)
                }

                // Add ALL tool results as a single user message
                conversationManager.addToolResults(toolResults)
                currentToolAction = nil
            }

            if hitTimeLimit {
                errorMessage = "Zia hit the 2-minute limit. Try breaking the task into smaller steps."
            } else if iterationCount >= maxAgentIterations {
                errorMessage = "Zia reached its step limit (\(maxAgentIterations) steps). Try breaking the task into smaller steps."
            }

        } catch {
            print("Error sending message: \(error)")
            errorMessage = error.localizedDescription
        }

        currentToolAction = nil
        isLoading = false
    }

    /// Send a message with an attached screenshot (triggered by ⌘+Shift+Z hotkey)
    func sendMessageWithScreenshot(text: String, imageBase64: String) async {
        isLoading = true
        errorMessage = nil

        let prompt = text.isEmpty ? "What do you see on my screen? Describe it and ask how you can help." : text
        conversationManager.addUserMessageWithImage(prompt, imageBase64: imageBase64)

        do {
            var systemPrompt = conversationManager.getSystemPrompt()
            let tools = toolRegistry.allDefinitions.isEmpty ? nil : toolRegistry.allDefinitions

            var iterationCount = 0
            var hitTimeLimit = false
            let startTime = Date()

            while iterationCount < maxAgentIterations {
                iterationCount += 1

                if Date().timeIntervalSince(startTime) > maxAgentDuration {
                    hitTimeLimit = true
                    break
                }

                let response = try await aiProvider.sendMessage(
                    messages: conversationManager.messages,
                    system: systemPrompt,
                    tools: tools
                )

                conversationManager.addAssistantMessage(content: response.contentBlocks)

                guard response.hasToolUses else { break }

                let toolUses = response.contentBlocks.compactMap { block -> ToolUse? in
                    if case .toolUse(let tu) = block { return tu }
                    return nil
                }

                var toolResults: [ToolResult] = []
                for toolUse in toolUses {
                    currentToolAction = "Running \(toolUse.name)..."
                    let result = await toolExecutor.execute(toolUse)
                    toolResults.append(result)
                }

                conversationManager.addToolResults(toolResults)
                currentToolAction = nil
            }

            if hitTimeLimit {
                errorMessage = "Zia hit the 2-minute limit. Try breaking the task into smaller steps."
            } else if iterationCount >= maxAgentIterations {
                errorMessage = "Zia reached its step limit (\(maxAgentIterations) steps). Try breaking the task into smaller steps."
            }

        } catch {
            print("Error sending screenshot message: \(error)")
            errorMessage = error.localizedDescription
        }

        currentToolAction = nil
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
