//
//  ShellTools.swift
//  Zia
//
//

import AppKit
import Foundation

/// Tool: run_shell_command
struct RunShellCommandTool: Tool {
    let name = "run_shell_command"

    /// In-memory audit log of all executed commands (max 100 entries).
    /// Accessible for diagnostics and transparency.
    static private(set) var auditLog: [(date: Date, command: String)] = []

    /// Patterns that identify destructive commands requiring explicit opt-in
    private static let destructivePatterns = [
        "rm ", "rm\t", "rmdir", "mv ", "mv\t", "dd ", "mkfs",
        "sudo ", "> /dev/", "chmod 777", "diskutil erase", "shred "
    ]

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Run a shell command on the user's Mac using zsh. Returns stdout, stderr, and exit code. For read-only tasks (ls, cat, grep, etc.) set dangerous: false (default). For commands that modify, delete, or move files or require sudo, you MUST set dangerous: true AND confirm with the user first. All executed commands are logged in the audit trail.",
            inputSchema: ToolInputSchema(
                properties: [
                    "command": PropertySchema(type: "string", description: "The shell command to execute"),
                    "timeout_seconds": PropertySchema(type: "integer", description: "Timeout in seconds (default 30, max 120)"),
                    "dangerous": PropertySchema(type: "boolean", description: "Set true to allow destructive commands (rm, mv, sudo, etc.). Default false.")
                ],
                required: ["command"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let command = try input.requiredString("command")
        let timeout = min(input.optionalInt("timeout_seconds") ?? 30, 120)
        let dangerous = input.optionalBool("dangerous", default: false)

        // Advisory pattern check — not a security gate.
        // Obfuscated variants (backticks, $(), space-inserted) bypass the pattern check intentionally.
        // The real security boundary is dangerous:true, which Claude must explicitly set and justify.
        let looksDestructive = Self.destructivePatterns.contains { command.localizedCaseInsensitiveContains($0) }
        if looksDestructive && !dangerous {
            throw ToolError.permissionDenied(
                "Command contains a potentially destructive operation. Pass dangerous: true to allow commands with rm, mv, sudo, etc."
            )
        }

        // Audit log — keep last 100 entries
        RunShellCommandTool.auditLog.append((date: Date(), command: command))
        if RunShellCommandTool.auditLog.count > 100 {
            RunShellCommandTool.auditLog.removeFirst()
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let timeoutWorkItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(
                    deadline: .now() + .seconds(timeout),
                    execute: timeoutWorkItem
                )

                do {
                    try process.run()
                    process.waitUntilExit()
                    timeoutWorkItem.cancel()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    var stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    var stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    let maxLen = 10000
                    if stdout.count > maxLen {
                        stdout = String(stdout.prefix(maxLen)) + "\n...[truncated]"
                    }
                    if stderr.count > maxLen {
                        stderr = String(stderr.prefix(maxLen)) + "\n...[truncated]"
                    }

                    let result = "{\"exit_code\": \(process.terminationStatus), \"stdout\": \(jsonEscape(stdout)), \"stderr\": \(jsonEscape(stderr))}"
                    continuation.resume(returning: result)
                } catch {
                    timeoutWorkItem.cancel()
                    continuation.resume(throwing: ToolError.executionFailed(error.localizedDescription))
                }
            }
        }
    }
}

/// Tool: run_applescript
struct RunAppleScriptTool: Tool {
    let name = "run_applescript"

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Run AppleScript to control macOS applications. This can interact with any app: Finder, Safari, Mail, Notes, Messages, System Settings, etc. Examples: open apps, send emails, manipulate files in Finder, get information from apps.",
            inputSchema: ToolInputSchema(
                properties: [
                    "script": PropertySchema(type: "string", description: "The AppleScript source code to execute")
                ],
                required: ["script"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let script = try input.requiredString("script")

        return try await MainActor.run {
            var errorDict: NSDictionary?
            guard let appleScript = NSAppleScript(source: script) else {
                throw ToolError.executionFailed("Failed to create AppleScript")
            }

            let result = appleScript.executeAndReturnError(&errorDict)

            if let error = errorDict {
                let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                throw ToolError.executionFailed(message)
            }

            let output = result.stringValue ?? ""
            return "{\"success\": true, \"result\": \(jsonEscape(output))}"
        }
    }
}
