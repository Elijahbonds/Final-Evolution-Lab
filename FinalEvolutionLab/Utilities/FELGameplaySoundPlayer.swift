import AVFoundation

/// Placeholder SFX — silent no-op when bundled assets are absent.
@MainActor
enum FELGameplaySoundPlayer {
    private static var apexPlayer: AVAudioPlayer?
    private static var swishPlayer: AVAudioPlayer?

    static func prepare() {
        apexPlayer = load(named: "fel_apex_tap", ext: "wav") ?? load(named: "fel_apex_tap", ext: "mp3")
        swishPlayer = load(named: "fel_swish", ext: "wav") ?? load(named: "fel_swish", ext: "mp3")
    }

    static func playApex() {
        play(apexPlayer)
    }

    static func playSwish() {
        play(swishPlayer)
    }

    private static func load(named: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: named, withExtension: ext) else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }

    private static func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
        player.currentTime = 0
        player.play()
    }
}
