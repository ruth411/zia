//
//  TabPillsView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Horizontal scrollable category tab pills in a rounded container
struct TabPillsView: View {
    @Binding var selectedCategory: DashboardCategory

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DashboardCategory.allCases) { category in
                TabPill(
                    title: category.rawValue,
                    isSelected: selectedCategory == category
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.2, green: 0.35, blue: 0.3).opacity(0.3))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

/// Individual pill button
struct TabPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected
                            ? Color.white.opacity(0.2)
                            : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }
}
