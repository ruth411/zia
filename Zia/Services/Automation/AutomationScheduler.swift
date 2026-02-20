//
//  AutomationScheduler.swift
//  Zia
//
//

import Foundation

/// Runs scheduled automations by checking their schedule against the current time.
/// When an automation is due, it posts a notification that the chat system picks up.
class AutomationScheduler {

    // MARK: - Properties

    private let store: AutomationStore
    private var timer: Timer?
    private var lastRunDates: [String: Date] = [:] // automation ID -> last run time

    // MARK: - Callback

    /// Called when an automation should be executed.
    /// The String parameter is the automation's prompt to send to Claude.
    var onAutomationDue: ((Automation) -> Void)?

    // MARK: - Init

    init(store: AutomationStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    func start() {
        stop()
        // Check every 60 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkScheduledAutomations()
        }
        print("AutomationScheduler: Started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Evaluation

    private func checkScheduledAutomations() {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat

        for automation in store.scheduledAutomations() {
            guard let schedule = automation.schedule else { continue }

            // Check if already run recently
            if let lastRun = lastRunDates[automation.id] {
                let elapsed = now.timeIntervalSince(lastRun)
                switch schedule.frequency {
                case .hourly:
                    if elapsed < 3500 { continue } // ~1 hour
                case .daily, .weekdays, .weekly:
                    if calendar.isDate(lastRun, inSameDayAs: now) { continue }
                }
            }

            // Check frequency
            switch schedule.frequency {
            case .weekdays:
                // Skip weekends (1=Sun, 7=Sat)
                if currentWeekday == 1 || currentWeekday == 7 { continue }
            case .weekly:
                // Only run on Mondays (weekday 2)
                if currentWeekday != 2 { continue }
            case .daily, .hourly:
                break
            }

            // Check time of day (if specified)
            if let timeStr = schedule.timeOfDay {
                let parts = timeStr.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 {
                    let targetHour = parts[0]
                    let targetMinute = parts[1]
                    guard targetHour >= 0 && targetHour <= 23 && targetMinute >= 0 && targetMinute <= 59 else { continue }
                    // Compare total minutes-since-midnight to correctly handle hour boundaries
                    let nowTotal = currentHour * 60 + currentMinute
                    let targetTotal = targetHour * 60 + targetMinute
                    if abs(nowTotal - targetTotal) > 1 {
                        continue
                    }
                }
            } else if schedule.frequency != .hourly {
                // No time specified for non-hourly — default to 9:00 AM
                if currentHour != 9 || currentMinute > 1 { continue }
            }

            // Automation is due — execute it
            lastRunDates[automation.id] = now
            onAutomationDue?(automation)
            print("AutomationScheduler: Running '\(automation.name)'")
        }
    }
}
