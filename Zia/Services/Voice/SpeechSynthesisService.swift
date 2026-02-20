//
//  SpeechSynthesisService.swift
//  Zia
//
//

import AppKit
import Combine
import Foundation

/// Text-to-speech using NSSpeechSynthesizer.
/// Can speak Claude's responses aloud when enabled.
@MainActor
class SpeechSynthesisService: ObservableObject {

    // MARK: - Published

    @Published var isEnabled = false
    @Published private(set) var isSpeaking = false

    // MARK: - Private

    private let synthesizer = NSSpeechSynthesizer()

    // MARK: - Init

    init() {
        // Load preference
        isEnabled = UserDefaults.standard.bool(
            forKey: "\(Configuration.App.bundleIdentifier).speakResponses"
        )
    }

    // MARK: - Public

    /// Speak text aloud (only if TTS is enabled)
    func speak(_ text: String) {
        guard isEnabled else { return }
        stop()

        // Clean up text for speech (remove markdown, URLs, etc.)
        let cleanedText = cleanForSpeech(text)
        guard !cleanedText.isEmpty else { return }

        synthesizer.startSpeaking(cleanedText)
        isSpeaking = true

        // Monitor completion
        Task {
            while synthesizer.isSpeaking {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            isSpeaking = false
        }
    }

    /// Stop speaking
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking()
        }
        isSpeaking = false
    }

    /// Toggle TTS on/off and persist preference
    func toggle() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: "\(Configuration.App.bundleIdentifier).speakResponses")
        if !isEnabled {
            stop()
        }
    }

    // MARK: - Text Cleanup

    private func cleanForSpeech(_ text: String) -> String {
        var cleaned = text

        // Remove markdown formatting
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")

        // Remove markdown headers
        cleaned = cleaned.replacingOccurrences(of: "### ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "## ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "# ", with: "")

        // Remove bullet points
        cleaned = cleaned.replacingOccurrences(of: "- ", with: "")
        cleaned = cleaned.replacingOccurrences(of: "* ", with: "")

        // Trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Limit length for speech (don't read super long responses)
        if cleaned.count > 500 {
            cleaned = String(cleaned.prefix(500)) + "... and more."
        }

        return cleaned
    }
}
