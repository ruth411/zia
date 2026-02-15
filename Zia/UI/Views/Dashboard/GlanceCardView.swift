//
//  GlanceCardView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Individual glance card styled like a macOS app icon
struct GlanceCardView: View {
    let card: GlanceCard

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Square icon with large rounded corners (app-icon style)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: card.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .overlay(
                        Image(systemName: card.iconName)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(card.iconColor)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

                // Notification badge
                if card.badgeCount > 0 {
                    BadgeView(count: card.badgeCount)
                        .offset(x: 4, y: -4)
                }
            }

            // Label below the icon
            Text(card.title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

/// Blue notification badge (matches mockup)
struct BadgeView: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
            Text("\(count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
