//
//  ConversationManager.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation
import Combine

/// Manages conversation history with the AI provider.
/// Persists conversations to disk and injects user preferences into the system prompt.
class ConversationManager: ObservableObject {

    // MARK: - Properties

    @Published private(set) var messages: [Message] = []

    private let maxMessages = 50
    private let baseSystemPrompt: String
    private let conversationStore: ConversationStore
    private let preferencesStore: UserPreferencesStore
    private let ragService: RAGService?
    private var currentConversationId: String

    /// Public access to the current conversation ID (used by RAG)
    var currentConversationID: String { currentConversationId }

    // MARK: - Initialization

    init(
        systemPrompt: String? = nil,
        conversationStore: ConversationStore = ConversationStore(),
        preferencesStore: UserPreferencesStore = UserPreferencesStore(),
        ragService: RAGService? = nil
    ) {
        self.baseSystemPrompt = systemPrompt ?? Self.defaultSystemPrompt
        self.conversationStore = conversationStore
        self.preferencesStore = preferencesStore
        self.ragService = ragService
        self.currentConversationId = UUID().uuidString

        // Load persisted conversation on init
        loadPersistedConversation()
    }

    // MARK: - Public Methods

    /// Add a user message to the conversation
    func addUserMessage(_ text: String) {
        let message = Message(role: .user, text: text)
        addMessage(message)
    }

    /// Add an assistant message to the conversation
    func addAssistantMessage(_ text: String) {
        let message = Message(role: .assistant, text: text)
        addMessage(message)
    }

    /// Add an assistant message with content blocks (including tool uses)
    func addAssistantMessage(content: [ContentBlock]) {
        let message = Message(role: .assistant, content: content)
        addMessage(message)
    }

    /// Add a tool result to the conversation
    func addToolResult(_ toolResult: ToolResult) {
        let message = Message(
            role: .user,
            content: [.toolResult(toolResult)]
        )
        addMessage(message)
    }

    /// Clear all messages (current session only)
    func clearHistory() {
        messages.removeAll()
        currentConversationId = UUID().uuidString
    }

    /// Get the system prompt, enriched with user preferences
    func getSystemPrompt() -> String {
        var prompt = baseSystemPrompt

        // Inject learned user preferences
        if let context = preferencesStore.generateContextSummary() {
            prompt += "\n\nUser preferences (learned from past interactions):\n\(context)"
        }

        // Add current time
        prompt += "\n\nCurrent time: \(Date().formatted(date: .abbreviated, time: .shortened))"

        return prompt
    }

    // MARK: - Private Helpers

    private func loadPersistedConversation() {
        do {
            let conversation = try conversationStore.loadOrCreateCurrent()
            currentConversationId = conversation.id
            messages = conversation.messages
        } catch {
            print("Failed to load persisted conversation: \(error)")
        }
    }

    private func addMessage(_ message: Message) {
        messages.append(message)

        // Trim history if it exceeds max messages
        if messages.count > maxMessages {
            let removeCount = messages.count - maxMessages
            messages.removeFirst(removeCount)
        }

        // Persist to disk
        persistCurrentConversation()

        // Index for RAG search
        try? ragService?.indexMessage(conversationId: currentConversationId, message: message)
    }

    private func persistCurrentConversation() {
        let conversation = ConversationStore.Conversation(
            id: currentConversationId,
            messages: messages,
            createdAt: messages.first?.timestamp ?? Date(),
            updatedAt: Date()
        )

        do {
            try conversationStore.save(conversation)
        } catch {
            print("Failed to persist conversation: \(error)")
        }
    }

    // MARK: - System Prompt

    private static let defaultSystemPrompt = """
    You are Zia, a helpful AI personal assistant for macOS.

    You help users manage their daily digital life including:
    - Calendar events and reminders (using native macOS Calendar and Reminders)
    - Emails (via Mail.app)
    - Spotify music playback
    - Flight tracking and management

    Key behaviors:
    - Be concise and helpful
    - Confirm actions before executing them
    - Use natural, friendly language
    - When using tools, explain what you're doing
    - If you need more information, ask clarifying questions
    - Remember and learn from previous conversations

    Available capabilities:
    - Create, view, and manage calendar events
    - Create and manage reminders
    - Control Spotify playback (play, pause, skip, search)
    - Track flights from email confirmations
    - Send scheduled emails
    """
}
