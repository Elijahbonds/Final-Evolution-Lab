import SwiftUI
import AVFoundation

nonisolated enum DemoMode: String, Sendable, CaseIterable {
    case coach = "Coach"
    case avatar = "Avatar"
}

nonisolated enum VideoLoadState: Sendable {
    case idle
    case loading
    case ready(URL)
    case failed
}

@Observable
@MainActor
class DemoEngine {
    var currentMode: DemoMode = .coach
    var videoLoadState: VideoLoadState = .idle
    var isTransitioning: Bool = false

    private static let videoMap: [String: String] = [
        "f1": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#ScaledPogos",
        "f2": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#BoxJumps",
        "f3": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#SplitSquats",
        "f4": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#AnkleMobility",
        "f5": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#LateralShuffles",
        "fl1": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#DepthJumps",
        "fl2": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#LateralLeaps",
        "fl3": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#BulgarianSplitSquats",
        "fl4": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#HipFlexor",
        "fl5": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#ConeAgility",
        "e1": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#DunkSessions",
        "e2": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#WeightedDepthJumps",
        "e3": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#TrapBarDeadlifts",
        "e4": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#NeuralDriveSprint",
        "e5": "https://share.icloud.com/photos/0c16kro59r04sOvqojl-LJswQ#RecoveryProtocol",
    ]

    func loadVideo(for exerciseId: String) {
        videoLoadState = .loading

        let url: URL? = {
            if let bundled = Bundle.main.url(forResource: exerciseId, withExtension: "mp4") {
                return bundled
            }
            if let urlString = Self.videoMap[exerciseId], let u = URL(string: urlString), u.scheme == "file" {
                return u
            }
            if let urlString = Self.videoMap[exerciseId], let u = URL(string: urlString) {
                return u
            }
            return nil
        }()

        guard let videoURL = url else {
            videoLoadState = .failed
            currentMode = .avatar
            return
        }

        Task {
            let asset = AVURLAsset(url: videoURL)
            do {
                let isPlayable = try await asset.load(.isPlayable)
                if isPlayable {
                    videoLoadState = .ready(videoURL)
                } else {
                    videoLoadState = .failed
                    currentMode = .avatar
                }
            } catch {
                videoLoadState = .failed
                currentMode = .avatar
            }
        }
    }

    func toggleMode() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isTransitioning = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMode = currentMode == .coach ? .avatar : .coach
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeOut(duration: 0.3)) {
                isTransitioning = false
            }
        }
    }

    var isVideoAvailable: Bool {
        if case .ready = videoLoadState { return true }
        return false
    }
}
