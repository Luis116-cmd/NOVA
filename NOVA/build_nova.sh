#!/bin/bash
set -e

rm -f Sources/NOVA/NOVASettings.swift

cat << 'INNER' > Sources/NOVA/NOVAPreferences.swift
import Foundation

public struct NOVAPreferences {
    public var localModel: String = "llama3:8b"
    public var wakeWordEnabled: Bool = false
    public var voiceEnabled: Bool = true
    
    public init() {}
}
INNER

cat << 'INNER' > Sources/NOVA/NOVABrain.swift
import Foundation

public enum ArtifactKind {
    case studyGuide
    case summary
    case notes
}

public actor NOVABrain {
    private var conversationHistory: [[String: String]] = []
    private let historyFilePath: URL

    private let systemPrompt = """
    You are NOVA, a mature, articulate, and highly competent personal AI assistant.
    Speak naturally with composure, clarity, and intelligence. Maintain a grounded, thoughtful tone—avoid childish energy, overly casual slang, or robotic fluff.
    Keep spoken responses concise, clear, and direct. Do not read aloud special formatting characters like asterisks.

    STRICT ACCURACY & GROUNDING RULES:
    1. Never fabricate or invent personal facts, upcoming tests, assignments, schedules, or events unless explicitly stated by the user.
    2. If you do not have information about something, acknowledge what you know based on the conversation history or ask for clarification.
    """

    public init(preferences: Any? = nil) {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        self.historyFilePath = paths[0].appendingPathComponent("nova_history.json")
        Task {
            await self.loadHistoryFromDisk()
        }
    }

    public func reply(to prompt: String) async throws -> String {
        return await askOllama(prompt: prompt)
    }

    public func askOllama(prompt: String) async -> String {
        conversationHistory.append(["role": "user", "content": prompt])
        
        if conversationHistory.count > 20 {
            conversationHistory.removeFirst(conversationHistory.count - 20)
        }
        
        saveHistoryToDisk()

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        messages.append(contentsOf: conversationHistory)

        guard let url = URL(string: "http://localhost:11434/api/chat") else {
            return "Server URL error."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "llama3:8b",
            "messages": messages,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return "I couldn't reach Ollama. Make sure Ollama is running in the background."
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageObj = json["message"] as? [String: Any],
               let content = messageObj["content"] as? String {
                
                let cleanedResponse = content.trimmingCharacters(in: .whitespacesAndNewlines)
                conversationHistory.append(["role": "assistant", "content": cleanedResponse])
                saveHistoryToDisk()
                return cleanedResponse
            }
        } catch {
            return "Connection error: \(error.localizedDescription)"
        }

        return "I didn't receive a valid response."
    }

    public func artifact(topic: String, kind: ArtifactKind) async -> String {
        let prompt = "Create a comprehensive study guide on the topic: \(topic)."
        return await askOllama(prompt: prompt)
    }

    public func flashcards(topic: String) async -> [(String, String)] {
        let prompt = "Create 5 flashcards on \(topic). Format each line exactly as: Question | Answer"
        let response = await askOllama(prompt: prompt)
        
        var pairs: [(String, String)] = []
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let parts = line.components(separatedBy: "|")
            if parts.count == 2 {
                let q = parts[0].trimmingCharacters(in: .whitespaces)
                let a = parts[1].trimmingCharacters(in: .whitespaces)
                pairs.append((q, a))
            }
        }
        
        if pairs.isEmpty {
            pairs.append(("What is \(topic)?", "Key details about \(topic)."))
        }
        return pairs
    }

    public func clearMemory() {
        conversationHistory.removeAll()
        saveHistoryToDisk()
    }

    private func saveHistoryToDisk() {
        do {
            let data = try JSONSerialization.data(withJSONObject: conversationHistory, options: .prettyPrinted)
            try data.write(to: historyFilePath)
        } catch {
            print("Failed to save memory: \(error)")
        }
    }

    private func loadHistoryFromDisk() {
        do {
            if FileManager.default.fileExists(atPath: historyFilePath.path) {
                let data = try Data(contentsOf: historyFilePath)
                if let loaded = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                    self.conversationHistory = loaded
                }
            }
        } catch {
            print("Failed to load memory: \(error)")
        }
    }
}
INNER

