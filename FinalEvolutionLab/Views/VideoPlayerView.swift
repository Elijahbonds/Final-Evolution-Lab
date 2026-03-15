import SwiftUI
import AVKit

// MARK: - Demo video playback.
// Cross-platform: Console/UE5 can supply 4K assets; mobile may prefer 1080p (add URL variant in DemoEngine.videoMap when needed). If isPlayable fails at runtime (codec/device), onPlaybackFailed lets DemoEngine fall back to Avatar without interrupting the workout.
struct VideoPlayerView: View {
    let url: URL
    /// Called when playback fails at runtime (e.g. codec unsupported). DemoEngine.reportPlaybackFailed() keeps avatar as universal fallback.
    var onPlaybackFailed: (() -> Void)?

    @State private var player: AVPlayer?
    @State private var endTimeObserver: (any NSObjectProtocol)?
    @State private var statusObserver: NSKeyValueObservation<AVPlayerItem, AVPlayerItem.Status>?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true) // Keep playback in-app; prevent fullscreen takeover and seek during loops
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(Theme.brandBlue)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            let avPlayer = AVPlayer(url: url)
            avPlayer.isMuted = true
            avPlayer.play()
            let item = avPlayer.currentItem
            let loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }
            endTimeObserver = loopObserver
            statusObserver = item?.observe(\.status, options: [.new]) { playerItem, _ in
                guard playerItem.status == .failed else { return }
                Task { @MainActor in
                    onPlaybackFailed?()
                }
            }
            player = avPlayer
        }
        .onDisappear {
            if let endTimeObserver {
                NotificationCenter.default.removeObserver(endTimeObserver)
                self.endTimeObserver = nil
            }
            statusObserver = nil
            player?.pause()
            player = nil
        }
    }
}
