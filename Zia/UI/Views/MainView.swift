//
//  MainView.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import SwiftUI

/// Main view displayed in the menu bar popover
struct MainView: View {

    // MARK: - Environment

    @EnvironmentObject var dependencyContainer: DependencyContainer

    // MARK: - State

    @State private var messageText: String = ""

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Chat area (placeholder for Phase 3)
            chatPlaceholderView

            Divider()

            // Input area
            inputView
        }
        .frame(
            width: Configuration.App.popoverWidth,
            height: Configuration.App.popoverHeight
        )
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "atom")
                .font(.title2)
                .foregroundColor(.blue)

            Text("Zia")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Settings")

            Button(action: quitApp) {
                Image(systemName: "xmark.circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Quit Zia")
        }
        .padding()
    }

    private var chatPlaceholderView: some View {
        VStack {
            Spacer()

            Image(systemName: "atom")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))

            Text("Welcome to Zia")
                .font(.title)
                .fontWeight(.semibold)
                .padding(.top)

            Text("Your AI personal assistant")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Chat integration coming in Phase 3...")
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var inputView: some View {
        HStack(spacing: 12) {
            TextField("Ask Zia anything...", text: $messageText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .disabled(true) // Disabled until Phase 3

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .disabled(true) // Disabled until Phase 3
            .help("Send message")
        }
        .padding()
    }

    // MARK: - Actions

    private func sendMessage() {
        // TODO: Phase 3 - Send message to Claude API
        print("📤 Send message: \(messageText)")
        messageText = ""
    }

    private func openSettings() {
        // TODO: Phase 2 - Open settings window
        print("⚙️ Open settings")
        let alert = NSAlert()
        alert.messageText = "Settings"
        alert.informativeText = "Settings UI will be implemented in Phase 2 (Authentication)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(DependencyContainer.shared)
}
