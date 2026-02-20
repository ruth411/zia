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

            HStack(spacing: 12) {
                Image(systemName: viewModel.hasAPIKey ? "key.fill" : "key")
                    .font(.system(size: 28))
                    .foregroundColor(viewModel.hasAPIKey ? .blue : .gray)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.hasAPIKey ? "Anthropic API Key configured" : "No API key set")
                        .font(.subheadline.weight(.medium))
                    Text(viewModel.hasAPIKey
                         ? "Your key is stored securely in Keychain"
                         : "Add your key in onboarding to use Zia")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.hasAPIKey {
                    Button("Reset Key") {
                        viewModel.resetAPIKey()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
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

    func resetAPIKey() {
        do { try keychainService.deleteString(for: Configuration.Keys.Keychain.claudeAPIKey) }
        catch { print("Keychain: Failed to delete API key: \(error)") }
        hasAPIKey = false
        Configuration.Onboarding.reset()
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
