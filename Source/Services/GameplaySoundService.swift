import Foundation
import AudioToolbox

/// Central place for gameplay SFX. Uses system sounds by default; replace with custom assets via AVFoundation when desired.
enum GameplaySoundService {
    private static let soundPerfect: SystemSoundID = 1057   // tap
    private static let soundGood: SystemSoundID = 1104     // keyboard tap
    private static let soundMiss: SystemSoundID = 1005     // sent message / subtle
    private static let soundVictory: SystemSoundID = 1025 // new mail / positive
    private static let soundDefeat: SystemSoundID = 1005  // subtle

    static func playCommit(quality: CommitFeedbackQuality) {
        switch quality {
        case .perfect: AudioServicesPlaySystemSound(soundPerfect)
        case .good: AudioServicesPlaySystemSound(soundGood)
        case .miss: AudioServicesPlaySystemSound(soundMiss)
        }
    }

    static func playRoundEnd(won: Bool) {
        _ = won
        // Optional: light tap on round end
    }

    static func playVictory() {
        AudioServicesPlaySystemSound(soundVictory)
    }

    static func playDefeat() {
        AudioServicesPlaySystemSound(soundDefeat)
    }

    enum CommitFeedbackQuality {
        case perfect, good, miss
    }
}
