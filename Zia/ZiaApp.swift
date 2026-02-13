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
            Text("Settings will be implemented in Phase 2")
                .frame(width: 400, height: 300)
                .padding()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var menuBarController: MenuBarController?
    private let dependencyContainer = DependencyContainer.shared

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 Zia is launching...")

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Initialize dependency container
        Task {
            await dependencyContainer.initialize()
        }

        // Setup menu bar
        menuBarController = MenuBarController(dependencyContainer: dependencyContainer)
        menuBarController?.setup()

        print("✅ Zia is ready!")
    }

    func applicationWillTerminate(_ notification: Notification) {
        print("👋 Zia is shutting down...")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
