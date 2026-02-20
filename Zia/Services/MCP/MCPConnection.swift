//
//  MCPConnection.swift
//  Zia
//
//

import Foundation

/// Manages a single MCP server connection over stdio (JSON-RPC 2.0).
/// Launches the server process, performs the initialize handshake,
/// discovers tools, and executes tool calls.
class MCPConnection {

    // MARK: - Properties

    let serverName: String
    let config: MCPServerConfig

    private(set) var state: MCPServerState = .disconnected
    private(set) var tools: [MCPToolInfo] = []

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var nextRequestId = 1
    private var pendingRequests: [Int: CheckedContinuation<JSONRPCResponse, Error>] = [:]
    private var readBuffer = Data()
    private let bufferQueue = DispatchQueue(label: "com.zia.mcp.buffer")

    // MARK: - Lifecycle

    init(serverName: String, config: MCPServerConfig) {
        self.serverName = serverName
        self.config = config
    }

    deinit {
        disconnect()
    }

    /// Start the MCP server process and perform initialization handshake
    func connect() async throws {
        state = .connecting

        do {
            try launchProcess()
            try await performInitialize()
            try await discoverTools()
            state = .connected
            print("[MCP] \(serverName): Connected with \(tools.count) tools")
        } catch {
            state = .failed(error.localizedDescription)
            disconnect()
            throw error
        }
    }

    /// Stop the server process
    func disconnect() {
        if let process = process, process.isRunning {
            process.terminate()
        }
        process = nil
        stdinPipe = nil
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        tools = []
        pendingRequests.removeAll()
        readBuffer = Data()
        state = .disconnected
    }

    /// Call a tool on this MCP server
    func callTool(name: String, arguments: [String: AnyCodable]) async throws -> MCPToolCallResult {
        let params = JSONRPCParams([
            "name": name,
            "arguments": arguments.mapValues { $0.value }
        ])

        let response = try await sendRequest(method: "tools/call", params: params)

        if let error = response.error {
            return MCPToolCallResult(content: "MCP error: \(error.message)", isError: true)
        }

        // Parse tool result content
        if let result = response.result?.value as? [String: Any],
           let content = result["content"] as? [[String: Any]] {
            // MCP returns content as array of {type: "text", text: "..."}
            let texts = content.compactMap { block -> String? in
                guard let type = block["type"] as? String, type == "text",
                      let text = block["text"] as? String else { return nil }
                return text
            }
            let isError = result["isError"] as? Bool ?? false
            return MCPToolCallResult(content: texts.joined(separator: "\n"), isError: isError)
        }

        // Fallback: serialize the result as JSON
        if let result = response.result {
            if let data = try? JSONEncoder().encode(result),
               let str = String(data: data, encoding: .utf8) {
                return MCPToolCallResult(content: str, isError: false)
            }
        }

        return MCPToolCallResult(content: "{\"result\": null}", isError: false)
    }

    // MARK: - Process Management

    private func launchProcess() throws {
        let proc = Process()

        // Resolve command path
        let command = config.command
        if command.hasPrefix("/") {
            proc.executableURL = URL(fileURLWithPath: command)
        } else {
            // Search in common paths
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = [command] + (config.args ?? [])
        }

        if proc.executableURL?.lastPathComponent != "env" {
            proc.arguments = config.args
        }

        // Set environment
        var env = ProcessInfo.processInfo.environment
        if let extraEnv = config.env {
            for (key, value) in extraEnv {
                env[key] = value
            }
        }
        // Ensure node/npx can be found
        let pathAdditions = ["/usr/local/bin", "/opt/homebrew/bin", "\(NSHomeDirectory())/.nvm/versions/node/*/bin"]
            .joined(separator: ":")
        env["PATH"] = (env["PATH"] ?? "") + ":" + pathAdditions
        proc.environment = env

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderr

        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr

        // Read stdout asynchronously for JSON-RPC responses
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.handleStdoutData(data)
        }

        // Log stderr
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else { return }
            print("[MCP] \(self?.serverName ?? "?"): stderr: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        proc.terminationHandler = { [weak self] _ in
            guard let self = self else { return }
            print("[MCP] \(self.serverName): Process terminated")
            self.state = .failed("Process terminated unexpectedly")
            // Fail all pending requests
            self.bufferQueue.sync {
                for (_, continuation) in self.pendingRequests {
                    continuation.resume(throwing: MCPError.serverDisconnected)
                }
                self.pendingRequests.removeAll()
            }
        }

