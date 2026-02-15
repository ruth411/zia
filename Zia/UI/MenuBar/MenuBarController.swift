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
        print("🎯 Setting up menu bar...")

        // Create status item in menu bar with variable length to fit icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            print("❌ Failed to get status item button!")
            return
        }

        print("✅ Status item button created")

        // Load the custom Zia logo
        var image: NSImage?

        // Approach 1: Try loading from asset catalog (standard way)
        print("🔍 Attempting to load ZiaLogo from asset catalog...")
        image = NSImage(named: "ZiaLogo")
        if image != nil {
            print("✅ Loaded from asset catalog")
        }

        // Approach 2: Try loading directly from the app's Resources
        if image == nil {
            print("🔍 Attempting to load from resource path...")
            if let resourcePath = Bundle.main.resourcePath {
                let imagePath = "\(resourcePath)/Assets.xcassets/ZiaLogo.imageset/zialogo.png"
                if FileManager.default.fileExists(atPath: imagePath) {
                    image = NSImage(contentsOfFile: imagePath)
                    print("✅ Loaded ZiaLogo from resource path: \(imagePath)")
                } else {
                    print("❌ File not found at: \(imagePath)")
                }
            }
        }

        // Approach 3: Search for the image file in the bundle
        if image == nil {
            print("🔍 Searching bundle for zialogo.png...")
            if let imagePath = Bundle.main.path(forResource: "zialogo", ofType: "png") {
                image = NSImage(contentsOfFile: imagePath)
                print("✅ Loaded ZiaLogo from bundle search: \(imagePath)")
            } else {
                print("❌ Not found in bundle")
            }
        }

        // Set the image
        if let loadedImage = image {
            print("✅ ZiaLogo loaded successfully - Original size: \(loadedImage.size)")

            // Resize to appropriate menu bar size (27x27 points for better visibility)
            let iconSize: CGFloat = 27
            let resizedImage = NSImage(size: NSSize(width: iconSize, height: iconSize))
            resizedImage.lockFocus()
            loadedImage.draw(in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize))
            resizedImage.unlockFocus()

            // Set as template to auto-adapt to light/dark mode
            resizedImage.isTemplate = true
            button.image = resizedImage
            print("✅ Menu bar icon set with resized image (\(iconSize)x\(iconSize))")
        } else {
            print("⚠️ ZiaLogo not found - using system fallback icon")
            // Use a simple text as absolute fallback
            button.title = "Z"
            button.image = nil
            print("✅ Menu bar showing 'Z' text")
        }

        button.action = #selector(togglePopover)
        button.target = self

        // Create popover with SwiftUI content
        print("🔧 Setting up popover...")
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
