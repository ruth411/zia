//
//  MCPTypes.swift
//  Zia
//
//

import Foundation

// MARK: - MCP Configuration

/// Configuration loaded from ~/.zia/mcp.json
struct MCPConfig: Codable {
    let mcpServers: [String: MCPServerConfig]
}

/// Configuration for a single MCP server
struct MCPServerConfig: Codable {
    let command: String
    let args: [String]?
    let env: [String: String]?
}

// MARK: - JSON-RPC 2.0

/// JSON-RPC 2.0 request
struct JSONRPCRequest: Encodable {
    let jsonrpc: String = "2.0"
    let id: Int
    let method: String
    let params: JSONRPCParams?

    init(id: Int, method: String, params: JSONRPCParams? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// JSON-RPC 2.0 notification (no id, no response expected)
struct JSONRPCNotification: Encodable {
    let jsonrpc: String = "2.0"
    let method: String
    let params: JSONRPCParams?

    init(method: String, params: JSONRPCParams? = nil) {
        self.method = method
        self.params = params
    }
}

/// Flexible params container for JSON-RPC
struct JSONRPCParams: Codable {
    private let storage: [String: AnyCodable]

    init(_ dict: [String: Any] = [:]) {
        self.storage = dict.mapValues { AnyCodable($0) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storage)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.storage = try container.decode([String: AnyCodable].self)
    }
}

/// JSON-RPC 2.0 response (decoded dynamically)
struct JSONRPCResponse: Codable {
    let jsonrpc: String
    let id: Int?
    let result: AnyCodable?
    let error: JSONRPCError?
}

/// JSON-RPC error object
struct JSONRPCError: Codable {
    let code: Int
    let message: String
    let data: AnyCodable?
}

// MARK: - MCP Protocol Types

/// MCP initialize request params
struct MCPInitializeParams: Codable {
    let protocolVersion: String
    let capabilities: MCPClientCapabilities
    let clientInfo: MCPClientInfo
}

/// Client capabilities we advertise
struct MCPClientCapabilities: Codable {
    // Empty for now — we only need tools
}

/// Info about our client
struct MCPClientInfo: Codable {
    let name: String
    let version: String
}

/// MCP tool definition from server
struct MCPToolInfo: Codable {
    let name: String
    let description: String?
    let inputSchema: MCPInputSchema?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case inputSchema
    }
}

/// Input schema from MCP server (JSON Schema format)
struct MCPInputSchema: Codable {
    let type: String?
    let properties: [String: MCPPropertyInfo]?
    let required: [String]?
}

/// Property info from MCP tool schema
struct MCPPropertyInfo: Codable {
    let type: String?
    let description: String?
    // Using enum as key name conflicts with Swift keyword
    let enumValues: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enumValues = "enum"
    }
}

/// Result of calling an MCP tool
struct MCPToolCallResult {
    let content: String
    let isError: Bool
}

// MARK: - MCP Server State

/// Connection state for an MCP server
enum MCPServerState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    static func == (lhs: MCPServerState, rhs: MCPServerState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Conversion Helpers

extension MCPToolInfo {
    /// Convert MCP tool info to Zia's ToolDefinition format
    func toToolDefinition() -> ToolDefinition {
        var properties: [String: PropertySchema] = [:]

        if let props = inputSchema?.properties {
            for (key, info) in props {
                properties[key] = PropertySchema(
                    type: info.type ?? "string",
                    description: info.description ?? "",
                    enumValues: info.enumValues
                )
            }
        }

        return ToolDefinition(
            name: name,
            description: description ?? "MCP tool: \(name)",
            inputSchema: ToolInputSchema(
                properties: properties,
                required: inputSchema?.required
            )
        )
    }
}
