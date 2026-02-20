//
//  SpotifyTools.swift
//  Zia
//
//

import Foundation

/// Tool: spotify_get_current_track
struct SpotifyGetCurrentTrackTool: Tool {
    let name = "spotify_get_current_track"
    let spotifyService: SpotifyService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Get the currently playing track on Spotify including track name, artist, album, and playback status.",
            inputSchema: ToolInputSchema(properties: [:])
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        return try await spotifyService.getCurrentTrack()
    }
}

/// Tool: spotify_play_pause
struct SpotifyPlayPauseTool: Tool {
    let name = "spotify_play_pause"
    let spotifyService: SpotifyService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Play or pause Spotify playback.",
            inputSchema: ToolInputSchema(
                properties: [
                    "action": PropertySchema(
                        type: "string",
                        description: "Either 'play' or 'pause'",
                        enumValues: ["play", "pause"]
                    )
                ],
                required: ["action"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let action = try input.requiredString("action")
        switch action {
        case "play":
            try await spotifyService.play()
            return "{\"success\": true, \"action\": \"play\"}"
        case "pause":
            try await spotifyService.pause()
            return "{\"success\": true, \"action\": \"pause\"}"
        default:
            throw ToolError.invalidParameter("action", expected: "'play' or 'pause'")
        }
    }
}

/// Tool: spotify_skip
struct SpotifySkipTool: Tool {
    let name = "spotify_skip"
    let spotifyService: SpotifyService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Skip to the next or previous track on Spotify.",
            inputSchema: ToolInputSchema(
                properties: [
                    "direction": PropertySchema(
                        type: "string",
                        description: "Skip direction",
                        enumValues: ["next", "previous"]
                    )
                ],
                required: ["direction"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let direction = try input.requiredString("direction")
        switch direction {
        case "next":
            try await spotifyService.skipToNext()
            return "{\"success\": true, \"direction\": \"next\"}"
        case "previous":
            try await spotifyService.skipToPrevious()
            return "{\"success\": true, \"direction\": \"previous\"}"
        default:
            throw ToolError.invalidParameter("direction", expected: "'next' or 'previous'")
        }
    }
}

/// Tool: spotify_search
struct SpotifySearchTool: Tool {
    let name = "spotify_search"
    let spotifyService: SpotifyService

    private static let maxSearchLimit = 10

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Search for tracks on Spotify. Returns track names, artists, albums, and URIs that can be used with spotify_play_track.",
            inputSchema: ToolInputSchema(
                properties: [
                    "query": PropertySchema(type: "string", description: "Search query (song name, artist, etc.)"),
                    "limit": PropertySchema(type: "integer", description: "Max results (1-10, default 5)")
                ],
                required: ["query"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let query = try input.requiredString("query")
        let limit = input.optionalInt("limit") ?? 5
        return try await spotifyService.search(query: query, limit: min(limit, Self.maxSearchLimit))
    }
}

/// Tool: spotify_play_track
struct SpotifyPlayTrackTool: Tool {
    let name = "spotify_play_track"
    let spotifyService: SpotifyService

    var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: "Play a specific track on Spotify by its URI. Use spotify_search first to find the URI.",
            inputSchema: ToolInputSchema(
                properties: [
                    "uri": PropertySchema(type: "string", description: "Spotify track URI (e.g., spotify:track:xxxxx)")
                ],
                required: ["uri"]
            )
        )
    }

    func execute(input: [String: AnyCodable]) async throws -> String {
        let uri = try input.requiredString("uri")
        try await spotifyService.playTrack(uri: uri)
        return "{\"success\": true, \"uri\": \"\(uri)\"}"
    }
}
