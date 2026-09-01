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
