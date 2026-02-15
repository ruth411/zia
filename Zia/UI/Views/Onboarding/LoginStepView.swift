//
//  LoginStepView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Login / Sign Up view for onboarding (replaces Apple Sign In)
struct LoginStepView: View {

    // MARK: - Properties

    @ObservedObject var authService: BackendAuthService
    let onNext: () -> Void

    // MARK: - State

    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            Image(systemName: "person.crop.circle")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            // Title
            Text(isLoginMode ? "Log In" : "Create Account")
                .font(.title2.weight(.bold))

            // Mode toggle
            Picker("Mode", selection: $isLoginMode) {
                Text("Log In").tag(true)
                Text("Sign Up").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            // Form fields
            VStack(spacing: 12) {
                if !isLoginMode {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if !isLoginMode {
                    Text("Password must be at least 6 characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)

            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Action button
            Button(action: submit) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    Text(isLoginMode ? "Log In" : "Create Account")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .disabled(isLoading || !isFormValid)

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 6
        return emailValid && passwordValid
    }

    // MARK: - Actions

    private func submit() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if isLoginMode {
                    _ = try await authService.login(email: email, password: password)
                } else {
                    _ = try await authService.register(
                        email: email,
                        password: password,
                        name: name.isEmpty ? nil : name
                    )
                }

                await MainActor.run {
                    isLoading = false
                    onNext()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
