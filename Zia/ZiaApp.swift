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

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Zia is launching...")

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
            print("🔧 Creating MenuBarController...")
            self?.menuBarController = MenuBarController(dependencyContainer: self?.dependencyContainer ?? DependencyContainer.shared)
            self?.menuBarController?.setup()

            // Verify status item was created
            if self?.menuBarController?.statusItem != nil {
                print("✅ Status item verified - should be visible in menu bar")
            } else {
                print("❌ Status item is nil - menu bar icon will not appear!")
            }
        }

        print("✅ Zia is ready!")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Zia is shutting down...")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Settings Window

    @objc func showSettings() {
        print("🔧 showSettings() called")

        if settingsWindow == nil {
            print("🔧 Creating new settings panel...")
            // Create settings window
            let settingsView = SettingsView()
                .environmentObject(dependencyContainer)

            let hostingController = NSHostingController(rootView: settingsView)

            // Use NSPanel instead of NSWindow - works better for accessory apps
            let panel = NSPanel(contentViewController: hostingController)
            panel.title = "Zia Settings"
            panel.styleMask = [.titled, .closable, .resizable]
            panel.setContentSize(NSSize(width: 500, height: 600))
            panel.center()
            panel.isReleasedWhenClosed = false
            panel.level = .floating // Keep panel on top
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = false

            settingsWindow = panel
            print("✅ Settings panel created")
        } else {
            print("🔧 Reusing existing settings panel")
        }

        print("🔧 Making panel key and ordering front...")
        settingsWindow?.makeKeyAndOrderFront(nil)
        print("✅ Settings panel should be visible")
    }

    // MARK: - OAuth URL Handling

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        print("📨 Received OAuth callback URL: \(url)")

        // Check if it's a Spotify OAuth callback
        if url.absoluteString.contains("oauth2callback") {
            if url.absoluteString.contains("code") {
                // Post Spotify OAuth notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("SpotifyOAuthCallback"),
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }
}
