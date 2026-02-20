//
//  WebFetchTool.swift
//  Zia
//
//

import Foundation

/// Tool: web_fetch
struct WebFetchTool: Tool {
    let name = "web_fetch"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Fetch content from a URL. Works with HTTPS URLs. Returns the page content as text (HTML tags are stripped via simple regex — code/JSON embedded inside HTML may be mangled). Useful for checking websites, reading documentation, or calling APIs.",
            inputSchema: ToolInputSchema(
                properties: [
                    "url": PropertySchema(type: "string", description: "The URL to fetch (HTTPS)"),
                    "timeout_seconds": PropertySchema(type: "integer", description: "Request timeout in seconds (default 30, max 60)")
                ],
                required: ["url"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let urlString = try input.requiredString("url")
        let timeout = min(input.optionalInt("timeout_seconds") ?? 30, 60)

        guard let url = URL(string: urlString) else {
            throw ToolError.invalidParameter("url", expected: "valid URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(timeout)
        request.setValue("Zia/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response")
        }

        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        var content = String(data: data, encoding: .utf8) ?? ""

        // Strip HTML tags if content is HTML
        if contentType.contains("text/html") || content.hasPrefix("<!") || content.hasPrefix("<html") {
            content = stripHTML(content)
        }

        let maxLen = 15000
        let truncated = content.count > maxLen
        if truncated {
            content = String(content.prefix(maxLen)) + "\n...[truncated]"
        }

        return "{\"url\": \(jsonEscape(urlString)), \"status_code\": \(httpResponse.statusCode), \"content_type\": \(jsonEscape(contentType)), \"content\": \(jsonEscape(content)), \"truncated\": \(truncated)}"
    }

    private func stripHTML(_ html: String) -> String {
        // Remove script and style blocks entirely
        var result = html.replacingOccurrences(
            of: "<(script|style)[^>]*>[\\s\\S]*?</\\1>",
            with: "",
            options: .regularExpression
        )
        // Remove HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Decode common HTML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        // Collapse whitespace
        result = result.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
