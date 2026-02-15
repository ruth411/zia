//
//  InputBarView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Input bar with text field, mic icon, and send button
struct InputBarView: View {
    @Binding var inputText: String
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Text field with rounded pill shape
            TextField("Ask Zia anything...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .disabled(isLoading)
                .onSubmit { onSend() }

            // Microphone button
            Button {
                // Voice input — future feature
            } label: {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Voice input (coming soon)")

            // Send button
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 24, height: 24)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundColor(inputText.isEmpty ? .gray : .blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty)
                .help("Send message")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
