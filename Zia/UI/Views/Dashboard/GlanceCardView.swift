//
//  GlanceCardView.swift
//  Zia
//
//

import SwiftUI

/// Individual glance card styled like a macOS app icon
struct GlanceCardView: View {
    let card: GlanceCard
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
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
                VStack(spacing: 1) {
                    Text(card.title)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let subtitle = card.subtitle {
                        Text(subtitle)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isPressed)
        // minimumDuration: .infinity means the perform closure never fires.
        // The `pressing` callback is the only part used — it tracks the press state
        // for the scale animation, giving a tactile feel without a long-press action.
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
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
