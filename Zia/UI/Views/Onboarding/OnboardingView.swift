//
//  OnboardingView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI
import Combine

/// Multi-step onboarding flow for first-time setup
struct OnboardingView: View {

    // MARK: - State

    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentStep: OnboardingStep = .welcome

    let onComplete: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Step content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView(onNext: { currentStep = .login })
                case .login:
                    LoginStepView(
                        authService: DependencyContainer.shared.backendAuthService,
                        onNext: { currentStep = .apiKey }
                    )
                case .apiKey:
                    APIKeyStepView(viewModel: viewModel, onNext: { currentStep = .spotify })
                case .spotify:
                    SpotifyStepView(viewModel: viewModel, onNext: { currentStep = .completion })
                case .completion:
                    CompletionStepView(viewModel: viewModel, onFinish: {
                        Configuration.Onboarding.markCompleted()
                        onComplete()
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
            width: Configuration.App.popoverWidth,
            height: Configuration.App.popoverHeight
        )
        .background(.ultraThinMaterial)
    }

    // MARK: - Subviews

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue
                        ? Color.blue
                        : Color.white.opacity(0.2))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
}

// MARK: - Step Enum

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case login = 1
    case apiKey = 2
    case spotify = 3
    case completion = 4
}

// MARK: - Onboarding View Model

class OnboardingViewModel: ObservableObject {

    // MARK: - AI Provider

    @Published var selectedAIProvider: AIProviderType = .claude
    @Published var apiKey: String = ""
    @Published var isTestingAPIKey = false
    @Published var apiKeyValid: Bool? = nil
    @Published var apiKeyError: String? = nil

    // MARK: - Spotify

    @Published var spotifyClientID: String = ""
    @Published var spotifyClientSecret: String = ""
    @Published var isSpotifyConnected = false
    @Published var spotifySkipped = false

    // MARK: - Methods

    /// Test the AI API key by making a lightweight request
    func testAPIKey() async {
        await MainActor.run {
            isTestingAPIKey = true
            apiKeyValid = nil
            apiKeyError = nil
        }

        do {
            if selectedAIProvider == .claude {
                try await testClaudeKey()
            } else {
                try await testOpenAIKey()
            }
            await MainActor.run {
                apiKeyValid = true
                isTestingAPIKey = false
            }
        } catch {
            await MainActor.run {
                apiKeyValid = false
                apiKeyError = error.localizedDescription
                isTestingAPIKey = false
            }
        }
    }

    /// Save AI API key to local storage
    func saveAPIKey() {
        let keychain = KeychainService()
        let keyName = selectedAIProvider == .claude ? "claude_api_key" : "openai_api_key"
        try? keychain.saveString(apiKey, for: keyName)

        // Store which provider was selected
        UserDefaults.standard.set(selectedAIProvider.rawValue, forKey: Configuration.Onboarding.aiProviderKey)
    }

    /// Save Spotify credentials to local storage
    func saveSpotifyCredentials() {
        let bundleID = Configuration.App.bundleIdentifier
        UserDefaults.standard.set(spotifyClientID, forKey: "\(bundleID).spotify_client_id")
        UserDefaults.standard.set(spotifyClientSecret, forKey: "\(bundleID).spotify_client_secret")
    }

    // MARK: - Private

    private func testClaudeKey() async throws {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Configuration.API.Claude.model,
            "max_tokens": 10,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw NSError(domain: "Zia", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
        }
        // Any non-401 response means the key is valid:
        // 200 = success, 400 = bad request, 404 = model not found, 429 = rate limited
        // Only 401 means the key itself is invalid
    }

    private func testOpenAIKey() async throws {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        if http.statusCode == 401 {
            throw NSError(domain: "Zia", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
        }
        if http.statusCode != 200 {
            throw NSError(domain: "Zia", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Unexpected status: \(http.statusCode)"])
        }
    }
}

// MARK: - AI Provider Type

enum AIProviderType: String, CaseIterable {
    case claude = "claude"
    case openai = "openai"

    var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI (GPT)"
        }
    }

    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .openai: return "cpu"
        }
    }
}
