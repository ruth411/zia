//
//  SettingsView.swift
//  Zia
//
//

import SwiftUI
import Combine
import ServiceManagement

struct SettingsView: View {

    // MARK: - Environment

    @EnvironmentObject var dependencyContainer: DependencyContainer

    @StateObject private var viewModel: SettingsViewModel

    // MARK: - State

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingUninstall = false

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
                    // General section
                    generalSection

                    Divider()

                    // Account section
                    appleAccountSection

                    Divider()

                    // Connected Accounts section
                    accountsSection

                    Divider()

                    // MCP Servers section
                    mcpSection

                    Divider()

                    // Data & Privacy section
                    dataSection

                    Divider()

                    // About section
                    aboutSection

                    Divider()

                    // Uninstall section
                    uninstallSection
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

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.headline)

            Toggle("Launch Zia at Login", isOn: Binding(
                get: { viewModel.launchAtLogin },
                set: { viewModel.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)

            Text("Zia will start automatically when you log in.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var appleAccountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key")
                .font(.headline)

            if viewModel.hasAPIKey {
                // Key is saved — show status + reset button
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anthropic API Key configured")
                            .font(.subheadline.weight(.medium))
                        Text("Your key is stored securely in Keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Reset Key") {
                        viewModel.resetAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                // No key — show entry field directly
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "key")
                            .foregroundColor(.gray)
                        Text("Enter your Anthropic API Key")
                            .font(.subheadline.weight(.medium))
                    }

                    SecureField("sk-ant-...", text: $viewModel.newAPIKey)
                        .textFieldStyle(.roundedBorder)

                    if let error = viewModel.newAPIKeyError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    HStack {
                        Text("Get your key at console.anthropic.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Save Key") {
                            viewModel.saveNewAPIKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.newAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connected Services")
                .font(.headline)

            // Spotify — credentials + OAuth connect in one section
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 30)
                    Text("Spotify")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if viewModel.isSpotifyConnected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Connected").font(.caption).foregroundColor(.green)
                        }
                    }
                }

                Divider()

                // Credentials fields
                VStack(alignment: .leading, spacing: 8) {
                    Text("App Credentials")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)

                    TextField("Client ID", text: $viewModel.spotifyClientID)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    SecureField("Client Secret", text: $viewModel.spotifyClientSecret)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Text("Create an app at developer.spotify.com/dashboard")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack {
                        if viewModel.spotifyCredentialsSaved {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("Saved!").font(.caption).foregroundColor(.green)
                            }
                        }
                        Spacer()
                        Button("Save Credentials") {
                            viewModel.saveSpotifyCredentials()
                        }
                        .buttonStyle(.bordered)
                        .disabled(
                            viewModel.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            viewModel.spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }

                Divider()

                // OAuth connect/disconnect row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.isSpotifyConnected ? "Authorized" : "Not authorized")
                            .font(.caption.weight(.medium))
                        Text("Tap Connect to authorize with your Spotify account")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if viewModel.isConnectingSpotify {
                        ProgressView().scaleEffect(0.8)
                    } else if viewModel.isSpotifyConnected {
                        Button("Disconnect") { disconnectSpotify() }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    } else {
                        Button("Connect") { connectSpotify() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.hasSpotifyCredentials)
                    }
                }

                if !viewModel.hasSpotifyCredentials {
                    Text("Save your credentials above before connecting.")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                // Clear credentials
                if viewModel.hasSpotifyCredentials {
                    Button("Clear Credentials") {
                        viewModel.clearSpotifyCredentials()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

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

    private var mcpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MCP Servers")
                .font(.headline)

            let mcpServers = Array(DependencyContainer.shared.mcpClientManager.servers.values)

            if mcpServers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No MCP servers configured")
                        .font(.subheadline.weight(.medium))
                    Text("Add servers to ~/.zia/mcp.json to extend Zia with additional tools.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                ForEach(mcpServers) { server in
                    HStack(spacing: 12) {
                        Image(systemName: mcpServerIcon(for: server.state))
                            .foregroundColor(mcpServerColor(for: server.state))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(.subheadline.weight(.medium))
                            Text(mcpServerSubtitle(for: server))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if server.state == .connected {
                            Text("\(server.toolCount) tools")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }

            Button("Reload MCP Config") {
                Task { @MainActor in
                    await DependencyContainer.shared.mcpClientManager.reloadConfig()
                    DependencyContainer.shared.mcpClientManager.registerTools(
                        in: DependencyContainer.shared.toolRegistry
                    )
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func mcpServerIcon(for state: MCPServerState) -> String {
        switch state {
        case .connected: return "checkmark.circle.fill"
        case .connecting: return "arrow.clockwise.circle"
        case .disconnected: return "circle"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    private func mcpServerColor(for state: MCPServerState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .gray
        case .failed: return .red
        }
    }

    private func mcpServerSubtitle(for server: MCPServerStatus) -> String {
        switch server.state {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Disconnected"
        case .failed(let msg): return "Error: \(msg.prefix(50))"
        }
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

                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Open source - github.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var uninstallSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)
                .foregroundColor(.red)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Uninstall Zia")
                        .font(.subheadline.weight(.medium))
                    Text("Remove the app and all associated data from your Mac.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Uninstall...") {
                    showingUninstall = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingUninstall) {
            UninstallView()
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
            do { try await viewModel.disconnectSpotify() }
            catch { print("Spotify disconnect failed: \(error)") }
        }
    }
}

// MARK: - View Model

class SettingsViewModel: ObservableObject {

    @Published var isSpotifyConnected = false
    @Published var isConnectingSpotify = false
    @Published var hasAPIKey = false
    @Published var newAPIKey: String = ""
    @Published var newAPIKeyError: String? = nil
    @Published var spotifyClientID: String = ""
    @Published var spotifyClientSecret: String = ""
    @Published var hasSpotifyCredentials: Bool = false
    @Published var spotifyCredentialsSaved: Bool = false
    @Published var indexedMessageCount: Int = 0
    @Published var indexSizeDisplay: String = "0 KB"
    @Published var isReindexing = false
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            print("Launch at login error: \(error)")
        }
    }

    private let authManager: AuthenticationManager
    private let keychainService = DependencyContainer.shared.keychainService
    private let ragService = DependencyContainer.shared.ragService
    private let conversationStore = DependencyContainer.shared.conversationStore

    init(authManager: AuthenticationManager) {
        self.authManager = authManager

        // Load authentication status
        self.isSpotifyConnected = authManager.isSpotifyAuthenticated

        // Check if API key is stored
        self.hasAPIKey = (try? keychainService.retrieveString(for: Configuration.Keys.Keychain.claudeAPIKey)) != nil

        // Load Spotify credentials (for display in settings)
        let storedClientID = (try? keychainService.retrieveString(for: Configuration.Keys.Keychain.spotifyClientID)) ?? ""
        let storedSecret = (try? keychainService.retrieveString(for: Configuration.Keys.Keychain.spotifyClientSecret)) ?? ""
        self.spotifyClientID = storedClientID
        self.spotifyClientSecret = storedSecret
        self.hasSpotifyCredentials = !storedClientID.isEmpty && !storedSecret.isEmpty

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

    func saveSpotifyCredentials() {
        let id = spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !secret.isEmpty else { return }
        try? keychainService.saveString(id, for: Configuration.Keys.Keychain.spotifyClientID)
        try? keychainService.saveString(secret, for: Configuration.Keys.Keychain.spotifyClientSecret)
        hasSpotifyCredentials = true
        spotifyCredentialsSaved = true
        // Reset the saved confirmation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.spotifyCredentialsSaved = false
        }
    }

    func clearSpotifyCredentials() {
        try? keychainService.deleteString(for: Configuration.Keys.Keychain.spotifyClientID)
        try? keychainService.deleteString(for: Configuration.Keys.Keychain.spotifyClientSecret)
        spotifyClientID = ""
        spotifyClientSecret = ""
        hasSpotifyCredentials = false
        isSpotifyConnected = false
    }

    func resetAPIKey() {
        do { try keychainService.deleteString(for: Configuration.Keys.Keychain.claudeAPIKey) }
        catch { print("Keychain: Failed to delete API key: \(error)") }
        hasAPIKey = false
        newAPIKey = ""
        newAPIKeyError = nil
        Configuration.Onboarding.reset()
    }

    func saveNewAPIKey() {
        let trimmed = newAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("sk-ant-") else {
            newAPIKeyError = "Invalid key — Anthropic keys start with \"sk-ant-\""
            return
        }
        do {
            try keychainService.saveString(trimmed, for: Configuration.Keys.Keychain.claudeAPIKey)
            hasAPIKey = true
            newAPIKey = ""
            newAPIKeyError = nil
            Configuration.Onboarding.markCompleted()
        } catch {
            newAPIKeyError = "Failed to save key: \(error.localizedDescription)"
        }
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
