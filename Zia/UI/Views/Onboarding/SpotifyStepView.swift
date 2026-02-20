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

            // Status
            if let error = viewModel.spotifyError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if viewModel.isSpotifyConnected {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Spotify connected!").font(.subheadline.weight(.medium)).foregroundColor(.green)
                }
            }

            // Buttons
            VStack(spacing: 12) {
                if viewModel.isSpotifyConnected {
                    Button { onNext() } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        Task { await viewModel.saveAndConnect() }
                    } label: {
                        if viewModel.isConnectingSpotify {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Connecting…")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        } else {
                            Text("Save & Connect Spotify")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.spotifyClientID.isEmpty || viewModel.spotifyClientSecret.isEmpty || viewModel.isConnectingSpotify)
                }

                Button {
                    viewModel.spotifySkipped = true
                    onNext()
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isConnectingSpotify)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
