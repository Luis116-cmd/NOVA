import Foundation
import Speech
import AVFoundation

@preconcurrency
public final class NOVASpeechService: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var isStoppingIntentionally = false

    public private(set) var isRunning = false

    public override init() {
        super.init()
        speechRecognizer?.delegate = self
    }

    public func start(
        onPartial: @escaping (String) -> Void,
        onFinal: @escaping (String) -> Void,
        onState: @escaping (Bool, String?) -> Void
    ) {
        stop()
        isStoppingIntentionally = false

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            onState(false, "Speech recognizer unavailable.")
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            onState(false, "No microphone input is available. Check System Settings → Privacy & Security → Microphone.")
            return
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRunning = true
            onState(true, nil)
        } catch {
            inputNode.removeTap(onBus: 0)
            isRunning = false
            onState(false, "Microphone failed to start: \(error.localizedDescription)")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let transcription = result.bestTranscription.formattedString
                onPartial(transcription)

                if result.isFinal && !transcription.isEmpty {
                    onFinal(transcription)
                    self.stop()
                    return
                }

                self.silenceTimer?.invalidate()
                if !transcription.isEmpty {
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                        guard let self, self.isRunning else { return }
                        onFinal(transcription)
                        self.stop()
                    }
                }
            }

            if let error {
                let desc = error.localizedDescription.lowercased()
                if self.isStoppingIntentionally || desc.contains("cancelled") || desc.contains("canceled") {
                    return
                }
                self.stop()
                onState(false, error.localizedDescription)
            }
        }
    }

    public func stop() {
        isStoppingIntentionally = true
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRunning = false
    }

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available {
            stop()
        }
    }
}
