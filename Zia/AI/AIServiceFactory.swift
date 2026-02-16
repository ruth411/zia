//
//  AIServiceFactory.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation

/// Factory that creates the AI provider.
/// All AI requests go through the Zia backend, which holds the Claude API key.
struct AIServiceFactory {

    static func createProvider(
        keychainService: KeychainService,
        backendAuthService: BackendAuthService
    ) -> AIProvider {
        return BackendAIService(
            keychainService: keychainService,
            backendAuthService: backendAuthService
        )
    }
}