        try proc.run()
        self.process = proc
        print("[MCP] \(serverName): Process launched (PID \(proc.processIdentifier))")
    }

    // MARK: - JSON-RPC Communication

    private func sendRequest(method: String, params: JSONRPCParams? = nil) async throws -> JSONRPCResponse {
        // Atomically grab the next ID on the serial bufferQueue to prevent data races
        let requestId = bufferQueue.sync { () -> Int in
            let id = nextRequestId
            nextRequestId += 1
            return id
        }

        let request = JSONRPCRequest(id: requestId, method: method, params: params)

        guard let data = try? JSONEncoder().encode(request) else {
            throw MCPError.encodingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            bufferQueue.sync {
                pendingRequests[requestId] = continuation
            }

            guard let stdin = stdinPipe else {
                bufferQueue.sync {
                    _ = pendingRequests.removeValue(forKey: requestId)
                }
                continuation.resume(throwing: MCPError.serverDisconnected)
                return
            }

            var message = data
            message.append(contentsOf: [0x0A]) // newline delimiter
            stdin.fileHandleForWriting.write(message)
        }
    }

    private func sendNotification(method: String, params: JSONRPCParams? = nil) throws {
        let notification = JSONRPCNotification(method: method, params: params)
        guard let data = try? JSONEncoder().encode(notification) else {
            throw MCPError.encodingFailed
        }
        var message = data
        message.append(contentsOf: [0x0A])
        stdinPipe?.fileHandleForWriting.write(message)
    }

    private func handleStdoutData(_ data: Data) {
        bufferQueue.sync {
            readBuffer.append(data)
        }
        processBuffer()
    }

    private func processBuffer() {
        bufferQueue.sync {
            while let newlineIndex = readBuffer.firstIndex(of: 0x0A) {
                let lineData = readBuffer[readBuffer.startIndex..<newlineIndex]
                readBuffer = Data(readBuffer[(newlineIndex + 1)...])

                guard !lineData.isEmpty else { continue }

                do {
                    let response = try JSONDecoder().decode(JSONRPCResponse.self, from: Data(lineData))
                    if let id = response.id, let continuation = pendingRequests.removeValue(forKey: id) {
                        continuation.resume(returning: response)
                    }
                } catch {
                    // Might be a notification or malformed — log and skip
                    if let text = String(data: Data(lineData), encoding: .utf8) {
                        print("[MCP] \(serverName): Unhandled message: \(text.prefix(200))")
                    }
                }
            }
        }
    }

    // MARK: - MCP Handshake

    private func performInitialize() async throws {
        let initParams: [String: Any] = [
            "protocolVersion": "2024-11-05",
            "capabilities": [String: Any](),
            "clientInfo": [
                "name": "Zia",
                "version": "1.0.0"
            ]
        ]

        let response = try await sendRequest(
            method: "initialize",
            params: JSONRPCParams(initParams)
        )

        if let error = response.error {
            throw MCPError.initializeFailed(error.message)
        }

        // Send initialized notification
        try sendNotification(method: "notifications/initialized")
        print("[MCP] \(serverName): Initialized")
    }

    private func discoverTools() async throws {
        let response = try await sendRequest(method: "tools/list")

        if let error = response.error {
            throw MCPError.toolDiscoveryFailed(error.message)
        }

        // Parse tools from result
        guard let result = response.result?.value as? [String: Any],
              let toolsArray = result["tools"] as? [[String: Any]] else {
            tools = []
            return
        }

        // Re-encode and decode to get typed MCPToolInfo
        let toolsData = try JSONSerialization.data(withJSONObject: toolsArray)
        tools = try JSONDecoder().decode([MCPToolInfo].self, from: toolsData)
    }
}

// MARK: - MCP Errors

enum MCPError: LocalizedError {
    case serverDisconnected
    case encodingFailed
    case initializeFailed(String)
    case toolDiscoveryFailed(String)
    case toolCallFailed(String)
    case configNotFound

    var errorDescription: String? {
        switch self {
        case .serverDisconnected:
            return "MCP server disconnected"
        case .encodingFailed:
            return "Failed to encode JSON-RPC message"
        case .initializeFailed(let msg):
            return "MCP initialize failed: \(msg)"
        case .toolDiscoveryFailed(let msg):
            return "MCP tool discovery failed: \(msg)"
        case .toolCallFailed(let msg):
            return "MCP tool call failed: \(msg)"
        case .configNotFound:
            return "MCP config file not found at ~/.zia/mcp.json"
        }
    }
}
