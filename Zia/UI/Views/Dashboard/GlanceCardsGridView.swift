//
//  GlanceCardsGridView.swift
//  Zia
//
//

import SwiftUI

/// Horizontal row of glance capability cards (app-icon style)
struct GlanceCardsGridView: View {
    let cards: [GlanceCard]
    let onCardTap: (GlanceCard) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(cards) { card in
                GlanceCardView(card: card) {
                    onCardTap(card)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}
