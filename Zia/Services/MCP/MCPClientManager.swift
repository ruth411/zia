//
//  MCPClientManager.swift
//  Zia
//
//

import Foundation
import Combine

/// Manages all MCP server connections.
/// Reads configuration from ~/.zia/mcp.json, launches servers,
/// and registers discovered tools in the ToolRegistry.
class MCPClientManager: ObservableObject {

    // MARK: - Properties

    @Published private(set) var servers: [String: MCPServerStatus] = [:]

    private var connections: [String: MCPConnection] = [:]
    private let configPath: String

    /// All tools discovered from MCP servers
    var allBridgeTools: [MCPBridgeTool] {
        connections.values.flatMap { connection in
            connection.tools.map { toolInfo in
                MCPBridgeTool(
                    toolInfo: toolInfo,
                    serverName: connection.serverName,
                    connection: connection
                )
            }
        }
    }

    /// Total count of MCP tools
    var toolCount: Int {
        connections.values.reduce(0) { $0 + $1.tools.count }
    }

    // MARK: - Initialization

    init(configPath: String? = nil) {
        self.configPath = configPath ?? MCPClientManager.defaultConfigPath
    }

    static var defaultConfigPath: String {
        let home = NSHomeDirectory()
        return "\(home)/.zia/mcp.json"
    }

    // MARK: - Public Methods

    /// Load config and start all MCP servers
    func startAll() async {
        guard let config = loadConfig() else {
            return
        }

        for (name, serverConfig) in config.mcpServers {
            await startServer(name: name, config: serverConfig)
        }
    }

    /// Stop all MCP servers
    func stopAll() {
        for (_, connection) in connections {
            connection.disconnect()
        }
        connections.removeAll()
        DispatchQueue.main.async {
            self.servers.removeAll()
        }
    }

    /// Restart a specific server
    func restart(server name: String) async {
        if let connection = connections[name] {
            connection.disconnect()
            await startServer(name: name, config: connection.config)
        }
    }

    /// Reload config and restart all servers
    func reloadConfig() async {
        stopAll()
        await startAll()
    }

    /// Register all MCP tools into a ToolRegistry
    func registerTools(in registry: ToolRegistry) {
        for tool in allBridgeTools {
            registry.register(tool)
        }
    }

    // MARK: - Private Methods

    private func startServer(name: String, config: MCPServerConfig) async {
        let connection = MCPConnection(serverName: name, config: config)
        connections[name] = connection

        DispatchQueue.main.async {
            self.servers[name] = MCPServerStatus(
                name: name,
                state: .connecting,
                toolCount: 0
            )
        }

        do {
            try await connection.connect()

            DispatchQueue.main.async {
                self.servers[name] = MCPServerStatus(
                    name: name,
                    state: .connected,
                    toolCount: connection.tools.count
                )
            }
        } catch {
            DispatchQueue.main.async {
                self.servers[name] = MCPServerStatus(
                    name: name,
                    state: .failed(error.localizedDescription),
                    toolCount: 0
                )
            }
        }
    }

    private func loadConfig() -> MCPConfig? {
        let expandedPath = (configPath as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            return try JSONDecoder().decode(MCPConfig.self, from: data)
        } catch {
            print("[MCP] Failed to parse config: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Server Status Model

/// Published status of an MCP server (for UI)
struct MCPServerStatus: Identifiable {
    let id: String
    let name: String
    let state: MCPServerState
    let toolCount: Int

    init(name: String, state: MCPServerState, toolCount: Int) {
        self.id = name
        self.name = name
        self.state = state
        self.toolCount = toolCount
    }
}
