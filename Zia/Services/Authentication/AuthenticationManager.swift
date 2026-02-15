//
//  AuthenticationManager.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation
import Combine

/// Central authentication manager coordinating all OAuth providers
class AuthenticationManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isSpotifyAuthenticated = false

    // MARK: - Properties

    private let keychainService: KeychainService
    private let spotifyProvider: SpotifyOAuthProvider

    // Cache for tokens
    private var cachedTokens: [String: OAuthToken] = [:]

    // MARK: - Initialization

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        self.spotifyProvider = SpotifyOAuthProvider()

        // Check authentication status on init
        checkAuthenticationStatus()
    }

    // MARK: - Authentication Status

    /// Check if user is authenticated with specific service
    func isAuthenticated(for service: String) -> Bool {
        switch service.lowercased() {
        case "spotify":
            return isSpotifyAuthenticated
        default:
            return false
        }
    }

    /// Check authentication status for all services
    private func checkAuthenticationStatus() {
        // Check Spotify
        if let token = try? keychainService.retrieveToken(for: "Spotify"),
           !token.isExpired {
            isSpotifyAuthenticated = true
            cachedTokens["Spotify"] = token
        }
    }

    // MARK: - Authentication

    /// Authenticate with Spotify
    @MainActor
    func authenticateSpotify() async throws {
        let token = try await spotifyProvider.authenticate(presentingWindow: nil)
        try keychainService.saveToken(token, for: "Spotify")
        cachedTokens["Spotify"] = token
        isSpotifyAuthenticated = true

        print("✅ Spotify authentication successful")
    }

    // MARK: - Token Management

    /// Get valid token for service (auto-refreshes if needed)
    func getValidToken(for service: String) async throws -> OAuthToken {
        // Check cache first
        if let cachedToken = cachedTokens[service], !cachedToken.isExpired {
            return cachedToken
        }

        // Try to retrieve from Keychain
        guard var token = try keychainService.retrieveToken(for: service) else {
            throw AuthenticationError.notAuthenticated
        }

        // Refresh if expired
        if token.isExpired {
            token = try await refreshToken(for: service, token: token)
        }

        // Update cache
        cachedTokens[service] = token
        return token
    }

    /// Refresh token for service
    private func refreshToken(for service: String, token: OAuthToken) async throws -> OAuthToken {
        let provider: OAuthProvider

        switch service {
        case "Spotify":
            provider = spotifyProvider
        default:
            throw AuthenticationError.unsupportedService
        }

        let newToken = try await provider.refreshToken(token)
        try keychainService.saveToken(newToken, for: service)

        print("✅ Token refreshed for \(service)")
        return newToken
    }

    // MARK: - Sign Out

    /// Sign out from Spotify
    @MainActor
    func signOutSpotify() async throws {
        if let token = try? keychainService.retrieveToken(for: "Spotify") {
            try? await spotifyProvider.revokeToken(token)
        }

        try keychainService.deleteToken(for: "Spotify")
        cachedTokens.removeValue(forKey: "Spotify")
        isSpotifyAuthenticated = false

        print("✅ Signed out from Spotify")
    }

    /// Sign out from all services
    @MainActor
    func signOutAll() async throws {
        try await signOutSpotify()
    }
}

// MARK: - Errors

enum AuthenticationError: LocalizedError {
    case notAuthenticated
    case unsupportedService

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in first."
        case .unsupportedService:
            return "Unsupported service"
        }
    }
}
