import Foundation
import Speech
import AVFoundation

public class NOVASpeechService: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var isStoppingIntentionally = false

    public private(set) var isRunning: Bool = false

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

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRunning = true
            onState(true, nil)
        } catch {
            isRunning = false
            onState(false, "Audio engine failed to start: \(error.localizedDescription)")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                onPartial(transcription)

                self.silenceTimer?.invalidate()
                self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                    if transcription.isEmpty == false {
                        onFinal(transcription)
                        self.stop()
                    }
                }
            }

            if let error = error {
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
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRunning = false
    }
}
