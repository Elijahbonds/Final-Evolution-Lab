import Foundation
import AVFoundation
import Combine

/// Simple text-to-speech coaching for exercises. Reads demoDescription and cues when enabled.
@MainActor
final class ExerciseNarrationService: ObservableObject {
    static let shared = ExerciseNarrationService()

    @Published var isEnabled: Bool = false
    private let synthesizer = AVSpeechSynthesizer()

    func speakIntro(for exercise: TrainingExercise) {
        guard isEnabled, !synthesizer.isSpeaking else { return }
        let text = "\(exercise.name). \(exercise.cues)"
        speak(text)
    }

    func speakSetComplete(currentSet: Int, totalSets: Int) {
        guard isEnabled else { return }
        let remaining = totalSets - currentSet
        let text: String
        if remaining > 0 {
            text = "Set \(currentSet) complete. \(remaining) sets left."
        } else {
            text = "Exercise complete. Nice work."
        }
        speak(text)
    }

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47
        synthesizer.speak(utterance)
    }
}

