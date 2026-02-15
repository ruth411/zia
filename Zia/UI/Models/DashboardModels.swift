//
//  DashboardModels.swift
//  Zia
//
//  Created by Claude on 2/14/26.
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
    let id = UUID()
    let title: String
    let subtitle: String?
    let iconName: String
    let gradientColors: [Color]
    let iconColor: Color
    let badgeCount: Int
    let category: DashboardCategory

    static let placeholders: [GlanceCard] = [
        // Calendar — white card, red calendar icon (like macOS Calendar)
        GlanceCard(
            title: "Calendar",
            subtitle: "1,231",
            iconName: "calendar",
            gradientColors: [.white, Color(white: 0.93)],
            iconColor: .red,
            badgeCount: 3,
            category: .calendar
        ),
        // Music — white card, pink/red music note (like Apple Music)
        GlanceCard(
            title: "Music",
            subtitle: nil,
            iconName: "music.note",
            gradientColors: [.white, Color(white: 0.93)],
            iconColor: Color(red: 0.98, green: 0.18, blue: 0.35),
            badgeCount: 0,
            category: .music
        ),
        // Flight — warm orange/brown gradient, white icon
        GlanceCard(
            title: "Flight",
            subtitle: nil,
            iconName: "airplane",
            gradientColors: [Color(red: 0.95, green: 0.55, blue: 0.25), Color(red: 0.8, green: 0.35, blue: 0.15)],
            iconColor: .white,
            badgeCount: 0,
            category: .flights
        ),
        // Flight — dark card, white airplane
        GlanceCard(
            title: "Flight",
            subtitle: nil,
            iconName: "airplane.departure",
            gradientColors: [Color(white: 0.15), Color(white: 0.22)],
            iconColor: .white,
            badgeCount: 1,
            category: .flights
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
