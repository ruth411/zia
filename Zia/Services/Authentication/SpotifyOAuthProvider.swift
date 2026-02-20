//
//  SpotifyOAuthProvider.swift
//  Zia
//
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
        guard var components = URLComponents(string: authorizationEndpoint) else {
            throw OAuthError.invalidResponse
        }
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

            // Register for URL callback
            NotificationCenter.default.addObserver(
                forName: Configuration.Keys.Notifications.spotifyOAuthCallback,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleCallback(notification, expectedState: state)
            }

            // 5-minute timeout: cancel the continuation if user never completes OAuth
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                guard let self, let pending = self.authenticationContinuation else { return }
                self.authenticationContinuation = nil
                NotificationCenter.default.removeObserver(
                    self,
                    name: Configuration.Keys.Notifications.spotifyOAuthCallback,
                    object: nil
                )
                pending.resume(throwing: OAuthError.timeout)
            }
        }
    }

    /// Handle OAuth callback from URL scheme
    func handleCallback(_ notification: Notification, expectedState: String) {
        // Remove observer to prevent duplicate calls
        NotificationCenter.default.removeObserver(self, name: Configuration.Keys.Notifications.spotifyOAuthCallback, object: nil)

        guard let userInfo = notification.userInfo,
              let url = userInfo["url"] as? URL else {
            authenticationContinuation?.resume(throwing: OAuthError.invalidResponse)
            return
        }

        // Parse URL components
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            authenticationContinuation?.resume(throwing: OAuthError.invalidResponse)
            return
        }

        // Check for error
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
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
                // Nil out before resuming to prevent double-resume if timeout fires concurrently
                let pending = self.authenticationContinuation
                self.authenticationContinuation = nil
                pending?.resume(returning: token)
            } catch {
                print("❌ Failed to exchange code for token: \(error)")
                let pending = self.authenticationContinuation
                self.authenticationContinuation = nil
                pending?.resume(throwing: error)
            }
        }
    }

    /// Exchange authorization code for access token
    private func exchangeCodeForToken(_ code: String) async throws -> OAuthToken {
        guard let tokenURL = URL(string: tokenEndpoint) else {
            throw OAuthError.invalidResponse
        }
        var request = URLRequest(url: tokenURL)
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

        let encodedBody = try bodyParams.map { key, value -> String in
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw OAuthError.invalidResponse
            }
            return "\(key)=\(encoded)"
        }.joined(separator: "&")
        request.httpBody = encodedBody.data(using: .utf8)

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

        guard let tokenURL = URL(string: tokenEndpoint) else {
            throw OAuthError.invalidResponse
        }
        var request = URLRequest(url: tokenURL)
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

        let encodedRefreshBody = try bodyParams.map { key, value -> String in
            guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw OAuthError.invalidResponse
            }
            return "\(key)=\(encoded)"
        }.joined(separator: "&")
        request.httpBody = encodedRefreshBody.data(using: .utf8)

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
