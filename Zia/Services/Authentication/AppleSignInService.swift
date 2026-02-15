//
//  AppleSignInService.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation
import AuthenticationServices
import Combine

/// Handles Sign in with Apple for user identification.
/// For local-only use, Apple ID is informational (shows name in header).
/// For future enterprise, it becomes the user identifier for backend auth.
class AppleSignInService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isSignedIn: Bool = false
    @Published var userName: String?
    @Published var userEmail: String?

    // MARK: - Properties

    private let userIDKey = "\(Configuration.App.bundleIdentifier).appleUserID"
    private let userNameKey = "\(Configuration.App.bundleIdentifier).appleUserName"
    private let userEmailKey = "\(Configuration.App.bundleIdentifier).appleUserEmail"

    private var signInContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Initialization

    override init() {
        super.init()
        loadCachedUser()
    }

    // MARK: - Public Methods

    /// Current Apple user identifier (nil if not signed in)
    var currentUserID: String? {
        UserDefaults.standard.string(forKey: userIDKey)
    }

    /// Start Sign in with Apple flow
    func signIn() async throws {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }
    }

    /// Sign out (clear local data)
    func signOut() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)

        isSignedIn = false
        userName = nil
        userEmail = nil
    }

    /// Check if the Apple ID credential is still valid
    func checkCredentialState() {
        guard let userID = currentUserID else {
            isSignedIn = false
            return
        }

        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    self?.isSignedIn = true
                case .revoked, .notFound:
                    self?.signOut()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Private

    private func loadCachedUser() {
        if let userID = UserDefaults.standard.string(forKey: userIDKey), !userID.isEmpty {
            isSignedIn = true
            userName = UserDefaults.standard.string(forKey: userNameKey)
            userEmail = UserDefaults.standard.string(forKey: userEmailKey)
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            signInContinuation?.resume(throwing: AppleSignInError.invalidCredential)
            return
        }

        // Store user info
        UserDefaults.standard.set(credential.user, forKey: userIDKey)

        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                UserDefaults.standard.set(name, forKey: userNameKey)
                userName = name
            }
        }

        if let email = credential.email {
            UserDefaults.standard.set(email, forKey: userEmailKey)
            userEmail = email
        }

        isSignedIn = true
        signInContinuation?.resume()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        signInContinuation?.resume(throwing: error)
    }
}

// MARK: - Errors

enum AppleSignInError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple ID credential"
        }
    }
}
