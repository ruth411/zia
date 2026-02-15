//
//  APIKeyStepView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Step for selecting AI provider and entering API key
struct APIKeyStepView: View {

    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)

                Text("AI Provider Setup")
                    .font(.title2.bold())

                Text("Choose your AI provider and enter your API key.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            // Provider selection
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    ForEach(AIProviderType.allCases, id: \.self) { provider in
                        providerButton(provider)
                    }
                }
            }
            .padding(.horizontal, 24)

            // API Key input
            VStack(alignment: .leading, spacing: 8) {
                Text("\(viewModel.selectedAIProvider.displayName) API Key")
                    .font(.subheadline.weight(.medium))

                SecureField("Paste your API key here", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.apiKey) { _, _ in
                        viewModel.apiKeyValid = nil
                        viewModel.apiKeyError = nil
                    }

                if viewModel.selectedAIProvider == .claude {
                    Text("Get your key at console.anthropic.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Get your key at platform.openai.com")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            // Test connection button
            HStack(spacing: 12) {
                Button {
                    Task { await viewModel.testAPIKey() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isTestingAPIKey {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text("Test Connection")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.apiKey.isEmpty || viewModel.isTestingAPIKey)

                // Validation status
                if let valid = viewModel.apiKeyValid {
                    if valid {
                        Label("Valid", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else {
                        Label(viewModel.apiKeyError ?? "Invalid", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Next button
            Button {
                viewModel.saveAPIKey()
                onNext()
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.apiKey.isEmpty)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Subviews

    private func providerButton(_ provider: AIProviderType) -> some View {
        Button {
            viewModel.selectedAIProvider = provider
            viewModel.apiKey = ""
            viewModel.apiKeyValid = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: provider.iconName)
                Text(provider.displayName)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.selectedAIProvider == provider
                        ? Color.blue.opacity(0.2)
                        : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(viewModel.selectedAIProvider == provider
                        ? Color.blue
                        : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
