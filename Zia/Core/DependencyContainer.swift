//
//  DependencyContainer.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation
import Combine

/// Central dependency injection container
/// This class initializes and wires all services, capabilities, and view models
class DependencyContainer: ObservableObject {

    // MARK: - Shared Instance

    static let shared = DependencyContainer()

    // MARK: - Services (will be implemented in later phases)

    // Phase 2: Authentication
    // lazy var keychainService: KeychainService = KeychainService()
    // lazy var authenticationManager: AuthenticationManager = AuthenticationManager(keychainService: keychainService)

    // Phase 3: AI
    // lazy var claudeService: ClaudeService = ClaudeService(keychainService: keychainService)
    // lazy var toolRegistry: ToolRegistry = ToolRegistry()
    // lazy var toolExecutor: ToolExecutor = ToolExecutor(registry: toolRegistry)
    // lazy var conversationManager: ConversationManager = ConversationManager()

    // Phase 4: Capabilities
    // lazy var capabilityManager: CapabilityManager = CapabilityManager(toolRegistry: toolRegistry)

    // Phase 8: Storage
    // lazy var cloudKitService: CloudKitService = CloudKitService()

    // Phase 9: Scheduling
    // lazy var schedulerService: SchedulerService = SchedulerService()

    // MARK: - View Models

    // Phase 3: Chat
    // lazy var chatViewModel: ChatViewModel = ChatViewModel(
    //     claudeService: claudeService,
    //     conversationManager: conversationManager,
    //     toolExecutor: toolExecutor
    // )

    // lazy var settingsViewModel: SettingsViewModel = SettingsViewModel(
    //     authenticationManager: authenticationManager
    // )

    // MARK: - Initialization

    private init() {
        // Services will be initialized lazily when first accessed
        print("✅ DependencyContainer initialized")
    }

    // MARK: - Setup

    /// Initialize services that need setup on app launch
    func initialize() async {
        print("🚀 Initializing services...")

        // Phase 2: Initialize authentication
        // await authenticationManager.initialize()

        // Phase 4: Register capabilities
        // await registerCapabilities()

        // Phase 9: Start scheduler
        // schedulerService.start()

        print("✅ Services initialized")
    }

    // MARK: - Private Methods

    // Phase 4: Capability Registration
    // private func registerCapabilities() async {
    //     // Register calendar capability
    //     let calendarCapability = CalendarCapability()
    //     try? await capabilityManager.registerCapability(calendarCapability)
    //
    //     // Register email capability
    //     let emailCapability = EmailCapability()
    //     try? await capabilityManager.registerCapability(emailCapability)
    //
    //     // Register music capability
    //     let musicCapability = MusicCapability()
    //     try? await capabilityManager.registerCapability(musicCapability)
    //
    //     // Register flight capability
    //     let flightCapability = FlightCapability()
    //     try? await capabilityManager.registerCapability(flightCapability)
    // }
}
