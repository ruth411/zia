//
//  SpotifyStepView.swift
//  Zia
//
//

import SwiftUI

/// Step for entering Spotify API credentials (optional)
struct SpotifyStepView: View {

    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 36))
                    .foregroundColor(.green)

                Text("Spotify Integration")
                    .font(.title2.bold())

                Text("Connect Spotify for music control.\nThis step is optional.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Spotify Client ID
            VStack(alignment: .leading, spacing: 8) {
                Text("Spotify Client ID")
                    .font(.subheadline.weight(.medium))

                TextField("Enter Spotify Client ID", text: $viewModel.spotifyClientID)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 24)

            // Spotify Client Secret
            VStack(alignment: .leading, spacing: 8) {
                Text("Spotify Client Secret")
                    .font(.subheadline.weight(.medium))

                SecureField("Enter Spotify Client Secret", text: $viewModel.spotifyClientSecret)
                    .textFieldStyle(.roundedBorder)

                Text("Create an app at developer.spotify.com/dashboard")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                // Save & Continue
                Button {
                    viewModel.saveSpotifyCredentials()
                    onNext()
                } label: {
                    Text("Save & Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.spotifyClientID.isEmpty || viewModel.spotifyClientSecret.isEmpty)

                // Skip
                Button {
                    viewModel.spotifySkipped = true
                    onNext()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
