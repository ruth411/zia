//
//  SystemHealthTrigger.swift
//  Zia
//
//

import Foundation
import IOKit.ps

/// Monitors system health: battery level, disk space.
/// Notifies when battery drops below 20% or disk space is critically low.
struct SystemHealthTrigger: ContextTrigger {

    let id = "system_health"
    let name = "System Health Monitor"
    let checkInterval: TimeInterval = 300 // Check every 5 minutes

    /// Track what we've already warned about to avoid spamming
    nonisolated(unsafe) private static var lastBatteryWarning: Int? // Battery level at which we last warned
    nonisolated(unsafe) private static var lastDiskWarning: Date?

    func evaluate() async -> ProactiveNotification? {
        // Check battery
        if let batteryNotification = checkBattery() {
            return batteryNotification
        }

        // Check disk space
        if let diskNotification = checkDiskSpace() {
            return diskNotification
        }

        return nil
    }

    // MARK: - Battery

    private func checkBattery() -> ProactiveNotification? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let capacity = desc[kIOPSCurrentCapacityKey] as? Int,
              let powerSource = desc[kIOPSPowerSourceStateKey] as? String else {
            return nil // No battery (desktop Mac)
        }

        // Only warn on battery power (not when plugged in)
        guard powerSource == kIOPSBatteryPowerValue as String else {
            Self.lastBatteryWarning = nil
            return nil
        }

        // Warn at 20%, 10%, 5% thresholds
        let thresholds = [20, 10, 5]
        for threshold in thresholds {
            if capacity <= threshold {
                // Don't re-warn at the same threshold
                if Self.lastBatteryWarning == threshold { return nil }
                Self.lastBatteryWarning = threshold

                return ProactiveNotification(
                    title: "Low Battery: \(capacity)%",
                    body: capacity <= 5
                        ? "Critical! Connect your charger immediately."
                        : "Consider plugging in your charger soon.",
                    category: .system
                )
            }
        }

        Self.lastBatteryWarning = nil
        return nil
    }

    // MARK: - Disk Space

    private func checkDiskSpace() -> ProactiveNotification? {
        // Don't check more than once per hour
        if let lastWarning = Self.lastDiskWarning,
           Date().timeIntervalSince(lastWarning) < 3600 {
            return nil
        }

        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ),
              let freeSpace = attrs[.systemFreeSize] as? Int64 else {
            return nil
        }

        let freeGB = Double(freeSpace) / (1024 * 1024 * 1024)

        if freeGB < 5.0 {
            Self.lastDiskWarning = Date()

            return ProactiveNotification(
                title: "Low Disk Space",
                body: String(format: "Only %.1f GB free. Consider clearing some files.", freeGB),
                category: .system
            )
        }

        return nil
    }
}
