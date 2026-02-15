//
//  SettingsView.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import SwiftUI
import Combine

struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var dependencyContainer: DependencyContainer

    @StateObject private var viewModel: SettingsViewModel

    // MARK: - State

    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Initialization

    init() {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authManager: DependencyContainer.shared.authenticationManager))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Account section
                    appleAccountSection

                    Divider()

                    // Connected Accounts section
                    accountsSection

                    Divider()

                    // Data & Privacy section
                    dataSection

                    Divider()

                    // About section
                    aboutSection
                }
                .padding()
            }
        }
        .frame(width: 500, height: 650)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundColor(.blue)

            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()
        }
        .padding()
    }

    private var appleAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(viewModel.isBackendLoggedIn ? .blue : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    if let user = viewModel.backendUser {
                        Text(user.name ?? user.email)
                            .font(.subheadline.weight(.medium))
                        Text(user.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not signed in")
                            .font(.subheadline.weight(.medium))
                        Text("Log in to enable cloud features")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if viewModel.isBackendLoggedIn {
                    Button("Log Out") {
                        viewModel.logOutBackend()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Log In") {
                        viewModel.showLoginSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .sheet(isPresented: $viewModel.showLoginSheet) {
            loginSheet
        }
    }

    private var loginSheet: some View {
        VStack {
            LoginStepView(
                authService: DependencyContainer.shared.backendAuthService,
                onNext: {
                    viewModel.showLoginSheet = false
                    viewModel.refreshBackendUser()
                }
            )
        }
        .frame(width: 360, height: 480)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Services")
                .font(.headline)

            // Spotify Account
            if Configuration.OAuth.Spotify.isConfigured {
                accountRow(
                    icon: "music.note",
                    title: "Spotify",
                    subtitle: "Music playback control",
                    isConnected: viewModel.isSpotifyConnected,
                    isConnecting: viewModel.isConnectingSpotify,
                    onConnect: { connectSpotify() },
                    onDisconnect: { disconnectSpotify() }
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                        Text("Spotify")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("Not configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Re-run setup to add Spotify credentials")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }

            // Native macOS Services Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(.green)
                    Text("Calendar & Reminders")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Text("Uses native macOS Calendar and Reminders")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func accountRow(
        icon: String,
        title: String,
        subtitle: String,
        isConnected: Bool,
        isConnecting: Bool,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isConnecting {
                ProgressView()
                    .scaleEffect(0.8)
            } else if isConnected {
                Button("Disconnect") {
                    onDisconnect()
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Connect") {
                    onConnect()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data & Privacy")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("All data stored locally")
                        .font(.subheadline.weight(.medium))
                    Text("Conversations and preferences are stored on your Mac only.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Search Index section
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                    Text("Search Index (RAG)")
                        .font(.subheadline.weight(.medium))
                    Spacer()

                    if viewModel.isReindexing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                HStack {
                    Text("\(viewModel.indexedMessageCount) messages indexed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.indexSizeDisplay)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Rebuild Search Index") {
                    Task {
                        await viewModel.rebuildSearchIndex()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isReindexing)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Re-run setup
            Button("Re-run Setup") {
                viewModel.resetOnboarding()
            }
            .buttonStyle(.bordered)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Zia - AI Personal Assistant")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Open source - github.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func connectSpotify() {
        viewModel.isConnectingSpotify = true

        Task {
            do {
                try await viewModel.connectSpotify()
                await MainActor.run {
                    viewModel.isConnectingSpotify = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    viewModel.isConnectingSpotify = false
                }
            }
        }
    }

    private func disconnectSpotify() {
        Task {
            try? await viewModel.disconnectSpotify()
        }
    }
}

// MARK: - View Model

class SettingsViewModel: ObservableObject {

    @Published var isSpotifyConnected = false
    @Published var isConnectingSpotify = false
    @Published var isBackendLoggedIn = false
    @Published var backendUser: BackendUser?
    @Published var showLoginSheet = false
    @Published var indexedMessageCount: Int = 0
    @Published var indexSizeDisplay: String = "0 KB"
    @Published var isReindexing = false

    private let authManager: AuthenticationManager
    private let backendAuthService = DependencyContainer.shared.backendAuthService
    private let ragService = DependencyContainer.shared.ragService
    private let conversationStore = DependencyContainer.shared.conversationStore

    init(authManager: AuthenticationManager) {
        self.authManager = authManager

        // Load authentication status
        self.isSpotifyConnected = authManager.isSpotifyAuthenticated

        // Load backend auth status
        self.isBackendLoggedIn = backendAuthService.isLoggedIn
        self.backendUser = backendAuthService.currentUser

        // Load RAG index stats
        loadIndexStats()
    }

    @MainActor
    func connectSpotify() async throws {
        try await authManager.authenticateSpotify()
        isSpotifyConnected = true
    }

    @MainActor
    func disconnectSpotify() async throws {
        try await authManager.signOutSpotify()
        isSpotifyConnected = false
    }

    func logOutBackend() {
        backendAuthService.logout()
        isBackendLoggedIn = false
        backendUser = nil
    }

    func refreshBackendUser() {
        isBackendLoggedIn = backendAuthService.isLoggedIn
        backendUser = backendAuthService.currentUser
    }

    func resetOnboarding() {
        Configuration.Onboarding.reset()
    }

    func loadIndexStats() {
        if let stats = try? ragService.indexingStats() {
            indexedMessageCount = stats.totalMessages
            indexSizeDisplay = formatBytes(stats.dbSizeBytes)
        }
    }

    @MainActor
    func rebuildSearchIndex() async {
        isReindexing = true
        do {
            try ragService.reindexAll(conversationStore: conversationStore)
            loadIndexStats()
        } catch {
            print("Failed to rebuild search index: \(error)")
        }
        isReindexing = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        let mb = kb / 1024
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(DependencyContainer.shared)
}
