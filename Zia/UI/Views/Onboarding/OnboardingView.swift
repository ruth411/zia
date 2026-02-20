//
//  OnboardingView.swift
//  Zia
//
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
                    APIKeyStepView(
                        onNext: { currentStep = .spotify }
                    )
                case .spotify:
                    SpotifyStepView(viewModel: viewModel, onNext: { currentStep = .completion })
                case .completion:
                    CompletionStepView(viewModel: viewModel, onFinish: {
                        // Only mark onboarding complete if an API key was actually saved
                        let hasAPIKey = (try? DependencyContainer.shared.keychainService.retrieveString(for: Configuration.Keys.Keychain.claudeAPIKey)) != nil
                        if hasAPIKey {
                            Configuration.Onboarding.markCompleted()
                        }
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
    case spotify = 2
    case completion = 3
}

// MARK: - Onboarding View Model

class OnboardingViewModel: ObservableObject {

    // MARK: - Spotify

    @Published var spotifyClientID: String = ""
    @Published var spotifyClientSecret: String = ""
    @Published var isSpotifyConnected = false
    @Published var isConnectingSpotify = false
    @Published var spotifySkipped = false
    @Published var spotifyError: String? = nil

    // MARK: - Methods

    /// Save Spotify credentials to Keychain (secrets must not live in UserDefaults)
    func saveSpotifyCredentials() {
        let keychain = DependencyContainer.shared.keychainService
        try? keychain.saveString(spotifyClientID, for: Configuration.Keys.Keychain.spotifyClientID)
        try? keychain.saveString(spotifyClientSecret, for: Configuration.Keys.Keychain.spotifyClientSecret)
    }

    /// Save credentials then run the OAuth flow to get an access token
    @MainActor
    func saveAndConnect() async {
        saveSpotifyCredentials()
        isConnectingSpotify = true
        spotifyError = nil
        do {
            try await DependencyContainer.shared.authenticationManager.authenticateSpotify()
            isSpotifyConnected = true
        } catch {
            spotifyError = error.localizedDescription
        }
        isConnectingSpotify = false
    }
}
