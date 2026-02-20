//
//  ScreenCaptureTool.swift
//  Zia
//
//

import Cocoa
import Foundation
import ScreenCaptureKit

/// Tool that captures a screenshot of the active window or full screen.
/// Returns base64-encoded PNG data for use with Claude's vision API.
struct ScreenCaptureTool: Tool {

    let name = "capture_screen"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Capture a screenshot of the current screen or active window. Returns a base64 PNG image that can be analyzed with vision. Use this when the user asks you to look at, see, or analyze what's on their screen.",
            inputSchema: ToolInputSchema(
                properties: [
                    "mode": PropertySchema(
                        type: "string",
                        description: "Capture mode: 'window' for the frontmost window, 'screen' for the full screen.",
                        enumValues: ["window", "screen"]
                    )
                ],
                required: ["mode"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let mode = (input["mode"]?.value as? String) ?? "screen"

        guard ["window", "screen"].contains(mode) else {
            throw ToolError.invalidParameter("mode", expected: "'window' or 'screen'")
        }

        let imageData: Data
        if mode == "window" {
            imageData = try await captureActiveWindow()
        } else {
            imageData = try await captureFullScreen()
        }

        // Compress / resize for token efficiency (max 1568px on longest side per Claude docs)
        let resizedData = try resizeImageData(imageData, maxDimension: 1568)

        let base64 = resizedData.base64EncodedString()
        let sizeKB = resizedData.count / 1024

        return "{\"success\": true, \"format\": \"png\", \"size_kb\": \(sizeKB), \"base64\": \"\(base64)\"}"
    }

    // MARK: - ScreenCaptureKit Methods

    /// Capture the frontmost (active) window using ScreenCaptureKit
    private func captureActiveWindow() async throws -> Data {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Find the frontmost application's window (excluding Zia)
        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontPID = frontApp?.processIdentifier ?? 0

        let targetWindow = availableContent.windows.first { window in
            guard window.owningApplication?.processID == frontPID else { return false }
            guard window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
            guard window.isOnScreen else { return false }
            return true
        }

        guard let window = targetWindow else {
            return try await captureFullScreen()
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width) * 2  // Retina
        config.height = Int(window.frame.height) * 2
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return try pngData(from: image)
    }

    /// Capture the full main screen using ScreenCaptureKit
    private func captureFullScreen() async throws -> Data {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let mainDisplay = availableContent.displays.first else {
            throw ToolError.executionFailed("No display found for screen capture")
        }

        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = Int(mainDisplay.width) * 2  // Retina
        config.height = Int(mainDisplay.height) * 2
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return try pngData(from: image)
    }

    // MARK: - Image Processing

    /// Convert CGImage to PNG data
    private func pngData(from cgImage: CGImage) throws -> Data {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
            throw ToolError.executionFailed("Failed to encode image as PNG")
        }
        return data
    }

    /// Resize image data to fit within maxDimension while preserving aspect ratio
    private func resizeImageData(_ data: Data, maxDimension: CGFloat) throws -> Data {
        guard let image = NSImage(data: data) else {
            throw ToolError.executionFailed("Failed to load image for resizing")
        }

        let originalSize = image.size
        let scale: CGFloat

        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            if originalSize.width > originalSize.height {
                scale = maxDimension / originalSize.width
            } else {
                scale = maxDimension / originalSize.height
            }
        } else {
            scale = 1.0
        }

        let newSize = NSSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()

        guard let tiffData = resizedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ToolError.executionFailed("Failed to encode resized image")
        }

        return pngData
    }
}

// MARK: - Standalone Capture Helper

/// Captures the screen and returns base64 PNG data.
/// Used by the hotkey flow to attach a screenshot to the conversation.
enum ScreenCaptureHelper {

    /// Capture the active window (or full screen as fallback) and return base64 PNG
    static func captureActiveWindowBase64() async -> String? {
        let tool = ScreenCaptureTool()
        let input: [String: AnyCodable] = ["mode": AnyCodable("window")]

        guard let output = try? await tool.execute(input: input),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64 = json["base64"] as? String else {
            return nil
        }
        return base64
    }
}
