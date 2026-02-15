//
//  CompletionStepView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Final onboarding step showing setup summary
struct CompletionStepView: View {

    @ObservedObject var viewModel: OnboardingViewModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("You're all set!")
                .font(.title2.bold())

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                summaryRow(
                    icon: "brain.head.profile",
                    title: "AI Assistant",
                    value: "Claude (Powered by Zia)",
                    isConfigured: true
                )

                summaryRow(
                    icon: "music.note",
                    title: "Spotify",
                    value: viewModel.spotifySkipped ? "Skipped" : "Configured",
                    isConfigured: !viewModel.spotifySkipped
                )

                summaryRow(
                    icon: "calendar",
                    title: "Calendar & Reminders",
                    value: "Native macOS",
                    isConfigured: true
                )
            }
            .padding(.horizontal, 32)

            // Note about settings
            Text("You can change these settings anytime\nfrom the gear icon in the dashboard.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Start button
            Button(action: onFinish) {
                Text("Start Using Zia")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Subviews

    private func summaryRow(icon: String, title: String, value: String, isConfigured: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isConfigured ? .blue : .gray)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: isConfigured ? "checkmark.circle.fill" : "minus.circle")
                .foregroundColor(isConfigured ? .green : .gray)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(8)
    }
}
