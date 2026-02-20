//
//  MCPBridgeTool.swift
//  Zia
//
//

import Foundation

/// Bridges an MCP server tool to Zia's Tool protocol.
/// Each MCP tool discovered via tools/list becomes one MCPBridgeTool instance
/// registered in the ToolRegistry alongside built-in tools.
struct MCPBridgeTool: Tool {

    let name: String
    let serverName: String

    private let toolInfo: MCPToolInfo
    private let connection: MCPConnection

    var definition: ToolDefinition {
        toolInfo.toToolDefinition()
    }

    init(toolInfo: MCPToolInfo, serverName: String, connection: MCPConnection) {
        self.name = toolInfo.name
        self.serverName = serverName
        self.toolInfo = toolInfo
        self.connection = connection
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        guard connection.state == .connected else {
            throw ToolError.notAvailable("MCP server '\(serverName)' is not connected")
        }

        let result = try await connection.callTool(name: name, arguments: input)

        if result.isError {
            throw ToolError.executionFailed(result.content)
        }

        return result.content
    }
}
