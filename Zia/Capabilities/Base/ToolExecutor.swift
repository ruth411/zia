//
//  ToolExecutor.swift
//  Zia
//
//

import Foundation

/// Executes tools by name, producing ToolResult values.
/// Never throws — tool failures become error ToolResults so Claude can adapt.
class ToolExecutor {

    private let registry: ToolRegistry

    init(registry: ToolRegistry) {
        self.registry = registry
    }

    /// Execute a single tool use and return a ToolResult
    func execute(_ toolUse: ToolUse) async -> ToolResult {
        guard let tool = registry.tool(named: toolUse.name) else {
            return ToolResult(
                toolUseId: toolUse.id,
                content: "Error: Unknown tool '\(toolUse.name)'",
                isError: true
            )
        }

        do {
            let result = try await tool.execute(input: toolUse.input)
            return ToolResult(
                toolUseId: toolUse.id,
                content: result,
                isError: false
            )
        } catch {
            return ToolResult(
                toolUseId: toolUse.id,
                content: "Error: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    /// Execute multiple tool uses sequentially
    func executeAll(_ toolUses: [ToolUse]) async -> [ToolResult] {
        var results: [ToolResult] = []
        for toolUse in toolUses {
            let result = await execute(toolUse)
            results.append(result)
        }
        return results
    }
}
