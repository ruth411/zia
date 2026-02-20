//
//  ToolInputHelpers.swift
//  Zia
//
//

import Foundation

/// Convenience extensions for extracting typed values from tool input
extension Dictionary where Key == String, Value == AnyCodable {

    /// Get a required string parameter
    func requiredString(_ key: String) throws -> String {
        guard let codable = self[key], let value = codable.value as? String else {
            throw ToolError.missingParameter(key)
        }
        return value
    }

    /// Get an optional string parameter
    func optionalString(_ key: String) -> String? {
        guard let codable = self[key], let value = codable.value as? String else {
            return nil
        }
        return value
    }

    /// Get a required integer parameter
    func requiredInt(_ key: String) throws -> Int {
        guard let codable = self[key] else {
            throw ToolError.missingParameter(key)
        }
        if let value = codable.value as? Int { return value }
        if let value = codable.value as? Double { return Int(value) }
        throw ToolError.invalidParameter(key, expected: "integer")
    }

    /// Get an optional integer parameter
    func optionalInt(_ key: String) -> Int? {
        guard let codable = self[key] else { return nil }
        if let value = codable.value as? Int { return value }
        if let value = codable.value as? Double { return Int(value) }
        return nil
    }

    /// Get a required boolean parameter
    func requiredBool(_ key: String) throws -> Bool {
        guard let codable = self[key], let value = codable.value as? Bool else {
            throw ToolError.missingParameter(key)
        }
        return value
    }

    /// Get an optional boolean parameter with default
    func optionalBool(_ key: String, default defaultValue: Bool = false) -> Bool {
        guard let codable = self[key], let value = codable.value as? Bool else {
            return defaultValue
        }
        return value
    }
}

/// Escape a string for safe embedding in JSON (includes surrounding quotes)
func jsonEscape(_ string: String) -> String {
    if let data = try? JSONEncoder().encode(string),
       let encoded = String(data: data, encoding: .utf8) {
        return encoded
    }
    // Safe manual fallback: escape all JSON special characters
    let escaped = string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\t", with: "\\t")
    return "\"\(escaped)\""
}
