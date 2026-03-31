import Foundation

#if canImport(AVFAudio)
import AVFAudio
#endif

@MainActor
final class NarrationSpeechService {
#if canImport(AVFAudio)
    private let synthesizer = AVSpeechSynthesizer()
#endif

    func speak(script: String, voiceProfile: AIVoiceProfile) {
#if canImport(AVFAudio)
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: script)
        utterance.rate = Float(voiceProfile.speakingRate)
        utterance.pitchMultiplier = Float(voiceProfile.pitchMultiplier)
        if let voice = AVSpeechSynthesisVoice(language: voiceProfile.localeIdentifier) {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
#endif
    }

    func stopSpeaking() {
#if canImport(AVFAudio)
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
#endif
    }
}
