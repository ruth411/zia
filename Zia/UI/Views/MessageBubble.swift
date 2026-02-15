//
//  MessageBubble.swift
//  Zia
//
//  Created by Claude on 2/13/26.
//

import SwiftUI

/// A chat message bubble
struct MessageBubble: View {

    let message: Message
    let viewModel: ChatViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message text
                let displayText = viewModel.displayText(for: message)
                if !displayText.isEmpty {
                    Text(displayText)
                        .padding(12)
                        .background(message.role == .user ? Color.blue : Color(NSColor.controlBackgroundColor))
                        .foregroundColor(message.role == .user ? .white : .primary)
                        .cornerRadius(16)
                }

                // Tool uses (if any)
                if viewModel.hasToolUses(message) {
                    ForEach(viewModel.getToolUses(from: message)) { toolUse in
                        HStack(spacing: 6) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Using tool: \(toolUse.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                }

                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if message.role == .assistant {
                Spacer()
            }
        }
    }
}
