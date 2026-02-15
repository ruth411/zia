//
//  SpotifyOAuthProvider.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation
import AppKit

/// Spotify OAuth 2.0 provider for music playback control
class SpotifyOAuthProvider: OAuthProvider {

    // MARK: - Properties

    let serviceName = "Spotify"

    let requiredScopes = Configuration.OAuth.Spotify.scopes

    private let clientID = Configuration.OAuth.Spotify.clientID
    private let clientSecret = Configuration.OAuth.Spotify.clientSecret
    private let redirectURI = Configuration.OAuth.redirectURI

    // For capturing OAuth callback
    private var authenticationContinuation: CheckedContinuation<OAuthToken, Error>?

    // MARK: - URLs

    private let authorizationEndpoint = "https://accounts.spotify.com/authorize"
    private let tokenEndpoint = "https://accounts.spotify.com/api/token"

    // MARK: - OAuth Flow

    func authenticate(presentingWindow: NSWindow?) async throws -> OAuthToken {
        // Generate state for CSRF protection
        let state = UUID().uuidString

        print("🎵 Starting Spotify OAuth flow...")
        print("🔑 State: \(state)")

        // Build authorization URL
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: requiredScopes.joined(separator: " ")),
            URLQueryItem(name: "show_dialog", value: "true")
        ]

        guard let authURL = components.url else {
            throw OAuthError.invalidResponse
        }

        print("🌐 Opening Spotify authorization page...")
        print("📍 Redirect URI: \(redirectURI)")

        // Open authorization URL in browser
        NSWorkspace.shared.open(authURL)

        // Wait for callback with authorization code
        return try await withCheckedThrowingContinuation { continuation in
            self.authenticationContinuation = continuation

            print("⏳ Waiting for OAuth callback...")

            // Register for URL callback
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("SpotifyOAuthCallback"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                print("📨 Received OAuth callback notification")
                self?.handleCallback(notification, expectedState: state)
            }
        }
    }

    /// Handle OAuth callback from URL scheme
    func handleCallback(_ notification: Notification, expectedState: String) {
        // Remove observer to prevent duplicate calls
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("SpotifyOAuthCallback"), object: nil)

        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? URL else {
            print("❌ Invalid callback - no URL in notification")
            authenticationContinuation?.resume(throwing: OAuthError.invalidResponse)
            return
        }

        print("✅ Received callback URL: \(url.absoluteString)")

        // Parse URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("❌ Failed to parse URL components")
            authenticationContinuation?.resume(throwing: OAuthError.invalidResponse)
            return
        }

        // Check for error
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            print("❌ OAuth error from Spotify: \(error)")
            if error == "access_denied" {
                authenticationContinuation?.resume(throwing: OAuthError.userCancelled)
            } else {
                authenticationContinuation?.resume(throwing: OAuthError.serverError(error))
            }
            return
        }

        // Verify state (CSRF protection)
        guard let state = queryItems.first(where: { $0.name == "state" })?.value,
              state == expectedState else {
            print("❌ State mismatch - possible CSRF attack")
            print("   Expected: \(expectedState)")
            print("   Received: \(queryItems.first(where: { $0.name == "state" })?.value ?? "nil")")
            authenticationContinuation?.resume(throwing: OAuthError.invalidResponse)
            return
        }

        print("✅ State verified")

        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            print("❌ No authorization code in callback")
            authenticationContinuation?.resume(throwing: OAuthError.invalidResponse)
            return
        }

        print("✅ Authorization code received: \(code.prefix(10))...")

        // Exchange code for token
        print("🔄 Exchanging code for access token...")
        Task {
            do {
                let token = try await self.exchangeCodeForToken(code)
                print("✅ Successfully obtained access token")
                self.authenticationContinuation?.resume(returning: token)
            } catch {
                print("❌ Failed to exchange code for token: \(error)")
                self.authenticationContinuation?.resume(throwing: error)
            }
        }
    }

    /// Exchange authorization code for access token
    private func exchangeCodeForToken(_ code: String) async throws -> OAuthToken {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Spotify requires Basic auth with client_id:client_secret
        let credentials = "\(clientID):\(clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }

        let bodyParams = [
            "code": code,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.invalidResponse
        }

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)

        return OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in)),
            scopes: tokenResponse.scope?.components(separatedBy: " ") ?? requiredScopes,
            serviceName: serviceName,
            tokenType: tokenResponse.token_type
        )
    }

    // MARK: - Token Refresh

    func refreshToken(_ token: OAuthToken) async throws -> OAuthToken {
        guard let refreshToken = token.refreshToken else {
            throw OAuthError.missingRefreshToken
        }

        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Spotify requires Basic auth
        let credentials = "\(clientID):\(clientSecret)"
        if let credentialsData = credentials.data(using: .utf8) {
            let base64Credentials = credentialsData.base64EncodedString()
            request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        }

        let bodyParams = [
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuthError.invalidResponse
        }

        if httpResponse.statusCode == 400 {
            throw OAuthError.invalidGrant
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.invalidResponse
        }

        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)

        return OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: token.refreshToken, // Keep original if not provided
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in)),
            scopes: token.scopes,
            serviceName: serviceName,
            tokenType: tokenResponse.token_type
        )
    }

    // MARK: - Token Revocation

    func revokeToken(_ token: OAuthToken) async throws {
        // Spotify doesn't have a revoke endpoint
        // Tokens automatically expire, so just delete from Keychain
        print("✅ Spotify token marked for deletion (no revoke endpoint)")
    }
}

// MARK: - Response Models

private struct SpotifyTokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
    let refresh_token: String?
    let scope: String?
}
