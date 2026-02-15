//
//  AIServiceFactory.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation

/// Factory that creates the correct AI provider based on user configuration
struct AIServiceFactory {

    /// Create the AI provider based on the user's selected provider from onboarding
    static func createProvider(keychainService: KeychainService = KeychainService()) -> AIProvider {
        let providerString = UserDefaults.standard.string(forKey: Configuration.Onboarding.aiProviderKey) ?? "claude"
        let providerType = AIProviderType(rawValue: providerString) ?? .claude

        switch providerType {
        case .claude:
            return ClaudeService(keychainService: keychainService)
        case .openai:
            return OpenAIService(keychainService: keychainService)
        }
    }
}
