//
//  ContextTrigger.swift
//  Zia
//
//

import Foundation

/// Protocol for proactive context triggers.
/// Each trigger checks a condition and returns a notification if action is needed.
protocol ContextTrigger {
    /// Unique identifier for this trigger
    var id: String { get }

    /// Human-readable name
    var name: String { get }

    /// How often this trigger should be checked (in seconds)
    var checkInterval: TimeInterval { get }

    /// Evaluate the trigger condition. Returns a notification if triggered, nil otherwise.
    func evaluate() async -> ProactiveNotification?
}

/// A notification produced by a proactive trigger
struct ProactiveNotification {
    let id: String
    let title: String
    let body: String
    let category: NotificationCategory
    let actionURL: String?
    let timestamp: Date

    enum NotificationCategory: String {
        case calendar
        case system
        case reminder
        case briefing
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        category: NotificationCategory,
        actionURL: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.actionURL = actionURL
        self.timestamp = timestamp
    }
}
