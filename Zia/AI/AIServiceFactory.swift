//
//  AIServiceFactory.swift
//  Zia
//
//

import Foundation

/// Factory that creates the AI provider.
/// Uses direct Claude API — each user brings their own API key stored in Keychain.
struct AIServiceFactory {

    static func createProvider(keychainService: KeychainService) -> AIProvider {
        return ClaudeService(keychainService: keychainService)
    }
}
