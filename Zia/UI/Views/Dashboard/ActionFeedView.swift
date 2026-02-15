//
//  ActionFeedView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Activity feed showing Zia's actions and responses
struct ActionFeedView: View {
    let items: [ActionFeedItem]
    let onDismiss: (UUID) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(items) { item in
                ActionFeedItemView(
                    item: item,
                    onDismiss: { onDismiss(item.id) }
                )
            }
        }
        .padding(.horizontal, 16)
    }
}

/// Individual action/response card
struct ActionFeedItemView: View {
    let item: ActionFeedItem
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: title + action/close button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        if item.status == .inProgress {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        }

                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                    }

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer()

                Button(action: item.status == .inProgress ? {} : onDismiss) {
                    Text(item.status == .inProgress ? "Action" : "Close")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Completed status
            if item.status == .completed && !item.bulletPoints.isEmpty {
                Divider()

                Text("Done Completed")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                // Bullet points
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(item.bulletPoints.prefix(5), id: \.self) { point in
                        HStack(alignment: .top, spacing: 5) {
                            Text("\u{2022}")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(point)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
    }
}