cat << 'INNER' > Sources/NOVA/NOVASpeaker.swift
import Foundation
@preconcurrency import AVFoundation

public final class NOVASpeaker: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    public var onSpeechFinished: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func say(_ text: String, voiceID: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }

            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.pitchMultiplier = 0.95

            let voices = AVSpeechSynthesisVoice.speechVoices()
            if let explicitVoice = voiceID, let chosen = voices.first(where: { $0.identifier == explicitVoice }) {
                utterance.voice = chosen
            } else if let maleVoice = voices.first(where: { $0.language == "en-US" && $0.gender == .male }) {
                utterance.voice = maleVoice
            } else if let fallbackVoice = AVSpeechSynthesisVoice(language: "en-US") {
                utterance.voice = fallbackVoice
            }

            self.synthesizer.speak(utterance)
        }
    }

    public func speak(_ text: String) {
        say(text)
    }

    public func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.synthesizer.isSpeaking {
                self.synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechFinished?()
        }
    }
}
INNER

cat << 'INNER' > Sources/NOVA/NOVASpeechService.swift
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
INNER

cat << 'INNER' > Sources/NOVA/NOVACoordinator.swift
import Foundation

public class NOVACoordinator {
    private let brain: NOVABrain
    private let speaker: NOVASpeaker
    private let speechService: NOVASpeechService
    
    public var preferences = NOVAPreferences()

    public var onReply: ((String) -> Void)?
    public var onTranscript: ((String) -> Void)?
    public var onUserMessage: ((String) -> Void)?
    public var onListeningChanged: ((Bool) -> Void)?
    
    public var isContinuousVoiceEnabled: Bool = true

    public var isListening: Bool {
        return speechService.isRunning
    }

    public init(brain: NOVABrain = NOVABrain(), speaker: NOVASpeaker = NOVASpeaker(), speechService: NOVASpeechService = NOVASpeechService()) {
        self.brain = brain
        self.speaker = speaker
        self.speechService = speechService

        self.speaker.onSpeechFinished = { [weak self] in
            guard let self = self, self.isContinuousVoiceEnabled else { return }
            self.startListening()
        }
    }

    public func startListening() {
        speaker.stop()
        speechService.start(
            onPartial: { [weak self] partial in
                self?.onTranscript?(partial)
            },
            onFinal: { [weak self] finalQuery in
                self?.handle(finalQuery)
            },
            onState: { [weak self] isRunning, _ in
                self?.onListeningChanged?(isRunning)
            }
        )
    }

    public func stopListening() {
        speechService.stop()
        onListeningChanged?(false)
    }

    public func handle(_ message: String) {
        speechService.stop()
        onListeningChanged?(false)
        onUserMessage?(message)
        
        Task {
            let response = try? await brain.reply(to: message)
            let textToSpeak = response ?? "I didn't quite catch that."
            self.publish(textToSpeak)
        }
    }

    private func publish(_ message: String) {
        onReply?(message)
        if preferences.voiceEnabled {
            speaker.say(message)
        }
    }
}
INNER

cat << 'INNER' > Sources/NOVA/NOVASettings.swift
import Foundation
import AppKit

public class NOVASettingsPresenter {
    public static func show(from window: NSWindow?, coordinator: NOVACoordinator) {
        let alert = NSAlert()
        alert.messageText = "NOVA Settings"
        alert.informativeText = "Voice enabled: \(coordinator.preferences.voiceEnabled ? "On" : "Off")\nLocal model: \(coordinator.preferences.localModel)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
INNER

killall NOVA 2>/dev/null || true
swift build -c release
mkdir -p outputs/NOVA.app/Contents/MacOS outputs/NOVA.app/Contents/Resources
cp .build/release/NOVA outputs/NOVA.app/Contents/MacOS/NOVA

if [ -f Sources/NOVA/Resources/NOVA-Info.plist ]; then
    cp Sources/NOVA/Resources/NOVA-Info.plist outputs/NOVA.app/Contents/Info.plist
fi

chmod +x outputs/NOVA.app/Contents/MacOS/NOVA
open outputs/NOVA.app
