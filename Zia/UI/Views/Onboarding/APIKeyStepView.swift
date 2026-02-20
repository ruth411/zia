//
//  APIKeyStepView.swift
//  Zia
//
//

import SwiftUI

/// Onboarding step where users enter their Anthropic API key.
/// The key is validated with a test request and stored in Keychain.
struct APIKeyStepView: View {

    // MARK: - Properties

    let onNext: () -> Void

    // MARK: - State

    @State private var apiKey = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var isValid = false

    private let keychainService = DependencyContainer.shared.keychainService

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            // Title
            Text("Enter Your API Key")
                .font(.title2.weight(.bold))

            Text("Zia uses Claude to power its AI. Your key stays on your Mac, stored securely in Keychain.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // API Key input
            VStack(alignment: .leading, spacing: 8) {
                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: apiKey) { _ in
                        isValid = false
                        errorMessage = nil
                    }

                Button("Get an API key from Anthropic") {
                    if let url = URL(string: "https://console.anthropic.com/settings/keys") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 32)

            // Validation status
            if let errorMessage = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                .font(.caption)
                .padding(.horizontal, 32)
            }

            if isValid {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API key is valid")
                        .foregroundColor(.green)
                }
                .font(.caption)
            }

            // Action buttons
            VStack(spacing: 12) {
                Button(action: validateAndSave) {
                    if isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        Text(isValid ? "Continue" : "Validate & Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isValidating || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Skip for now") {
                    onNext()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Actions

    private func validateAndSave() {
        if isValid {
            onNext()
            return
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            errorMessage = "Please enter an API key"
            return
        }

        isValidating = true
        errorMessage = nil

        Task {
            do {
                try await validateAPIKey(trimmedKey)

                // Save to Keychain
                try keychainService.saveString(trimmedKey, for: Configuration.Keys.Keychain.claudeAPIKey)

                await MainActor.run {
                    isValidating = false
                    isValid = true
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    errorMessage = "Invalid API key: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Validate the API key by making a minimal test request to Claude
    private func validateAPIKey(_ key: String) async throws {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw ValidationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(Configuration.API.Claude.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 15

        // Minimal request to validate the key
        let body: [String: Any] = [
            "model": Configuration.API.Claude.model,
            "max_tokens": 10,
            "messages": [["role": "user", "content": "hi"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ValidationError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return // Valid
        case 401:
            throw ValidationError.unauthorized
        case 403:
            throw ValidationError.forbidden
        default:
            throw ValidationError.httpError(httpResponse.statusCode)
        }
    }

    enum ValidationError: LocalizedError {
        case invalidURL
        case invalidResponse
        case unauthorized
        case forbidden
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API URL"
            case .invalidResponse: return "Invalid response"
            case .unauthorized: return "Invalid API key"
            case .forbidden: return "API key does not have permission"
            case .httpError(let code): return "HTTP error \(code)"
            }
        }
    }
}
