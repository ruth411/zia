//
//  DependencyContainer.swift
//  Zia
//
//

import Foundation
import Combine

/// Central dependency injection container
/// This class initializes and wires all services, capabilities, and view models
class DependencyContainer: ObservableObject {

    // MARK: - Shared Instance

    static let shared = DependencyContainer()

    // MARK: - App Delegate Reference

    weak var appDelegate: AnyObject?

    // MARK: - Services

    // Authentication
    lazy var keychainService: KeychainService = KeychainService()
    lazy var authenticationManager: AuthenticationManager = AuthenticationManager(keychainService: keychainService)

    // AI — direct Claude API, user provides their own key via onboarding
    lazy var aiProvider: AIProvider = AIServiceFactory.createProvider(keychainService: keychainService)
    lazy var conversationStore: ConversationStore = ConversationStore()
    lazy var ragService: RAGService = RAGService()
    lazy var conversationManager: ConversationManager = ConversationManager(ragService: ragService)

    // Tool System
    lazy var toolRegistry: ToolRegistry = {
        let registry = ToolRegistry()
        registerAllTools(in: registry)
        return registry
    }()
    lazy var toolExecutor: ToolExecutor = ToolExecutor(registry: toolRegistry)

    // MCP
    lazy var mcpClientManager: MCPClientManager = MCPClientManager()

    // Capability Services
    lazy var calendarService: CalendarService = CalendarService()
    lazy var remindersService: RemindersService = RemindersService()
    lazy var spotifyService: SpotifyService = SpotifyService(authManager: authenticationManager)

    // Proactive Intelligence
    lazy var proactiveEngine: ProactiveEngine = ProactiveEngine()

    // Automations
    lazy var automationStore: AutomationStore = AutomationStore()
    lazy var automationScheduler: AutomationScheduler = AutomationScheduler(store: automationStore)

    // MARK: - Initialization

    private init() {}

    // MARK: - Setup

    /// Initialize services that need setup on app launch
    func initialize() async {
        // Initialize RAG search index (auto-reindexes if needed)
        try? ragService.initialize(conversationStore: conversationStore)

        // Force tool registry initialization (built-in tools)
        _ = toolRegistry

        // Start MCP servers and register their tools
        await mcpClientManager.startAll()
        mcpClientManager.registerTools(in: toolRegistry)

        // Start proactive engine with triggers
        proactiveEngine.registerTriggers([
            CalendarTrigger(calendarService: calendarService),
            MorningBriefingTrigger(calendarService: calendarService, remindersService: remindersService),
            SystemHealthTrigger()
        ])
        proactiveEngine.start()

        // Start automation scheduler
        automationScheduler.start()
    }

    // MARK: - Tool Registration

    private func registerAllTools(in registry: ToolRegistry) {
        // System tools
        registry.register(GetCurrentDateTimeTool())
        registry.register(GetSystemInfoTool())
        registry.register(SetDefaultBrowserTool())

        // Calendar tools
        registry.register(CalendarGetEventsTool(calendarService: calendarService))
        registry.register(CalendarCreateEventTool(calendarService: calendarService))
        registry.register(CalendarDeleteEventTool(calendarService: calendarService))

        // Reminder tools
        registry.register(RemindersListTool(remindersService: remindersService))
        registry.register(RemindersCreateTool(remindersService: remindersService))
        registry.register(RemindersCompleteTool(remindersService: remindersService))

        // Spotify tools
        registry.register(SpotifyGetCurrentTrackTool(spotifyService: spotifyService))
        registry.register(SpotifyPlayPauseTool(spotifyService: spotifyService))
        registry.register(SpotifySkipTool(spotifyService: spotifyService))
        registry.register(SpotifySearchTool(spotifyService: spotifyService))
        registry.register(SpotifyPlayTrackTool(spotifyService: spotifyService))

        // Shell tools
        registry.register(RunShellCommandTool())
        registry.register(RunAppleScriptTool())

        // File system tools
        registry.register(ReadFileTool())
        registry.register(WriteFileTool())
        registry.register(ListDirectoryTool())

        // Web tools
        registry.register(WebFetchTool())

        // Utility tools
        registry.register(ClipboardReadTool())
        registry.register(ClipboardWriteTool())
        registry.register(OpenURLTool())

        // Vision tools
        registry.register(ScreenCaptureTool())

        // Automation tools
        registry.register(CreateAutomationTool(store: automationStore))
        registry.register(ListAutomationsTool(store: automationStore))
        registry.register(RunAutomationTool(store: automationStore))
        registry.register(DeleteAutomationTool(store: automationStore))
    }
}
