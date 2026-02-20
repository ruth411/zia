//
//  ToolRegistry.swift
//  Zia
//
//

import Foundation

/// Registry that maps tool names to Tool instances.
/// Provides all ToolDefinitions for the AI request.
class ToolRegistry {

    private var tools: [String: Tool] = [:]

    /// Register a tool
    func register(_ tool: Tool) {
        tools[tool.name] = tool
    }

    /// Get a tool by name
    func tool(named name: String) -> Tool? {
        tools[name]
    }

    /// Get all registered tool definitions (sent to Claude)
    var allDefinitions: [ToolDefinition] {
        tools.values.map { $0.definition }
    }

    /// Number of registered tools
    var count: Int {
        tools.count
    }
}
