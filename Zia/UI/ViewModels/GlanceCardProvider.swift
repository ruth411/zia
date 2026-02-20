//
//  GlanceCardProvider.swift
//  Zia
//
//

import Foundation
import Combine
import EventKit
import IOKit.ps

/// Fetches live data for glance cards (calendar events, now playing, weather, system stats).
/// Auto-refreshes periodically while active.
@MainActor
class GlanceCardProvider: ObservableObject {

    // MARK: - Published

    @Published private(set) var cards: [GlanceCard] = GlanceCard.defaults

    // MARK: - Dependencies

    private let calendarService: CalendarService
    private let spotifyService: SpotifyService
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 60

    // MARK: - Init

    init(calendarService: CalendarService, spotifyService: SpotifyService) {
        self.calendarService = calendarService
        self.spotifyService = spotifyService
    }

    // MARK: - Public

    /// Fetch all live data and update cards
    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshCalendar() }
            group.addTask { await self.refreshMusic() }
            group.addTask { await self.refreshWeather() }
            group.addTask { await self.refreshSystem() }
        }
    }

    /// Start periodic refresh
    func startAutoRefresh() {
        stopAutoRefresh()
        Task { await refreshAll() }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    /// Stop periodic refresh
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Calendar

    private func refreshCalendar() async {
        do {
            _ = try await calendarService.requestAccess()

            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            let events = calendarService.getEvents(from: now, to: endOfDay)

            let eventCount = events.count
            let subtitle: String?

            if let nextEvent = events.first {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                let time = formatter.string(from: nextEvent.startDate)
                let title = nextEvent.title ?? "Event"
                subtitle = "\(time) \(title)"
            } else {
                subtitle = "No events today"
            }

            updateCard(id: "calendar", badgeCount: eventCount, subtitle: subtitle)
        } catch {
            updateCard(id: "calendar", subtitle: "No access")
        }
    }

    // MARK: - Music

    private func refreshMusic() async {
        do {
            let trackJSON = try await spotifyService.getCurrentTrack()

            if let data = trackJSON.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                let isPlaying = json["is_playing"] as? Bool ?? false
                if isPlaying, let track = json["track"] as? String {
                    let artist = json["artist"] as? String ?? ""
                    let subtitle = artist.isEmpty ? track : "\(track) - \(artist)"
                    updateCard(id: "music", badgeCount: 1, subtitle: String(subtitle.prefix(30)))
                } else {
                    updateCard(id: "music", badgeCount: 0, subtitle: "Not playing")
                }
            }
        } catch {
            updateCard(id: "music", badgeCount: 0, subtitle: nil)
        }
    }

    // MARK: - Weather

    private func refreshWeather() async {
        do {
            // Use wttr.in free API — no API key needed
            guard let url = URL(string: "https://wttr.in/?format=j1") else { return }
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let currentCondition = (json["current_condition"] as? [[String: Any]])?.first else {
                return
            }

            let tempF = currentCondition["temp_F"] as? String ?? ""
            let tempC = currentCondition["temp_C"] as? String ?? ""
            let desc = (currentCondition["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String ?? ""

            // Use Fahrenheit for US locale, Celsius otherwise
            let usesMetric = Locale.current.measurementSystem == .metric
            let temp = usesMetric ? "\(tempC)°C" : "\(tempF)°F"
            let shortDesc = String(desc.prefix(15))

            updateCard(id: "weather", subtitle: "\(temp) \(shortDesc)")
        } catch {
            updateCard(id: "weather", subtitle: nil)
        }
    }

    // MARK: - System

    private func refreshSystem() async {
        let batteryLevel = getBatteryLevel()
        let subtitle: String

        if let level = batteryLevel {
            subtitle = "Battery \(level)%"
        } else {
            // Desktop Mac — show memory usage instead
            let memGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
            subtitle = "\(memGB)GB RAM"
        }

        let badgeCount = (batteryLevel ?? 100) < 20 ? 1 : 0
        updateCard(id: "system", badgeCount: badgeCount, subtitle: subtitle)
    }

    /// Get battery percentage (nil if no battery, e.g. desktop Mac)
    private func getBatteryLevel() -> Int? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let capacity = desc[kIOPSCurrentCapacityKey] as? Int else {
            return nil
        }
        return capacity
    }

    // MARK: - Helpers

    private func updateCard(id: String, badgeCount: Int? = nil, subtitle: String?) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        var card = cards[index]
        if let badge = badgeCount {
            card.badgeCount = badge
        }
        card.subtitle = subtitle
        cards[index] = card
    }
}
