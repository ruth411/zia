//
//  Tool.swift
//  Zia
//
//

import Foundation

/// Protocol that all tools must conform to
protocol Tool {
    /// Unique tool name (matches what Claude calls)
    var name: String { get }

    /// Tool definition sent to Claude API
    var definition: ToolDefinition { get }

    /// Execute the tool with the given input parameters.
    /// Returns a string result (JSON or plain text) for Claude to consume.
    func execute(input: [String: AnyCodable]) async throws -> String
}

/// Errors that tools can throw
enum ToolError: LocalizedError {
    case missingParameter(String)
    case invalidParameter(String, expected: String)
    case executionFailed(String)
    case permissionDenied(String)
    case notAvailable(String)

    var errorDescription: String? {
        switch self {
        case .missingParameter(let name):
            return "Missing required parameter: \(name)"
        case .invalidParameter(let name, let expected):
            return "Invalid parameter '\(name)': expected \(expected)"
        case .executionFailed(let reason):
            return "Tool execution failed: \(reason)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .notAvailable(let reason):
            return "Tool not available: \(reason)"
        }
    }
}
