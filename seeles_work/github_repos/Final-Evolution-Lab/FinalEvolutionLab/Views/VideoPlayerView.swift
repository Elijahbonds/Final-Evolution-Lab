import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true)
            } else {
                ProgressView()
                    .tint(Theme.brandBlue)
            }
        }
        .onAppear {
            let avPlayer = AVPlayer(url: url)
            avPlayer.isMuted = false
            avPlayer.play()
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }
            player = avPlayer
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
