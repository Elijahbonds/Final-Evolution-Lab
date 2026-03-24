import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var endObserver: NSObjectProtocol?

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
            endObserver = NotificationCenter.default.addObserver(
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
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
                self.endObserver = nil
            }
            player?.pause()
            player = nil
        }
    }
}
