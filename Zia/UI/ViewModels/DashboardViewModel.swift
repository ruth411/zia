//
//  DashboardViewModel.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import Foundation
import Combine
import SwiftUI

/// Central view model for the dashboard, wrapping ChatViewModel
@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var selectedCategory: DashboardCategory = .today
    @Published var glanceCards: [GlanceCard] = GlanceCard.placeholders
    @Published var actionFeedItems: [ActionFeedItem] = []
    @Published var suggestions: [Suggestion] = Suggestion.defaults
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let chatViewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Glance cards filtered by the selected category tab
    var filteredGlanceCards: [GlanceCard] {
        if selectedCategory == .today {
            return glanceCards
        }
        return glanceCards.filter { $0.category == selectedCategory }
    }

    // MARK: - Initialization

    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
        bindToChatViewModel()
    }

    // MARK: - Public Methods

    /// Send a message to Claude
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        isLoading = true
        errorMessage = nil

        // Create in-progress feed item
        let feedItemId = UUID()
        let feedItem = ActionFeedItem(
            id: feedItemId,
            title: deriveActionTitle(from: text),
            subtitle: text,
            status: .inProgress
        )
        actionFeedItems.insert(feedItem, at: 0)

        // Forward to ChatViewModel
        chatViewModel.inputText = text
        await chatViewModel.sendMessage()

        // Update feed item with response
        updateFeedItem(feedItemId)
        isLoading = false
    }

    /// Send a pre-defined query (from glance card tap or suggestion tap)
    func sendQuery(_ query: String) async {
        inputText = query
        await sendMessage()
    }

    /// Dismiss an action feed item
    func dismissFeedItem(_ id: UUID) {
        withAnimation {
            actionFeedItems.removeAll { $0.id == id }
        }
    }

    /// Dismiss error message
    func dismissError() {
        errorMessage = nil
        chatViewModel.dismissError()
    }

    // MARK: - Private Helpers

    private func bindToChatViewModel() {
        chatViewModel.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)
    }

    /// Derive a user-friendly action title from the input text
    private func deriveActionTitle(from text: String) -> String {
        let lowered = text.lowercased()
        if lowered.contains("calendar") || lowered.contains("schedule") || lowered.contains("event") {
            return "Checking your calendar..."
        }
        if lowered.contains("music") || lowered.contains("play") || lowered.contains("song") || lowered.contains("spotify") {
            return "Playing music..."
        }
        if lowered.contains("flight") || lowered.contains("travel") {
            return "Checking flights..."
        }
        if lowered.contains("email") || lowered.contains("mail") || lowered.contains("send") {
            return "Checking email..."
        }
        if lowered.contains("remind") {
            return "Setting reminder..."
        }
        return "Working on it..."
    }

    /// Update a feed item with the Claude response
    private func updateFeedItem(_ id: UUID) {
        guard let index = actionFeedItems.firstIndex(where: { $0.id == id }) else { return }

        // Get the latest assistant message
        if let lastAssistant = chatViewModel.messages.last(where: { $0.role == .assistant }) {
            let text = chatViewModel.displayText(for: lastAssistant)
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }

            // First line becomes the title, rest are bullet points
            let title: String
            let bullets: [String]

            if lines.count > 1 {
                title = lines[0]
                bullets = Array(lines.dropFirst())
            } else {
                title = actionFeedItems[index].title.replacingOccurrences(of: "...", with: "")
                bullets = lines
            }

            actionFeedItems[index] = ActionFeedItem(
                id: id,
                title: title,
                subtitle: nil,
                bulletPoints: bullets,
                status: chatViewModel.errorMessage != nil ? .failed : .completed,
                timestamp: Date()
            )
        } else if let error = chatViewModel.errorMessage {
            // Error case
            actionFeedItems[index] = ActionFeedItem(
                id: id,
                title: actionFeedItems[index].title.replacingOccurrences(of: "...", with: " failed"),
                subtitle: error,
                status: .failed,
                timestamp: Date()
            )
        }
    }
}
