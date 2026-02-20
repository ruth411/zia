//
//  Message.swift
//  Zia
//
//

import Foundation

/// Represents a message in the conversation with Claude
struct Message: Identifiable, Codable {

    let id: String
    let role: MessageRole
    let content: [ContentBlock]
    let timestamp: Date

    init(id: String = UUID().uuidString, role: MessageRole, content: [ContentBlock], timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    /// Convenience initializer for simple text messages
    init(role: MessageRole, text: String) {
        self.id = UUID().uuidString
        self.role = role
        self.content = [.text(text)]
        self.timestamp = Date()
    }
}

/// Message role in the conversation
enum MessageRole: String, Codable {
    case user
    case assistant
}

/// Content blocks that can appear in a message
enum ContentBlock: Codable {
    case text(String)
    case toolUse(ToolUse)
    case toolResult(ToolResult)
    case image(ImageContent)

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case toolUse
        case toolResult
        case image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_use":
            let toolUse = try container.decode(ToolUse.self, forKey: .toolUse)
            self = .toolUse(toolUse)
        case "tool_result":
            let toolResult = try container.decode(ToolResult.self, forKey: .toolResult)
            self = .toolResult(toolResult)
        case "image":
            let image = try container.decode(ImageContent.self, forKey: .image)
            self = .image(image)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content block type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let toolUse):
            try container.encode("tool_use", forKey: .type)
            try container.encode(toolUse, forKey: .toolUse)
        case .toolResult(let toolResult):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolResult, forKey: .toolResult)
        case .image(let image):
            try container.encode("image", forKey: .type)
            try container.encode(image, forKey: .image)
        }
    }
}

/// Image content for Claude vision API
struct ImageContent: Codable {
    let mediaType: String
    let base64Data: String

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case base64Data = "base64_data"
    }

    init(mediaType: String = "image/png", base64Data: String) {
        self.mediaType = mediaType
        self.base64Data = base64Data
    }
}

/// Represents a tool use request from Claude
struct ToolUse: Codable, Identifiable {
    let id: String
    let name: String
    let input: [String: AnyCodable]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case input
    }
}

/// Represents the result of a tool execution
struct ToolResult: Codable {
    let toolUseId: String
    let content: String
    let isError: Bool

    enum CodingKeys: String, CodingKey {
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
    }

    init(toolUseId: String, content: String, isError: Bool = false) {
        self.toolUseId = toolUseId
        self.content = content
        self.isError = isError
    }
}

/// Type-erased codable value for tool input parameters
struct AnyCodable: Codable {
    let value: Any

    /// Thread-local key for tracking recursive decode depth (prevents stack overflow on deep JSON)
    private static let depthKey = "AnyCodableDecodeDepth"
    private static let maxDepth = 20

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        // Guard against deeply-nested JSON causing a stack overflow
        let currentDepth = Thread.current.threadDictionary[Self.depthKey] as? Int ?? 0
        guard currentDepth < Self.maxDepth else {
            let container = try decoder.singleValueContainer()
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable: maximum nesting depth of \(Self.maxDepth) exceeded"
            )
        }
        Thread.current.threadDictionary[Self.depthKey] = currentDepth + 1
        defer { Thread.current.threadDictionary[Self.depthKey] = currentDepth }

        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}
