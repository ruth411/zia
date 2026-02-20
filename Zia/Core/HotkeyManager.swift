//
//  HotkeyManager.swift
//  Zia
//
//

import Cocoa
import Carbon.HIToolbox

/// Manages global keyboard shortcuts for Zia.
/// Registers ⌘+Shift+Z as a system-wide hotkey to activate Zia with screen context.
class HotkeyManager {

    // MARK: - Properties

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onHotkeyTriggered: (() -> Void)?
    private var fallbackMonitor: Any?  // NSEvent.addGlobalMonitorForEvents token

    /// Whether the hotkey is currently registered and active
    private(set) var isRegistered = false

    // MARK: - Singleton

    static let shared = HotkeyManager()

    private init() {}

    // MARK: - Registration

    /// Register the global hotkey (⌘+Shift+Z).
    /// Requires Accessibility permission — prompts user if not granted.
    func register(handler: @escaping () -> Void) {
        guard !isRegistered else { return }
        onHotkeyTriggered = handler

        // Check accessibility permission (required for global event tap)
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )

        if !trusted {
            print("⚠️ Accessibility permission not yet granted — hotkey will activate once granted.")
        }

        // Create event tap for key down events
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        // Use a static callback that forwards to the singleton
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: nil
        ) else {
            print("❌ Failed to create event tap. Falling back to NSEvent monitor.")
            registerFallback(handler: handler)
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isRegistered = true
            print("✅ Global hotkey ⌘+Shift+Z registered via CGEvent tap")
        }
    }

    /// Fallback: use NSEvent global monitor (works without full Accessibility in some cases)
    private func registerFallback(handler: @escaping () -> Void) {
        fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for ⌘+Shift+Z
            if event.modifierFlags.contains([.command, .shift]) &&
               event.keyCode == kVK_ANSI_Z {
                DispatchQueue.main.async {
                    self?.onHotkeyTriggered?()
                }
            }
        }
        isRegistered = true
        print("✅ Global hotkey ⌘+Shift+Z registered via NSEvent monitor (fallback)")
    }

    /// Unregister the global hotkey
    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        if let monitor = fallbackMonitor {
            NSEvent.removeMonitor(monitor)
            fallbackMonitor = nil
        }
        isRegistered = false
        onHotkeyTriggered = nil
        print("🔑 Global hotkey unregistered")
    }

    // MARK: - Internal

    /// Called when the hotkey combination is detected
    fileprivate func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.onHotkeyTriggered?()
        }
    }
}

// MARK: - C Callback

/// Global C function callback for CGEvent tap
private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // Re-enable tap if it gets disabled (system does this if callback is too slow)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = HotkeyManager.shared.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // Check for ⌘+Shift+Z (keyCode 6 = Z)
    let isCommand = flags.contains(.maskCommand)
    let isShift = flags.contains(.maskShift)
    let isZ = keyCode == Int64(kVK_ANSI_Z)

    // Make sure no other modifiers are held (Option, Control)
    let isOption = flags.contains(.maskAlternate)
    let isControl = flags.contains(.maskControl)

    if isCommand && isShift && isZ && !isOption && !isControl {
        HotkeyManager.shared.handleHotkey()
        // Consume the event so it doesn't propagate
        return nil
    }

    return Unmanaged.passRetained(event)
}
