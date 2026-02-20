//
//  SystemTools.swift
//  Zia
//
//

import CoreServices
import Foundation

/// Tool: get_current_datetime
struct GetCurrentDateTimeTool: Tool {
    let name = "get_current_datetime"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Get the current date, time, and timezone. Use this when the user asks about the current time or date, or when you need the current date to interpret relative dates like 'today' or 'tomorrow'.",
            inputSchema: ToolInputSchema(properties: [:])
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a"
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let timeZone = TimeZone.current

        return "{\"datetime\": \(jsonEscape(formatter.string(from: now))), \"iso\": \(jsonEscape(isoFormatter.string(from: now))), \"timezone\": \(jsonEscape(timeZone.identifier)), \"abbreviation\": \(jsonEscape(timeZone.abbreviation() ?? "Unknown")), \"unix_timestamp\": \(Int(now.timeIntervalSince1970))}"
    }
}

/// Tool: get_system_info
struct GetSystemInfoTool: Tool {
    let name = "get_system_info"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Get basic system information about the user's Mac.",
            inputSchema: ToolInputSchema(properties: [:])
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let processInfo = ProcessInfo.processInfo
        return "{\"os_version\": \(jsonEscape(processInfo.operatingSystemVersionString)), \"hostname\": \(jsonEscape(processInfo.hostName)), \"username\": \(jsonEscape(NSUserName())), \"uptime_seconds\": \(Int(processInfo.systemUptime))}"
    }
}

/// Tool: set_default_browser
struct SetDefaultBrowserTool: Tool {
    let name = "set_default_browser"

    /// Common browser bundle identifiers
    private static let knownBrowsers: [String: String] = [
        "safari": "com.apple.Safari",
        "chrome": "com.google.Chrome",
        "brave": "com.brave.Browser",
        "firefox": "org.mozilla.firefox",
        "edge": "com.microsoft.edgemac",
        "arc": "company.thebrowser.Browser",
        "opera": "com.operasoftware.Opera",
        "vivaldi": "com.vivaldi.Vivaldi",
        "orion": "com.kagi.kagimacOS",
        "zen": "io.github.nickvision.Parabolic"
    ]

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Set the default web browser on macOS. Supports: Safari, Chrome, Brave, Firefox, Edge, Arc, Opera, Vivaldi. You can pass the browser name (e.g. 'brave') or a bundle identifier (e.g. 'com.brave.Browser').",
            inputSchema: ToolInputSchema(
                properties: [
                    "browser": PropertySchema(type: "string", description: "Browser name (e.g. 'brave', 'chrome', 'safari') or bundle identifier (e.g. 'com.brave.Browser')")
                ],
                required: ["browser"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let browser = try input.requiredString("browser")
        let lowered = browser.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Resolve to bundle ID
        let bundleId: String
        if lowered.contains(".") {
            // Already a bundle identifier
            bundleId = browser
        } else if let known = Self.knownBrowsers[lowered] {
            bundleId = known
        } else {
            let available = Self.knownBrowsers.keys.sorted().joined(separator: ", ")
            throw ToolError.invalidParameter("browser", expected: "known browser name (\(available)) or bundle identifier")
        }

        // Verify the browser is installed
        guard LSCopyApplicationURLsForBundleIdentifier(bundleId as CFString, nil) != nil else {
            throw ToolError.executionFailed("Browser '\(browser)' (bundle: \(bundleId)) is not installed on this Mac.")
        }

        // Set as default for both http and https
        let httpResult = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId as CFString)
        let httpsResult = LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId as CFString)

        if httpResult == noErr && httpsResult == noErr {
            return "{\"success\": true, \"browser\": \(jsonEscape(browser)), \"bundle_id\": \(jsonEscape(bundleId)), \"message\": \"Default browser set successfully\"}"
        } else {
            throw ToolError.executionFailed("Failed to set default browser. HTTP status: \(httpResult), HTTPS status: \(httpsResult). The user may need to change it manually in System Settings > Desktop & Dock.")
        }
    }
}
