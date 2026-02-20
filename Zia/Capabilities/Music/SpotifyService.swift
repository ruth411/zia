//
//  SpotifyService.swift
//  Zia
//
//

import Foundation

/// Service for Spotify Web API operations
class SpotifyService {

    private let authManager: AuthenticationManager
    private let baseURL = Configuration.API.Spotify.baseURL

    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }

    // MARK: - Playback

    func getCurrentTrack() async throws -> String {
        let data = try await apiRequest(path: "/me/player/currently-playing")
        if data.isEmpty {
            return "{\"is_playing\": false, \"message\": \"Nothing currently playing\"}"
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = json["item"] as? [String: Any] else {
            return "{\"is_playing\": false}"
        }

        let name = item["name"] as? String ?? "Unknown"
        let artists = (item["artists"] as? [[String: Any]])?
            .compactMap { $0["name"] as? String }
            .joined(separator: ", ") ?? "Unknown"
        let album = (item["album"] as? [String: Any])?["name"] as? String ?? "Unknown"
        let isPlaying = json["is_playing"] as? Bool ?? false
        let progressMs = json["progress_ms"] as? Int ?? 0
        let durationMs = (item["duration_ms"] as? Int) ?? 0

        return "{\"is_playing\": \(isPlaying), \"track\": \(jsonEscape(name)), \"artist\": \(jsonEscape(artists)), \"album\": \(jsonEscape(album)), \"progress_seconds\": \(progressMs / 1000), \"duration_seconds\": \(durationMs / 1000)}"
    }

    func play() async throws {
        _ = try await apiRequest(path: "/me/player/play", method: "PUT")
    }

    func pause() async throws {
        _ = try await apiRequest(path: "/me/player/pause", method: "PUT")
    }

    func skipToNext() async throws {
        _ = try await apiRequest(path: "/me/player/next", method: "POST")
    }

    func skipToPrevious() async throws {
        _ = try await apiRequest(path: "/me/player/previous", method: "POST")
    }

    // MARK: - Search

    func search(query: String, type: String = "track", limit: Int = 5) async throws -> String {
        let data = try await apiRequest(
            path: "/search",
            queryParams: ["q": query, "type": type, "limit": String(limit)]
        )

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tracks = json["tracks"] as? [String: Any],
              let items = tracks["items"] as? [[String: Any]] else {
            return "{\"results\": []}"
        }

        let results: [[String: Any]] = items.map { item in
            [
                "name": item["name"] as? String ?? "",
                "artist": ((item["artists"] as? [[String: Any]])?.first?["name"] as? String) ?? "",
                "album": (item["album"] as? [String: Any])?["name"] as? String ?? "",
                "uri": item["uri"] as? String ?? ""
            ]
        }

        if let data = try? JSONSerialization.data(withJSONObject: ["results": results], options: []),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{\"results\": []}"
    }

    // MARK: - Play Specific Track

    func playTrack(uri: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["uris": [uri]])
        _ = try await apiRequest(path: "/me/player/play", method: "PUT", body: body)
    }

    // MARK: - Private

    private func apiRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        queryParams: [String: String]? = nil
    ) async throws -> Data {
        guard authManager.isSpotifyAuthenticated else {
            throw ToolError.notAvailable("Spotify is not connected. Please connect Spotify in Settings first.")
        }

        let token = try await authManager.getValidToken(for: "Spotify")

        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw ToolError.executionFailed("Invalid Spotify API URL for path: \(path)")
        }
        if let params = queryParams {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw ToolError.executionFailed("Failed to construct Spotify API URL for path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ToolError.executionFailed("Invalid response from Spotify")
        }

        // 204 = success with no content (common for play/pause/skip)
        if http.statusCode == 204 { return Data() }

        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 404 {
                throw ToolError.executionFailed("No active Spotify device found. Please open Spotify on a device first.")
            }
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ToolError.executionFailed("Spotify API error \(http.statusCode): \(errorBody)")
        }

        return data
    }

}
