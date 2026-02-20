//
//  MenuBarController.swift
//  Zia
//
//

import Cocoa
import SwiftUI

/// Manages the menu bar icon (NSStatusItem) and popover window
class MenuBarController: NSObject {

    // MARK: - Properties

    var statusItem: NSStatusItem? // Made internal for debugging
    private var popover: NSPopover?
    private let dependencyContainer: DependencyContainer

    // MARK: - Initialization

    init(dependencyContainer: DependencyContainer = .shared) {
        self.dependencyContainer = dependencyContainer
        super.init()
    }

    // MARK: - Setup

    func setup() {
        // Create status item in menu bar with variable length to fit icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Load the custom Zia logo — three fallback approaches
        var image: NSImage?

        // Approach 1: Asset catalog (standard way)
        image = NSImage(named: "ZiaLogo")

        // Approach 2: Direct resource path
        if image == nil, let resourcePath = Bundle.main.resourcePath {
            let imagePath = "\(resourcePath)/Assets.xcassets/ZiaLogo.imageset/zialogo.png"
            if FileManager.default.fileExists(atPath: imagePath) {
                image = NSImage(contentsOfFile: imagePath)
            }
        }

        // Approach 3: Bundle search
        if image == nil, let imagePath = Bundle.main.path(forResource: "zialogo", ofType: "png") {
            image = NSImage(contentsOfFile: imagePath)
        }

        // Set the image or fall back to "Z" text
        if let loadedImage = image {
            let iconSize: CGFloat = 27
            let resizedImage = NSImage(size: NSSize(width: iconSize, height: iconSize))
            resizedImage.lockFocus()
            loadedImage.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize))
            resizedImage.unlockFocus()
            resizedImage.isTemplate = true
            button.image = resizedImage
        } else {
            button.title = "Z"
            button.image = nil
        }

        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusBarClick(_:))
        button.target = self

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
    }

    // MARK: - Actions

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover?.isShown == true {
            closePopover()
        } else {
            openPopover(relativeTo: button)
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Zia", action: #selector(togglePopover(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Zia", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func openSettingsFromMenu() {
        // Open popover first so the app is active and has a window
        if popover?.isShown != true {
            guard let button = statusItem?.button else { return }
            openPopover(relativeTo: button)
        }
        // Route to AppDelegate.showSettings() through the responder chain
        NSApp.sendAction(Selector(("showSettings")), to: nil, from: nil)
    }

    private func openPopover(relativeTo view: NSView) {
        popover?.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover?.performClose(nil)
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

        var image: NSImage?

        switch state {
        case .idle:
            // Try to load ZiaLogo with fallback
            image = NSImage(named: "ZiaLogo")
            if image == nil, let resourcePath = Bundle.main.resourcePath {
                let imagePath = "\(resourcePath)/Assets.xcassets/ZiaLogo.imageset/zialogo.png"
                if FileManager.default.fileExists(atPath: imagePath) {
                    image = NSImage(contentsOfFile: imagePath)
                }
            }
            if image == nil, let imagePath = Bundle.main.path(forResource: "zialogo", ofType: "png") {
                image = NSImage(contentsOfFile: imagePath)
            }
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
