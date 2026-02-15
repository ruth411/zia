//
//  BackendAuthService.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation
import Combine

/// HTTP client for the Zia backend auth API.
/// Manages registration, login, token storage, and profile fetching.
class BackendAuthService: ObservableObject {

    // MARK: - Published Properties

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: BackendUser?
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private let keychainService: KeychainService
    private let accessTokenKey = "backend_access_token"
    private let refreshTokenKey = "backend_refresh_token"

    private var baseURL: String {
        Configuration.Backend.baseURL
    }

    // MARK: - Initialization

    init(keychainService: KeychainService) {
        self.keychainService = keychainService
        loadStoredSession()
    }

    // MARK: - Public Methods

    /// Register a new account
    func register(email: String, password: String, name: String?) async throws -> AuthTokens {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "name": name ?? ""
        ]

        let data = try await request(
            method: "POST",
            path: "/auth/register",
            body: body,
            authenticated: false
        )

        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        let tokens = AuthTokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token
        )

        try storeTokens(tokens)
        await fetchProfile()
        return tokens
    }

    /// Log in with email and password
    func login(email: String, password: String) async throws -> AuthTokens {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        let data = try await request(
            method: "POST",
            path: "/auth/login",
            body: body,
            authenticated: false
        )

        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        let tokens = AuthTokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token
        )

        try storeTokens(tokens)
        await fetchProfile()
        return tokens
    }

    /// Refresh the access token using the stored refresh token
    func refreshAccessToken() async throws -> AuthTokens {
        guard let refreshToken = try? keychainService.retrieveString(for: refreshTokenKey) else {
            throw BackendAuthError.noRefreshToken
        }

        let body: [String: Any] = [
            "refresh_token": refreshToken
        ]

        let data = try await request(
            method: "POST",
            path: "/auth/refresh",
            body: body,
            authenticated: false
        )

        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        let tokens = AuthTokens(
            accessToken: response.access_token,
            refreshToken: response.refresh_token
        )

        try storeTokens(tokens)
        return tokens
    }

    /// Fetch the current user's profile
    @MainActor
    func fetchProfile() async {
        do {
            let data = try await request(
                method: "GET",
                path: "/auth/me",
                authenticated: true
            )

            let user = try JSONDecoder().decode(BackendUser.self, from: data)
            self.currentUser = user
            self.isLoggedIn = true
        } catch {
            // If 401, try refreshing token
            if case BackendAuthError.unauthorized = error {
                do {
                    _ = try await refreshAccessToken()
                    let data = try await request(
                        method: "GET",
                        path: "/auth/me",
                        authenticated: true
                    )
                    let user = try JSONDecoder().decode(BackendUser.self, from: data)
                    self.currentUser = user
                    self.isLoggedIn = true
                } catch {
                    logout()
                }
            } else {
                print("Failed to fetch profile: \(error)")
            }
        }
    }

    /// Update the user's name
    func updateProfile(name: String) async throws -> BackendUser {
        let body: [String: Any] = ["name": name]

        let data = try await request(
            method: "PUT",
            path: "/auth/me",
            body: body,
            authenticated: true
        )

        let user = try JSONDecoder().decode(BackendUser.self, from: data)
        await MainActor.run {
            self.currentUser = user
        }
        return user
    }

    /// Delete the user's account
    func deleteAccount() async throws {
        _ = try await request(
            method: "DELETE",
            path: "/auth/me",
            authenticated: true
        )

        await MainActor.run {
            logout()
        }
    }

    /// Sign out — clears stored tokens and user data
    func logout() {
        try? keychainService.deleteString(for: accessTokenKey)
        try? keychainService.deleteString(for: refreshTokenKey)
        isLoggedIn = false
        currentUser = nil
    }

    /// Check for existing session on app launch
    func loadStoredSession() {
        guard let accessToken = try? keychainService.retrieveString(for: accessTokenKey),
              !accessToken.isEmpty else {
            isLoggedIn = false
            return
        }

        // We have a stored token — mark as logged in and fetch profile in background
        isLoggedIn = true
        Task {
            await fetchProfile()
        }
    }

    // MARK: - Private Methods

    private func storeTokens(_ tokens: AuthTokens) throws {
        try keychainService.saveString(tokens.accessToken, for: accessTokenKey)
        try keychainService.saveString(tokens.refreshToken, for: refreshTokenKey)
    }

    private func request(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        authenticated: Bool
    ) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw BackendAuthError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            guard let token = try? keychainService.retrieveString(for: accessTokenKey) else {
                throw BackendAuthError.unauthorized
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAuthError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200, 201:
            return data
        case 204:
            return Data()
        case 401:
            throw BackendAuthError.unauthorized
        case 409:
            throw BackendAuthError.emailTaken
        case 422:
            // Parse validation error
            if let errorBody = try? JSONDecoder().decode(ValidationError.self, from: data) {
                throw BackendAuthError.validationError(errorBody.detail.first?.msg ?? "Invalid input")
            }
            throw BackendAuthError.validationError("Invalid input")
        default:
            if let errorBody = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw BackendAuthError.serverError(errorBody.detail)
            }
            throw BackendAuthError.serverError("Status \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Types

struct AuthTokens {
    let accessToken: String
    let refreshToken: String
}

struct BackendUser: Codable {
    let id: String
    let email: String
    let name: String?
}

// MARK: - API Response Types

private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let token_type: String
}

private struct ErrorResponse: Codable {
    let detail: String
}

private struct ValidationError: Codable {
    let detail: [ValidationDetail]
}

private struct ValidationDetail: Codable {
    let msg: String
}

// MARK: - Errors

enum BackendAuthError: LocalizedError {
    case invalidURL
    case unauthorized
    case emailTaken
    case noRefreshToken
    case validationError(String)
    case networkError(String)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .unauthorized:
            return "Session expired. Please log in again."
        case .emailTaken:
            return "An account with this email already exists"
        case .noRefreshToken:
            return "No refresh token available"
        case .validationError(let msg):
            return msg
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .serverError(let msg):
            return "Server error: \(msg)"
        }
    }
}
