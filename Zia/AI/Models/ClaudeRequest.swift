//
//  ClaudeRequest.swift
//  Zia
//
//

import Foundation

/// Request body for Claude API /v1/messages endpoint
struct ClaudeRequest: Codable {

    let model: String
    let messages: [ClaudeMessage]
    let maxTokens: Int
    let system: String?
    let tools: [ToolDefinition]?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case maxTokens = "max_tokens"
        case system
        case tools
    }

    init(
        model: String = Configuration.API.Claude.model,
        messages: [ClaudeMessage],
        maxTokens: Int = Configuration.API.Claude.maxTokens,
        system: String? = nil,
        tools: [ToolDefinition]? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.system = system
        self.tools = tools
    }
}

/// Claude API message format
struct ClaudeMessage: Codable {
    let role: String
    let content: [ClaudeContentBlock]

    init(role: String, content: [ClaudeContentBlock]) {
        self.role = role
        self.content = content
    }

    /// Convenience initializer for text-only messages
    init(role: String, text: String) {
        self.role = role
        self.content = [.text(text)]
    }
}

/// Content blocks in Claude API format
enum ClaudeContentBlock: Codable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: AnyCodable])
    case toolResult(toolUseId: String, content: String, isError: Bool)
    case image(mediaType: String, base64Data: String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case id
        case name
        case input
        case toolUseId = "tool_use_id"
        case content
        case isError = "is_error"
        case source
    }

    enum SourceCodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "tool_use":
            let id = try container.decode(String.self, forKey: .id)
            let name = try container.decode(String.self, forKey: .name)
            let input = try container.decode([String: AnyCodable].self, forKey: .input)
            self = .toolUse(id: id, name: name, input: input)
        case "tool_result":
            let toolUseId = try container.decode(String.self, forKey: .toolUseId)
            let content = try container.decode(String.self, forKey: .content)
            let isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
            self = .toolResult(toolUseId: toolUseId, content: content, isError: isError)
        case "image":
            let sourceContainer = try container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: .source)
            let mediaType = try sourceContainer.decode(String.self, forKey: .mediaType)
            let data = try sourceContainer.decode(String.self, forKey: .data)
            self = .image(mediaType: mediaType, base64Data: data)
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
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(input, forKey: .input)
        case .toolResult(let toolUseId, let content, let isError):
            try container.encode("tool_result", forKey: .type)
            try container.encode(toolUseId, forKey: .toolUseId)
            try container.encode(content, forKey: .content)
            if isError {
                try container.encode(isError, forKey: .isError)
            }
        case .image(let mediaType, let base64Data):
            try container.encode("image", forKey: .type)
            var sourceContainer = container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: .source)
            try sourceContainer.encode("base64", forKey: .type)
            try sourceContainer.encode(mediaType, forKey: .mediaType)
            try sourceContainer.encode(base64Data, forKey: .data)
        }
    }
}

/// Tool definition in Claude API format
struct ToolDefinition: Codable {
    let name: String
    let description: String
    let inputSchema: ToolInputSchema

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema = "input_schema"
    }

    init(name: String, description: String, inputSchema: ToolInputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema for tool input parameters
struct ToolInputSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]?

    init(type: String = "object", properties: [String: PropertySchema], required: [String]? = nil) {
        self.type = type
        self.properties = properties
        self.required = required
    }
}

/// Property schema for tool parameters
struct PropertySchema: Codable {
    let type: String
    let description: String
    let enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }

    init(type: String, description: String, enumValues: [String]? = nil) {
        self.type = type
        self.description = description
        self.enumValues = enumValues
    }
}
