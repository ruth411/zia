//
//  InputBarView.swift
//  Zia
//
//

import SwiftUI

/// Input bar with text field, mic icon, and send button
struct InputBarView: View {
    @Binding var inputText: String
    let isLoading: Bool
    let onSend: () -> Void

    @ObservedObject var speechService: SpeechRecognitionService

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

            // Microphone button (push-to-talk)
            Button {
                toggleVoiceInput()
            } label: {
                Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                    .font(.body)
                    .foregroundColor(speechService.isListening ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(speechService.isListening ? "Stop listening" : "Voice input")

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
        .onAppear {
            speechService.requestAuthorization()
        }
        .onChange(of: speechService.isListening) { listening in
            if !listening && !speechService.transcribedText.isEmpty {
                inputText = speechService.transcribedText
            }
        }
    }

    private func toggleVoiceInput() {
        if speechService.isListening {
            speechService.stopListening()
        } else {
            do {
                try speechService.startListening()
            } catch {
                print("Failed to start speech recognition: \(error)")
            }
        }
    }
}
