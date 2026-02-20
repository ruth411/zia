//
//  FileSystemTools.swift
//  Zia
//
//

import Foundation

// MARK: - Path Validation

/// Validates that a resolved path stays within the user's home directory or /tmp.
/// Throws ToolError.permissionDenied for paths that escape the home directory.
private func validatePath(_ expandedPath: String) throws {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let resolved = URL(fileURLWithPath: expandedPath).resolvingSymlinksInPath().path
    guard resolved.hasPrefix(home) || resolved.hasPrefix("/tmp") else {
        throw ToolError.permissionDenied("Access outside home directory is not allowed: \(expandedPath)")
    }
}

/// Tool: read_file
struct ReadFileTool: Tool {
    let name = "read_file"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Read the contents of a file. Supports text files. Use ~ for home directory. Returns file content as text.",
            inputSchema: ToolInputSchema(
                properties: [
                    "path": PropertySchema(type: "string", description: "File path (supports ~ for home directory)"),
                    "max_lines": PropertySchema(type: "integer", description: "Maximum number of lines to read (optional, reads entire file by default)")
                ],
                required: ["path"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let path = try input.requiredString("path")
        let expandedPath = (path as NSString).expandingTildeInPath
        try validatePath(expandedPath)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw ToolError.executionFailed("File not found: \(path)")
        }

        var content = try String(contentsOfFile: expandedPath, encoding: .utf8)

        if let maxLines = input.optionalInt("max_lines") {
            let lines = content.components(separatedBy: "\n")
            if lines.count > maxLines {
                content = lines.prefix(maxLines).joined(separator: "\n")
            }
        }

        let maxLen = 20000
        let truncated = content.count > maxLen
        if truncated {
            content = String(content.prefix(maxLen)) + "\n...[truncated]"
        }

        let lineCount = content.components(separatedBy: "\n").count
        return "{\"path\": \(jsonEscape(expandedPath)), \"content\": \(jsonEscape(content)), \"lines\": \(lineCount), \"truncated\": \(truncated)}"
    }
}

/// Tool: write_file
struct WriteFileTool: Tool {
    let name = "write_file"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Write content to a file. Creates the file if it doesn't exist. Confirm with the user before overwriting existing files.",
            inputSchema: ToolInputSchema(
                properties: [
                    "path": PropertySchema(type: "string", description: "File path (supports ~ for home directory)"),
                    "content": PropertySchema(type: "string", description: "Content to write to the file"),
                    "create_directories": PropertySchema(type: "boolean", description: "Create parent directories if they don't exist (default true)")
                ],
                required: ["path", "content"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let path = try input.requiredString("path")
        let content = try input.requiredString("content")
        let createDirs = input.optionalBool("create_directories", default: true)
        let expandedPath = (path as NSString).expandingTildeInPath
        try validatePath(expandedPath)

        if createDirs {
            let parentDir = (expandedPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: parentDir,
                withIntermediateDirectories: true
            )
        }

        try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
        let bytesWritten = content.utf8.count

        return "{\"success\": true, \"path\": \(jsonEscape(expandedPath)), \"bytes_written\": \(bytesWritten)}"
    }
}

/// Tool: list_directory
struct ListDirectoryTool: Tool {
    let name = "list_directory"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "List files and directories at a given path. Returns names, types, and sizes.",
            inputSchema: ToolInputSchema(
                properties: [
                    "path": PropertySchema(type: "string", description: "Directory path (supports ~ for home directory)"),
                    "show_hidden": PropertySchema(type: "boolean", description: "Show hidden files starting with . (default false)")
                ],
                required: ["path"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let path = try input.requiredString("path")
        let showHidden = input.optionalBool("show_hidden")
        let expandedPath = (path as NSString).expandingTildeInPath
        try validatePath(expandedPath)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDir), isDir.boolValue else {
            throw ToolError.executionFailed("Directory not found: \(path)")
        }

        var entries = try FileManager.default.contentsOfDirectory(atPath: expandedPath)

        if !showHidden {
            entries = entries.filter { !$0.hasPrefix(".") }
        }

        entries.sort()

        let maxEntries = 200
        let truncated = entries.count > maxEntries
        if truncated {
            entries = Array(entries.prefix(maxEntries))
        }

        var formattedEntries: [[String: Any]] = []
        for entry in entries {
            let fullPath = (expandedPath as NSString).appendingPathComponent(entry)
            var entryIsDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &entryIsDir)

            var dict: [String: Any] = [
                "name": entry,
                "is_directory": entryIsDir.boolValue
            ]

            if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
               let size = attrs[.size] as? Int64 {
                dict["size"] = size
            }

            formattedEntries.append(dict)
        }

        if let data = try? JSONSerialization.data(withJSONObject: formattedEntries, options: []),
           let entriesJSON = String(data: data, encoding: .utf8) {
            return "{\"path\": \(jsonEscape(expandedPath)), \"entries\": \(entriesJSON), \"total\": \(formattedEntries.count), \"truncated\": \(truncated)}"
        }

        return "{\"path\": \(jsonEscape(expandedPath)), \"entries\": [], \"error\": \"Failed to serialize entries\"}"
    }
}
