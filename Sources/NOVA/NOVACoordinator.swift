import Foundation

@MainActor
public final class NOVACoordinator {
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
        speechService.isRunning
    }

    public init(
        brain: NOVABrain = NOVABrain(),
        speaker: NOVASpeaker = NOVASpeaker(),
        speechService: NOVASpeechService = NOVASpeechService()
    ) {
        self.brain = brain
        self.speaker = speaker
        self.speechService = speechService

        self.speaker.onSpeechFinished = { [weak self] in
            guard let self, self.isContinuousVoiceEnabled else { return }
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
            onState: { [weak self] isRunning, error in
                self?.onListeningChanged?(isRunning)
                if let error {
                    self?.onTranscript?("Speech error: \(error)")
                }
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

        Task { @MainActor [weak self] in
            guard let self else { return }
            let response = try? await brain.reply(to: message)
            let textToSpeak = response ?? "I didn't quite catch that."
            publish(textToSpeak)
        }
    }

    private func publish(_ message: String) {
        onReply?(message)
        if preferences.voiceEnabled {
            speaker.say(message)
        }
    }
}
