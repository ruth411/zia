//
//  ZiaApp.swift
//  Zia
//
//  Created by Ruthwik Dovala on 2/13/26.
//  Updated by Claude on 2/13/26.
//

import SwiftUI

@main
struct ZiaApp: App {
    // Use AppDelegate for menu bar app setup
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings window (accessible via menu bar)
        Settings {
            SettingsView()
                .environmentObject(appDelegate.dependencyContainer)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var menuBarController: MenuBarController?
    private var settingsWindow: NSWindow?
    let dependencyContainer = DependencyContainer.shared
    private let hotkeyManager = HotkeyManager.shared

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Set AppDelegate reference in dependency container
        dependencyContainer.appDelegate = self

        // Initialize dependency container
        Task {
            await dependencyContainer.initialize()
        }

        // Setup menu bar (must be on main thread)
        DispatchQueue.main.async { [weak self] in
            self?.menuBarController = MenuBarController(dependencyContainer: self?.dependencyContainer ?? DependencyContainer.shared)
            self?.menuBarController?.setup()
        }

        // Register global hotkey (⌘+Shift+Z) for screen context
        hotkeyManager.register { [weak self] in
            self?.handleScreenContextHotkey()
        }
    }

    /// Handle the global hotkey: capture screen, open popover, send to conversation
    private func handleScreenContextHotkey() {
        Task {
            guard let base64 = await ScreenCaptureHelper.captureActiveWindowBase64() else { return }

            await MainActor.run {
                NotificationCenter.default.post(
                    name: Configuration.Keys.Notifications.screenCaptureReady,
                    object: nil,
                    userInfo: ["base64": base64]
                )

                if let button = self.menuBarController?.statusItem?.button {
                    button.performClick(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {}

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Settings Window

    @objc func showSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(dependencyContainer)

            let hostingController = NSHostingController(rootView: settingsView)

            // Use NSPanel — works better for accessory (menu bar) apps
            let panel = NSPanel(contentViewController: hostingController)
            panel.title = "Zia Settings"
            panel.styleMask = [.titled, .closable, .resizable]
            panel.setContentSize(NSSize(width: 500, height: 600))
            panel.center()
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = false

            settingsWindow = panel
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - OAuth URL Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        // Check if it's a Spotify OAuth callback
        if url.absoluteString.contains("oauth2callback") {
            if url.absoluteString.contains("code") {
                // Post Spotify OAuth notification
                NotificationCenter.default.post(
                    name: Configuration.Keys.Notifications.spotifyOAuthCallback,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }
}
