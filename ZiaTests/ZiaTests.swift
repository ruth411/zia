//
//  ZiaTests.swift
//  ZiaTests
//
//  Created by Ruthwik Dovala on 2/13/26.
//

import XCTest
@testable import Zia

final class ZiaTests: XCTestCase {

    // MARK: - Mock Tools

    private struct MockSuccessTool: Tool {
        let name = "mock_success"
        var definition: ToolDefinition {
            ToolDefinition(name: name, description: "Mock tool that always succeeds",
                           inputSchema: ToolInputSchema(properties: [:]))
        }
        func execute(input: [String: AnyCodable]) async throws -> String { "ok" }
    }

    private struct MockFailTool: Tool {
        let name = "mock_fail"
        var definition: ToolDefinition {
            ToolDefinition(name: name, description: "Mock tool that always throws",
                           inputSchema: ToolInputSchema(properties: [:]))
        }
        func execute(input: [String: AnyCodable]) async throws -> String {
            throw ToolError.executionFailed("intentional failure")
        }
    }

    // MARK: - Group A: ToolError String Formatting

    func testToolErrorMissingParameter() {
        let error = ToolError.missingParameter("apiKey")
        XCTAssertEqual(error.errorDescription, "Missing required parameter: apiKey")
    }

    func testToolErrorPermissionDenied() {
        let error = ToolError.permissionDenied("outside home directory")
        XCTAssertTrue(error.errorDescription?.contains("Permission denied") == true)
    }

    // MARK: - Group B: ToolExecutor Wrapping
    // @MainActor ensures create/await/dealloc all happen on the same executor,
    // preventing Swift 5.9 isolated-deinit SIGABRT under XCTest async context.

    @MainActor
    func testToolExecutorUnknownToolReturnsError() async {
        let executor = ToolExecutor(registry: ToolRegistry())
        let result = await executor.execute(ToolUse(id: "t1", name: "no_such_tool", input: [:]))
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("no_such_tool"))
    }

    @MainActor
    func testToolExecutorSuccessfulExecutionReturnsContent() async {
        let registry = ToolRegistry()
        registry.register(MockSuccessTool())
        let executor = ToolExecutor(registry: registry)
        let result = await executor.execute(ToolUse(id: "t2", name: "mock_success", input: [:]))
        XCTAssertFalse(result.isError)
        XCTAssertEqual(result.content, "ok")
    }

    @MainActor
    func testToolExecutorWrapsExceptionAsError() async {
        let registry = ToolRegistry()
        registry.register(MockFailTool())
        let executor = ToolExecutor(registry: registry)
        let result = await executor.execute(ToolUse(id: "t3", name: "mock_fail", input: [:]))
        XCTAssertTrue(result.isError)
        XCTAssertTrue(result.content.contains("intentional failure"))
    }

    // MARK: - Group C: Path Traversal Protection

    func testPathTraversalIsBlocked() async {
        let tool = ReadFileTool()
        do {
            _ = try await tool.execute(input: ["path": AnyCodable("~/../../../etc/passwd")])
            XCTFail("Expected ToolError.permissionDenied to be thrown")
        } catch let error as ToolError {
            guard case .permissionDenied = error else {
                XCTFail("Expected .permissionDenied, got: \(error)")
                return
            }
            // Test passes — correct error thrown
        } catch {
            XCTFail("Expected ToolError, got: \(type(of: error)): \(error)")
        }
    }
}
