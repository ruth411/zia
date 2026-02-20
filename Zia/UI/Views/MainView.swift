//
//  MainView.swift
//  Zia
//
//

import SwiftUI

/// Main dashboard view displayed in the menu bar popover
struct MainView: View {

    // MARK: - Environment

    @EnvironmentObject var dependencyContainer: DependencyContainer

    // MARK: - State

    @StateObject private var dashboardViewModel: DashboardViewModel
    /// Owned here so it survives InputBarView re-creation; passed down as @ObservedObject
    @StateObject private var speechService: SpeechRecognitionService
    @State private var showOnboarding = !Configuration.Onboarding.isCompleted

    // MARK: - Initialization

    init() {
        let container = DependencyContainer.shared
        let chatVM = ChatViewModel(
            aiProvider: container.aiProvider,
            conversationManager: container.conversationManager,
            ragService: container.ragService,
            toolRegistry: container.toolRegistry,
            toolExecutor: container.toolExecutor
        )
        let glanceProvider = GlanceCardProvider(
            calendarService: container.calendarService,
            spotifyService: container.spotifyService
        )
        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(chatViewModel: chatVM, glanceCardProvider: glanceProvider)
        )
        _speechService = StateObject(wrappedValue: SpeechRecognitionService())
    }

    // MARK: - Body

    var body: some View {
        if showOnboarding {
            OnboardingView {
                showOnboarding = false
            }
        } else {
            dashboardContent
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            // Section 1: Header
            DashboardHeaderView(onSettingsTapped: openSettings)

            // Section 2: Category tabs
            TabPillsView(selectedCategory: $dashboardViewModel.selectedCategory)

            // Sections 3-4: Scrollable content
            ScrollView {
                VStack(spacing: 12) {
                    // Section 3: Glance cards (horizontal row)
                    GlanceCardsGridView(
                        cards: dashboardViewModel.filteredGlanceCards,
                        onCardTap: { card in
                            Task { await dashboardViewModel.sendQuery(card.actionQuery) }
                        }
                    )

                    // Section 4: Action feed
                    if dashboardViewModel.actionFeedItems.isEmpty {
                        emptyFeedView
                    } else {
                        ActionFeedView(
                            items: dashboardViewModel.actionFeedItems,
                            onDismiss: { id in
                                dashboardViewModel.dismissFeedItem(id)
                            }
                        )
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Section 5: Suggestions + Input bar
            if dashboardViewModel.actionFeedItems.isEmpty && !dashboardViewModel.isLoading {
                SuggestionStripView(
                    suggestions: dashboardViewModel.suggestions,
                    onTap: { suggestion in
                        Task { await dashboardViewModel.sendQuery(suggestion.text) }
                    }
                )
            }

            InputBarView(
                inputText: $dashboardViewModel.inputText,
                isLoading: dashboardViewModel.isLoading,
                onSend: {
                    Task { await dashboardViewModel.sendMessage() }
                },
                speechService: speechService
            )
        }
        .frame(
            width: Configuration.App.popoverWidth,
            height: Configuration.App.popoverHeight
        )
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: Configuration.Keys.Notifications.screenCaptureReady)) { notification in
            if let base64 = notification.userInfo?["base64"] as? String {
                Task {
                    await dashboardViewModel.sendScreenshotMessage(imageBase64: base64)
                }
            }
        }
        .alert("Error", isPresented: .constant(dashboardViewModel.errorMessage != nil)) {
            Button("OK") {
                dashboardViewModel.dismissError()
            }
        } message: {
            if let errorMessage = dashboardViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    private var emptyFeedView: some View {
        VStack(spacing: 8) {
            Text("Ask Zia anything!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Your responses will appear here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Actions

    private func openSettings() {
        if let appDelegate = dependencyContainer.appDelegate as? AppDelegate {
            appDelegate.showSettings()
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(DependencyContainer.shared)
}
