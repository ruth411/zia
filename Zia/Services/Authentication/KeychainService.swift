//
//  KeychainService.swift
//  Zia
//
//

import Foundation
import Security

/// Secure storage for OAuth tokens and sensitive data using macOS Keychain.
/// All data is stored as kSecClassGenericPassword entries scoped to this app's bundle identifier.
class KeychainService {

    // MARK: - Properties

    private let serviceName = Configuration.App.bundleIdentifier

    // MARK: - Token Storage

    /// Save an OAuth token to the Keychain.
    func saveToken(_ token: OAuthToken, for service: String) throws {
        let data = try JSONEncoder().encode(token)
        try saveData(data, forKey: "oauth_token_\(service)")
    }

    /// Retrieve an OAuth token from the Keychain.
    func retrieveToken(for service: String) throws -> OAuthToken? {
        guard let data = try retrieveData(forKey: "oauth_token_\(service)") else { return nil }
        return try JSONDecoder().decode(OAuthToken.self, from: data)
    }

    /// Delete an OAuth token from the Keychain.
    func deleteToken(for service: String) throws {
        try deleteData(forKey: "oauth_token_\(service)")
    }

    // MARK: - Generic String Storage

    /// Save a string value to the Keychain.
    func saveString(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try saveData(data, forKey: key)
    }

    /// Retrieve a string value from the Keychain.
    func retrieveString(for key: String) throws -> String? {
        guard let data = try retrieveData(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    /// Delete a string value from the Keychain.
    func deleteString(for key: String) throws {
        try deleteData(forKey: key)
    }

    // MARK: - Private Keychain Primitives

    private func saveData(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      serviceName,
            kSecAttrAccount as String:      key,
            kSecValueData as String:        data,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Always delete existing item first to avoid errSecDuplicateItem
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func retrieveData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.retrieveFailed(status)
        }
    }

    private func deleteData(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        // errSecItemNotFound is acceptable — item may not exist
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
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
