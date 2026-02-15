//
//  Configuration.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Foundation

/// Central configuration for API keys, endpoints, and app settings
struct Configuration {

    // MARK: - OAuth Configuration

    struct OAuth {
        // Spotify uses custom URL scheme for OAuth callback
        static let redirectURI = "com.ruthwikdovala.zia://oauth2callback"

        struct Spotify {
            /// Spotify Client ID — loaded from UserDefaults (set during onboarding) or Secrets.plist
            static var clientID: String {
                // 1. Check UserDefaults (set during onboarding)
                if let stored = UserDefaults.standard.string(forKey: "\(App.bundleIdentifier).spotify_client_id"),
                   !stored.isEmpty {
                    return stored
                }
                // 2. Fallback to Secrets.plist (for dev convenience)
                if let value = secretsPlist?["SpotifyClientID"] as? String,
                   value != "YOUR_SPOTIFY_CLIENT_ID" {
                    return value
                }
                return ""
            }

            /// Spotify Client Secret — loaded from UserDefaults (set during onboarding) or Secrets.plist
            static var clientSecret: String {
                // 1. Check UserDefaults (set during onboarding)
                if let stored = UserDefaults.standard.string(forKey: "\(App.bundleIdentifier).spotify_client_secret"),
                   !stored.isEmpty {
                    return stored
                }
                // 2. Fallback to Secrets.plist (for dev convenience)
                if let value = secretsPlist?["SpotifyClientSecret"] as? String,
                   value != "YOUR_SPOTIFY_CLIENT_SECRET" {
                    return value
                }
                return ""
            }

            static let scopes = [
                "user-read-playback-state",
                "user-modify-playback-state",
                "playlist-modify-private",
                "user-library-read"
            ]

            /// Whether Spotify credentials have been configured
            static var isConfigured: Bool {
                !clientID.isEmpty && !clientSecret.isEmpty
            }
        }
    }

    // MARK: - Secrets Plist Loader

    /// Load Secrets.plist if it exists (optional, for dev convenience)
    private static var secretsPlist: [String: Any]? = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return nil
        }
        return dict
    }()

    // MARK: - API Endpoints

    struct API {
        struct Claude {
            static let baseURL = "https://api.anthropic.com/v1"
            static let model = "claude-sonnet-4-5-20250929"
            static let apiVersion = "2023-06-01"
            static let maxTokens = 4096
        }

        struct Spotify {
            static let baseURL = "https://api.spotify.com/v1"
        }
    }

    // MARK: - App Settings

    struct App {
        static let bundleIdentifier = "com.ruthwikdovala.Zia"
        static let menuBarIconName = "atom" // SF Symbol - atom structure
        static let popoverWidth: CGFloat = 360
        static let popoverHeight: CGFloat = 600
        static let maxConversationHistory = 50
    }

    // MARK: - Dashboard Layout

    struct Dashboard {
        static let glanceCardIconHeight: CGFloat = 70
        static let glanceCardSpacing: CGFloat = 12
        static let sectionPadding: CGFloat = 16
        static let pillHeight: CGFloat = 28
        static let inputBarCornerRadius: CGFloat = 20
        static let feedItemCornerRadius: CGFloat = 12
    }

    // MARK: - Storage

    struct Storage {
        /// Base directory for Zia's persistent data
        static var appSupportDirectory: URL {
            let fm = FileManager.default
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent(App.bundleIdentifier)
        }

        /// Directory for conversation history JSON files
        static var conversationsDirectory: URL {
            appSupportDirectory.appendingPathComponent("conversations")
        }

        /// File path for user preferences
        static var preferencesFile: URL {
            appSupportDirectory.appendingPathComponent("preferences.json")
        }

        /// File path for RAG search database
        static var searchDatabaseFile: URL {
            appSupportDirectory.appendingPathComponent("search.db")
        }
    }

    // MARK: - RAG

    struct RAG {
        static let maxSearchResults = 10
        static let ftsResultLimit = 30
        static let bm25Weight: Double = 0.4
        static let embeddingWeight: Double = 0.6
        static let minRelevanceScore: Double = 0.1
    }

    // MARK: - Backend

    struct Backend {
        private static let baseURLKey = "\(App.bundleIdentifier).backendURL"

        /// Backend API base URL (defaults to Railway deployment URL)
        static var baseURL: String {
            UserDefaults.standard.string(forKey: baseURLKey)
                ?? "https://zia-production-e66b.up.railway.app"
        }

        static func setBaseURL(_ url: String) {
            UserDefaults.standard.set(url, forKey: baseURLKey)
        }
    }

    // MARK: - Onboarding

    struct Onboarding {
        static let completedKey = "\(App.bundleIdentifier).onboardingCompleted"
        static let aiProviderKey = "\(App.bundleIdentifier).aiProvider"

        static var isCompleted: Bool {
            UserDefaults.standard.bool(forKey: completedKey)
        }

        static func markCompleted() {
            UserDefaults.standard.set(true, forKey: completedKey)
        }

        static func reset() {
            UserDefaults.standard.set(false, forKey: completedKey)
        }
    }

    // MARK: - CloudKit

    struct CloudKit {
        static let containerIdentifier = "iCloud.com.ruthwikdovala.Zia"
    }

    // MARK: - Scheduling

    struct Scheduler {
        static let timerInterval: TimeInterval = 60 // Check every 60 seconds
        static let flightCheckInterval: TimeInterval = 900 // Check for flights every 15 minutes
    }
}
