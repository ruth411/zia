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
        static let redirectURI = "com.yourcompany.zia://oauth2callback"

        struct Google {
            // TODO: Replace with your Google OAuth Client ID from Google Cloud Console
            static let clientID = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"

            static let scopes = [
                "https://www.googleapis.com/auth/gmail.modify",
                "https://www.googleapis.com/auth/calendar"
            ]
        }

        struct Spotify {
            // TODO: Replace with your Spotify Client ID from Spotify Developer Dashboard
            static let clientID = "YOUR_SPOTIFY_CLIENT_ID"
            static let clientSecret = "YOUR_SPOTIFY_CLIENT_SECRET"

            static let scopes = [
                "user-read-playback-state",
                "user-modify-playback-state",
                "playlist-modify-private",
                "user-library-read"
            ]
        }
    }

    // MARK: - API Endpoints

    struct API {
        struct Claude {
            static let baseURL = "https://api.anthropic.com/v1"
            static let model = "claude-3-5-sonnet-20241022"
            static let apiVersion = "2023-06-01"
            static let maxTokens = 4096
        }

        struct Gmail {
            static let baseURL = "https://gmail.googleapis.com/gmail/v1"
        }

        struct GoogleCalendar {
            static let baseURL = "https://www.googleapis.com/calendar/v3"
        }

        struct Spotify {
            static let baseURL = "https://api.spotify.com/v1"
        }
    }

    // MARK: - App Settings

    struct App {
        static let bundleIdentifier = "com.yourcompany.Zia"
        static let menuBarIconName = "atom" // SF Symbol - atom structure
        static let popoverWidth: CGFloat = 360
        static let popoverHeight: CGFloat = 600
        static let maxConversationHistory = 50
    }

    // MARK: - CloudKit

    struct CloudKit {
        static let containerIdentifier = "iCloud.com.yourcompany.Zia"
    }

    // MARK: - Scheduling

    struct Scheduler {
        static let timerInterval: TimeInterval = 60 // Check every 60 seconds
        static let flightCheckInterval: TimeInterval = 900 // Check for flights every 15 minutes
    }
}
