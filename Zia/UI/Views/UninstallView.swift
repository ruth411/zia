//
//  UninstallView.swift
//  Zia
//
//

import SwiftUI

/// Confirmation view shown before uninstalling Zia.
/// Lists all data that will be removed and provides options to keep data or fully uninstall.
struct UninstallView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var keepData = false
    @State private var showingConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 36))
                    .foregroundColor(.red)

                Text("Uninstall Zia")
                    .font(.title2.weight(.semibold))

                Text("This will remove Zia from your Mac.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            Divider()

            // Data checklist
            VStack(alignment: .leading, spacing: 10) {
                Text("The following will be removed:")
                    .font(.subheadline.weight(.medium))

                dataRow("Zia.app", detail: "The application itself")
                dataRow("Conversations & search index",
                        detail: "~/Library/Application Support/")
                dataRow("User preferences",
                        detail: "~/Library/Preferences/")
                dataRow("Keychain entries",
                        detail: "API key, Spotify tokens")
                dataRow("MCP config & automations",
                        detail: "~/.zia/")
                dataRow("Cached data",
                        detail: "~/Library/Caches/")
            }
            .padding(.horizontal, 4)

            Divider()

            // Keep data toggle
            Toggle(isOn: $keepData) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep my data")
                        .font(.subheadline.weight(.medium))
                    Text("Only remove the app, keep conversations and settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Uninstall") {
                    showingConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 420, height: 480)
        .confirmationDialog(
            "Are you sure?",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall Zia", role: .destructive) {
                performUninstall()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(keepData
                 ? "Zia.app will be moved to Trash. Your data will be kept."
                 : "Zia.app and all associated data will be permanently removed.")
        }
    }

    // MARK: - Subviews

    private func dataRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: keepData ? "circle" : "checkmark.circle.fill")
                .foregroundColor(keepData ? .gray : .red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.medium))
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func performUninstall() {
        if keepData {
            // Just move app to Trash
            guard let appURL = Bundle.main.bundleURL as URL? else { return }
            NSWorkspace.shared.recycle([appURL]) { _, _ in
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        } else {
            UninstallService.uninstallApp()
        }
    }
}
