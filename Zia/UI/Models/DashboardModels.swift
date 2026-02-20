//
//  DashboardModels.swift
//  Zia
//
//

import Foundation
import SwiftUI

/// Category tabs for the dashboard
enum DashboardCategory: String, CaseIterable, Identifiable {
    case today = "Today"
    case calendar = "Calendar"
    case music = "Music"
    case flights = "Flights"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .today: return "sun.max.fill"
        case .calendar: return "calendar"
        case .music: return "music.note"
        case .flights: return "airplane"
        }
    }
}

/// A glance card displayed in the horizontal row
struct GlanceCard: Identifiable {
    let id: String
    let title: String
    var subtitle: String?
    let iconName: String
    let gradientColors: [Color]
    let iconColor: Color
    var badgeCount: Int
    let category: DashboardCategory
    let actionQuery: String

    /// Card type for identifying which card to update with live data
    enum CardType: String {
        case calendar
        case music
        case weather
        case system
    }

    let cardType: CardType

    static let defaults: [GlanceCard] = [
        GlanceCard(
            id: "calendar",
            title: "Calendar",
            subtitle: nil,
            iconName: "calendar",
            gradientColors: [.white, Color(white: 0.93)],
            iconColor: .red,
            badgeCount: 0,
            category: .calendar,
            actionQuery: "What's on my calendar today?",
            cardType: .calendar
        ),
        GlanceCard(
            id: "music",
            title: "Music",
            subtitle: nil,
            iconName: "music.note",
            gradientColors: [.white, Color(white: 0.93)],
            iconColor: Color(red: 0.98, green: 0.18, blue: 0.35),
            badgeCount: 0,
            category: .music,
            actionQuery: "What's playing on Spotify?",
            cardType: .music
        ),
        GlanceCard(
            id: "weather",
            title: "Weather",
            subtitle: nil,
            iconName: "cloud.sun.fill",
            gradientColors: [Color(red: 0.3, green: 0.6, blue: 0.95), Color(red: 0.2, green: 0.4, blue: 0.8)],
            iconColor: .white,
            badgeCount: 0,
            category: .today,
            actionQuery: "What's the weather like?",
            cardType: .weather
        ),
        GlanceCard(
            id: "system",
            title: "System",
            subtitle: nil,
            iconName: "laptopcomputer",
            gradientColors: [Color(white: 0.15), Color(white: 0.22)],
            iconColor: .white,
            badgeCount: 0,
            category: .today,
            actionQuery: "How's my system doing?",
            cardType: .system
        )
    ]
}

/// An item in the action/response feed
struct ActionFeedItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let bulletPoints: [String]
    let status: ActionStatus
    let timestamp: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        bulletPoints: [String] = [],
        status: ActionStatus = .inProgress,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.bulletPoints = bulletPoints
        self.status = status
        self.timestamp = timestamp
    }

    enum ActionStatus {
        case inProgress
        case completed
        case failed
    }
}

/// A suggestion shown below the input bar
struct Suggestion: Identifiable {
    let id = UUID()
    let text: String
    let iconName: String

    static let defaults: [Suggestion] = [
        Suggestion(text: "Play some jazz", iconName: "music.note"),
        Suggestion(text: "What's on my calendar?", iconName: "calendar"),
        Suggestion(text: "Check my flights", iconName: "airplane")
    ]
}
