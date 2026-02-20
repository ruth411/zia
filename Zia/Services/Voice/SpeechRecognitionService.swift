//
//  SpeechRecognitionService.swift
//  Zia
//
//

import AVFoundation
import Combine
import Foundation
import Speech

/// On-device speech recognition using Apple's SFSpeechRecognizer.
/// Push-to-talk model: hold the mic button, speak, release to send.
@MainActor
class SpeechRecognitionService: ObservableObject {

    // MARK: - Published

    @Published private(set) var isListening = false
    @Published private(set) var transcribedText = ""
    @Published private(set) var isAvailable = false

    // MARK: - Private

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                self?.isAvailable = (status == .authorized)
                if status != .authorized {
                    print("SpeechRecognition: Not authorized (\(status.rawValue))")
                }
            }
        }
    }

    // MARK: - Recognition

    /// Start listening for speech
    func startListening() throws {
        // Cancel any in-progress recognition
        stopListening()

        transcribedText = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Privacy: stay on-device

        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || (result?.isFinal ?? false) {
                    self?.cleanupAudio()
                }
            }
        }

        isListening = true
        print("SpeechRecognition: Listening...")
    }

    /// Stop listening and finalize transcription
    func stopListening() {
        recognitionRequest?.endAudio()
        cleanupAudio()
        isListening = false
    }

    // MARK: - Cleanup

    private func cleanupAudio() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}
