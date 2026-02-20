//
//  UtilityTools.swift
//  Zia
//
//

import AppKit
import Foundation

/// Tool: clipboard_read
struct ClipboardReadTool: Tool {
    let name = "clipboard_read"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Read the current contents of the system clipboard (text only).",
            inputSchema: ToolInputSchema(properties: [:])
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        return await MainActor.run {
            guard let content = NSPasteboard.general.string(forType: .string) else {
                return "{\"content\": null, \"message\": \"Clipboard is empty or does not contain text\"}"
            }

            let maxLen = 10000
            let truncated = content.count > maxLen
            let text = truncated ? String(content.prefix(maxLen)) + "\n...[truncated]" : content

            return "{\"content\": \(jsonEscape(text)), \"truncated\": \(truncated)}"
        }
    }
}

/// Tool: clipboard_write
struct ClipboardWriteTool: Tool {
    let name = "clipboard_write"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Write text to the system clipboard.",
            inputSchema: ToolInputSchema(
                properties: [
                    "text": PropertySchema(type: "string", description: "The text to copy to the clipboard")
                ],
                required: ["text"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let text = try input.requiredString("text")

        await MainActor.run {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }

        return "{\"success\": true, \"characters_written\": \(text.count)}"
    }
}

/// Tool: open_url
struct OpenURLTool: Tool {
    let name = "open_url"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Open a URL in the default browser, or open a file/folder in Finder. Also supports app URL schemes.",
            inputSchema: ToolInputSchema(
                properties: [
                    "url": PropertySchema(type: "string", description: "URL to open (https://, file://, or app URL scheme)")
                ],
                required: ["url"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let urlString = try input.requiredString("url")

        guard let url = URL(string: urlString) else {
            throw ToolError.invalidParameter("url", expected: "valid URL")
        }

        let opened = await MainActor.run {
            NSWorkspace.shared.open(url)
        }

        if opened {
            return "{\"success\": true, \"url\": \(jsonEscape(urlString))}"
        } else {
            throw ToolError.executionFailed("Failed to open URL: \(urlString)")
        }
    }
}
