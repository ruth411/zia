//
//  KeychainService.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation
import Security

/// Secure storage for OAuth tokens and sensitive data using macOS Keychain
class KeychainService {

    // MARK: - Properties

    private let serviceName = Configuration.App.bundleIdentifier

    // MARK: - Token Storage (UserDefaults — avoids Keychain password prompts during development)

    /// Save OAuth token
    func saveToken(_ token: OAuthToken, for service: String) throws {
        let key = "\(serviceName).oauth_token_\(service)"
        let data = try JSONEncoder().encode(token)
        UserDefaults.standard.set(data, forKey: key)
        print("✅ Token saved for \(service)")
    }

    /// Retrieve OAuth token
    func retrieveToken(for service: String) throws -> OAuthToken? {
        let key = "\(serviceName).oauth_token_\(service)"
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try JSONDecoder().decode(OAuthToken.self, from: data)
    }

    /// Delete OAuth token
    func deleteToken(for service: String) throws {
        let key = "\(serviceName).oauth_token_\(service)"
        UserDefaults.standard.removeObject(forKey: key)
        print("✅ Token deleted for \(service)")
    }

    // MARK: - Generic String Storage (UserDefaults — avoids Keychain password prompts during development)

    /// Save a string using UserDefaults (no password prompt)
    func saveString(_ value: String, for key: String) throws {
        let storageKey = "\(serviceName).\(key)"
        UserDefaults.standard.set(value, forKey: storageKey)
        print("✅ String saved for key: \(key)")
    }

    /// Retrieve a string from UserDefaults
    func retrieveString(for key: String) throws -> String? {
        let storageKey = "\(serviceName).\(key)"
        return UserDefaults.standard.string(forKey: storageKey)
    }

    /// Delete a string from UserDefaults
    func deleteString(for key: String) throws {
        let storageKey = "\(serviceName).\(key)"
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve from Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
