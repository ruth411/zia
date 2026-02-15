//
//  MainView.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import SwiftUI

/// Main dashboard view displayed in the menu bar popover
struct MainView: View {

    // MARK: - Environment

    @EnvironmentObject var dependencyContainer: DependencyContainer

    // MARK: - State

    @StateObject private var dashboardViewModel: DashboardViewModel
    @State private var showOnboarding = !Configuration.Onboarding.isCompleted

    // MARK: - Initialization

    init() {
        let container = DependencyContainer.shared
        let chatVM = ChatViewModel(
            aiProvider: container.aiProvider,
            conversationManager: container.conversationManager,
            ragService: container.ragService
        )
        _dashboardViewModel = StateObject(
            wrappedValue: DashboardViewModel(chatViewModel: chatVM)
        )
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
                        cards: dashboardViewModel.filteredGlanceCards
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

            // Section 5: Input bar
            InputBarView(
                inputText: $dashboardViewModel.inputText,
                isLoading: dashboardViewModel.isLoading,
                onSend: {
                    Task { await dashboardViewModel.sendMessage() }
                }
            )
        }
        .frame(
            width: Configuration.App.popoverWidth,
            height: Configuration.App.popoverHeight
        )
        .background(.ultraThinMaterial)
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
