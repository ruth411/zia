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
    @State private var isUninstalling = false

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

                Button {
                    isUninstalling = true
                    // Small delay so SwiftUI renders the "Uninstalling…" label
                    // before we call exit(0) inside performUninstall()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        performUninstall()
                    }
                } label: {
                    if isUninstalling {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.75)
                            Text("Uninstalling…")
                        }
                    } else {
                        Text("Uninstall")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isUninstalling)
            }
        }
        .padding(24)
        .frame(minWidth: 420, maxWidth: 420, minHeight: 540)
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
            // Only move the app bundle; leave all user data intact
            UninstallService.moveAppToTrashAndQuit()
        } else {
            UninstallService.uninstallApp()
        }
    }
}
