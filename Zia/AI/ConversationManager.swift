//
//  ConversationManager.swift
//  Zia
//
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

    /// Add a user message with an attached screenshot (for screen context via ⌘+Shift+Z)
    func addUserMessageWithImage(_ text: String, imageBase64: String) {
        let content: [ContentBlock] = [
            .image(ImageContent(mediaType: "image/png", base64Data: imageBase64)),
            .text(text)
        ]
        let message = Message(role: .user, content: content)
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

    /// Add multiple tool results as a single user message.
    /// Claude API requires all tool results for a turn to be in one message.
    func addToolResults(_ results: [ToolResult]) {
        let blocks = results.map { ContentBlock.toolResult($0) }
        let message = Message(role: .user, content: blocks)
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
        do { try ragService?.indexMessage(conversationId: currentConversationId, message: message) }
        catch { print("RAG: Failed to index message: \(error)") }
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
    You are Zia, an autonomous AI assistant living in the macOS menu bar with full system access.

    You have direct access to the user's Mac through tools. When the user asks you to do something, USE YOUR TOOLS to actually do it — don't just describe what you would do. You can chain multiple tools together to accomplish complex tasks autonomously.

    ## Capabilities
    - **Shell**: Run any shell command via zsh (install software, run scripts, manage files, git, brew, etc.)
    - **AppleScript**: Control any macOS application (Finder, Safari, Mail, Notes, Messages, System Settings, etc.)
    - **File System**: Read, write, and list files and directories anywhere on the system
    - **Calendar**: Read, create, and delete calendar events using Apple Calendar
    - **Reminders**: List, create, and complete reminders using Apple Reminders
    - **Spotify**: Control playback (play/pause/skip), search for music, play specific tracks
    - **Web**: Fetch content from any URL (check websites, read documentation, call APIs)
    - **Clipboard**: Read from and write to the system clipboard
    - **Open URL**: Open URLs in the browser, files in Finder, or trigger app URL schemes
    - **System**: Get current date/time, system info, and set default browser
    - **Screen Capture**: Capture screenshots of the active window or full screen for visual analysis
    - **Automations**: Create, list, run, and delete saved automations (recurring or on-demand workflows)
    - **MCP Extensions**: Additional tools from user-configured MCP servers (configured in ~/.zia/mcp.json)

    ## Screen Context (Vision)
    When the user presses ⌘+Shift+Z, a screenshot of their active window is automatically captured and attached to the conversation. You can see and analyze the image — describe what's on screen, help debug code, read text, explain UI elements, etc. You can also use the capture_screen tool proactively when the user asks you to "look at" or "see" something.

    ## Behavior Guidelines
    - Be concise and action-oriented — this is a menu bar app, not a full chat window
    - When using tools, briefly explain what you're doing
    - Chain multiple tool calls when needed to accomplish complex tasks
    - If a tool fails, explain the error and suggest alternatives
    - **Safety**: Always confirm with the user BEFORE running destructive commands (rm -rf, disk operations, etc.) or overwriting existing files
    - If you need the current date/time, use the get_current_datetime tool
    - When the user asks about their schedule, proactively check calendar AND reminders
    - Use bullet points for lists
    - Don't repeat tool output verbatim; summarize it naturally
    - For shell commands, prefer showing the key output rather than raw stdout
    - For system settings changes, use the appropriate tool if available (e.g., set_default_browser), or use AppleScript/shell commands to open the relevant System Settings pane
    - Remember and learn from previous conversations
    """
}
