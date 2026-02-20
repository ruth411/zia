//
//  ProactiveEngine.swift
//  Zia
//
//

import Combine
import Foundation
import UserNotifications

/// Background engine that runs registered context triggers on a schedule
/// and surfaces proactive notifications via macOS notification center.
class ProactiveEngine: ObservableObject {

    // MARK: - Properties

    @Published private(set) var isRunning = false
    @Published private(set) var recentNotifications: [ProactiveNotification] = []

    private var triggers: [ContextTrigger] = []
    private var timers: [String: Timer] = [:]
    private let maxRecentNotifications = 20

    // MARK: - Setup

    /// Register all triggers
    func registerTriggers(_ triggers: [ContextTrigger]) {
        self.triggers = triggers
        print("ProactiveEngine: Registered \(triggers.count) triggers")
    }

    /// Start the proactive engine — begins evaluating triggers on their intervals
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Request notification permission
        requestNotificationPermission()

        // Create a timer for each trigger
        for trigger in triggers {
            // Run immediately on start
            Task { await evaluateTrigger(trigger) }

            // Then schedule periodic checks
            let timer = Timer.scheduledTimer(
                withTimeInterval: trigger.checkInterval,
                repeats: true
            ) { [weak self] _ in
                Task { [weak self] in
                    await self?.evaluateTrigger(trigger)
                }
            }
            timers[trigger.id] = timer
        }

        print("ProactiveEngine: Started with \(triggers.count) triggers")
    }

    /// Stop all triggers
    func stop() {
        for (_, timer) in timers {
            timer.invalidate()
        }
        timers.removeAll()
        isRunning = false
        print("ProactiveEngine: Stopped")
    }

    // MARK: - Evaluation

    private func evaluateTrigger(_ trigger: ContextTrigger) async {
        guard let notification = await trigger.evaluate() else { return }

        // Send macOS notification
        await sendSystemNotification(notification)

        // Track in recent list
        await MainActor.run {
            recentNotifications.insert(notification, at: 0)
            if recentNotifications.count > maxRecentNotifications {
                recentNotifications.removeLast()
            }
        }
    }

    // MARK: - macOS Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if granted {
                print("ProactiveEngine: Notification permission granted")
            } else if let error = error {
                print("ProactiveEngine: Notification permission error: \(error)")
            }
        }
    }

    private func sendSystemNotification(_ notification: ProactiveNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.categoryIdentifier = notification.category.rawValue

        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            print("ProactiveEngine: Sent notification — \(notification.title)")
        } catch {
            print("ProactiveEngine: Failed to send notification: \(error)")
        }
    }
}
