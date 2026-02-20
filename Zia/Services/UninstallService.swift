//
//  UninstallService.swift
//  Zia
//
//

import AppKit
import Foundation

/// Handles complete removal of all Zia data and the app itself.
enum UninstallService {

    /// Directories and files that Zia creates
    struct DataLocations {
        static let appSupport = Configuration.Storage.appSupportDirectory
        static let preferences = "\(Configuration.App.bundleIdentifier)"
        static let caches: URL = {
            guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return FileManager.default.temporaryDirectory.appendingPathComponent(Configuration.App.bundleIdentifier)
            }
            return cacheDir.appendingPathComponent(Configuration.App.bundleIdentifier)
        }()
        static let dotZia: URL = {
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zia")
        }()
    }

    /// Remove all Zia data (conversations, preferences, keychain, MCP config, automations)
    static func cleanAllData() {
        let fm = FileManager.default

        // 1. Delete Application Support directory (conversations, RAG index, preferences)
        let appSupportPath = DataLocations.appSupport
        if fm.fileExists(atPath: appSupportPath.path) {
            try? fm.removeItem(at: appSupportPath)
            print("UninstallService: Deleted \(appSupportPath.path)")
        }

        // 2. Delete UserDefaults
        UserDefaults.standard.removePersistentDomain(forName: DataLocations.preferences)
        UserDefaults.standard.synchronize()
        print("UninstallService: Cleared UserDefaults")

        // 3. Delete Keychain entries
        deleteKeychainEntries()

        // 4. Delete ~/.zia/ directory (MCP config, automations)
        let dotZia = DataLocations.dotZia
        if fm.fileExists(atPath: dotZia.path) {
            try? fm.removeItem(at: dotZia)
            print("UninstallService: Deleted \(dotZia.path)")
        }

        // 5. Delete caches
        let caches = DataLocations.caches
        if fm.fileExists(atPath: caches.path) {
            try? fm.removeItem(at: caches)
            print("UninstallService: Deleted \(caches.path)")
        }

        print("UninstallService: All data cleaned")
    }

    /// Move the app to Trash and quit
    static func uninstallApp() {
        cleanAllData()
        moveAppToTrashAndQuit()
    }

    /// Spawn a background shell that waits for the app process to exit, then moves
    /// the bundle to Trash.
    ///
    /// Uses `nohup` so the script is immune to SIGHUP when the parent quits,
    /// then calls `exit(0)` for an immediate OS-level process exit that cannot
    /// be blocked by AppKit or the run loop.
    static func moveAppToTrashAndQuit() {
        let appPath = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        let trashPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash").path

        // Single-quote-escape paths to handle spaces / special characters
        let escapedApp   = appPath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedTrash = trashPath.replacingOccurrences(of: "'", with: "'\\''")
        let script = "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done; /bin/mv -f '\(escapedApp)' '\(escapedTrash)/'"

        // nohup keeps the script alive after the parent process exits
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        task.arguments = ["/bin/sh", "-c", script]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()

        // Give the subprocess a moment to fully launch before we exit
        Thread.sleep(forTimeInterval: 0.25)

        // exit(0) is an immediate OS-level quit — cannot be blocked by AppKit
        exit(0)
    }

    // MARK: - Keychain Cleanup

    private static func deleteKeychainEntries() {
        let keychainQueries: [[String: Any]] = [
            // Claude API key
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Configuration.App.bundleIdentifier,
                kSecAttrAccount as String: Configuration.Keys.Keychain.claudeAPIKey
            ],
            // Spotify tokens
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Configuration.App.bundleIdentifier,
                kSecAttrAccount as String: Configuration.Keys.Keychain.spotifyAccessToken
            ],
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Configuration.App.bundleIdentifier,
                kSecAttrAccount as String: Configuration.Keys.Keychain.spotifyRefreshToken
            ],
            // Backend auth token
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Configuration.App.bundleIdentifier,
                kSecAttrAccount as String: "auth_token"
            ]
        ]

        for query in keychainQueries {
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess {
                let account = query[kSecAttrAccount as String] as? String ?? "unknown"
                print("UninstallService: Deleted keychain entry '\(account)'")
            }
        }
    }
}
