//
//  MenuBarController.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import Cocoa
import SwiftUI

/// Manages the menu bar icon (NSStatusItem) and popover window
class MenuBarController: NSObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let dependencyContainer: DependencyContainer

    // MARK: - Initialization

    init(dependencyContainer: DependencyContainer = .shared) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }

    // MARK: - Setup

    func setup() {
        print("🎯 Setting up menu bar...")

        // Create status item in menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure button
        if let button = statusItem?.button {
            // Use atom symbol icon
            let image = NSImage(
                systemSymbolName: Configuration.App.menuBarIconName,
                accessibilityDescription: "Zia AI Assistant"
            )
            // Set as template to auto-adapt to light/dark mode
            image?.isTemplate = true
            button.image = image

            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover with SwiftUI content
        popover = NSPopover()
        popover?.contentSize = NSSize(
            width: Configuration.App.popoverWidth,
            height: Configuration.App.popoverHeight
        )
        popover?.behavior = .transient // Auto-hide when user clicks outside
        popover?.contentViewController = NSHostingController(
            rootView: MainView()
                .environmentObject(dependencyContainer)
        )

        print("✅ Menu bar setup complete")
    }

    // MARK: - Actions

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover?.isShown == true {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    private func openPopover(relativeTo view: NSView) {
        popover?.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)

        // Activate app to capture keyboard focus
        NSApp.activate(ignoringOtherApps: true)

        print("📖 Popover opened")
    }

    private func closePopover() {
        popover?.performClose(nil)
        print("📕 Popover closed")
    }

    // MARK: - Icon State Management

    /// Update menu bar icon to show different states
    enum IconState {
        case idle
        case thinking
        case error
    }

    func setIconState(_ state: IconState) {
        guard let button = statusItem?.button else { return }

        let image: NSImage?

        switch state {
        case .idle:
            image = NSImage(
                systemSymbolName: Configuration.App.menuBarIconName,
                accessibilityDescription: "Zia AI Assistant"
            )
        case .thinking:
            // Use sparkles for thinking/processing state
            image = NSImage(
                systemSymbolName: "sparkles",
                accessibilityDescription: "Zia is thinking..."
            )
        case .error:
            // Use red or warning icon
            image = NSImage(
                systemSymbolName: "exclamationmark.triangle",
                accessibilityDescription: "Zia error"
            )
        }

        // Set as template to auto-adapt to light/dark mode
        image?.isTemplate = true
        button.image = image
    }
}
