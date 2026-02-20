//
//  OAuthProvider.swift
//  Zia
//
//

import Foundation
import AppKit

/// OAuth 2.0 token with refresh capability
struct OAuthToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let scopes: [String]
    let serviceName: String
    let tokenType: String

    /// Check if token is expired or will expire soon (within 5 minutes)
    var isExpired: Bool {
        return Date().addingTimeInterval(300) >= expiresAt
    }
}

/// Protocol for OAuth 2.0 providers
protocol OAuthProvider {
    /// Service name (e.g., "Spotify")
    var serviceName: String { get }

    /// Required OAuth scopes
    var requiredScopes: [String] { get }

    /// Initiate OAuth flow and return token
    /// - Parameter presentingWindow: Optional window to present the OAuth UI
    /// - Returns: OAuth token with access and refresh tokens
    func authenticate(presentingWindow: NSWindow?) async throws -> OAuthToken

    /// Refresh an expired token
    /// - Parameter token: Expired token with refresh token
    /// - Returns: New OAuth token
    func refreshToken(_ token: OAuthToken) async throws -> OAuthToken

    /// Revoke/invalidate a token
    /// - Parameter token: Token to revoke
    func revokeToken(_ token: OAuthToken) async throws
}

/// OAuth-related errors
enum OAuthError: LocalizedError {
    case userCancelled
    case invalidResponse
    case missingRefreshToken
    case networkError(Error)
    case invalidGrant
    case serverError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Authentication was cancelled"
        case .invalidResponse:
            return "Invalid response from authentication server"
        case .missingRefreshToken:
            return "No refresh token available"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidGrant:
            return "Token is invalid or expired. Please re-authenticate."
        case .serverError(let message):
            return "Server error: \(message)"
        case .timeout:
            return "Authentication timed out. Please try again."
        }
    }
}
