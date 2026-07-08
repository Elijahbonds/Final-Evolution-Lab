import SwiftUI
import AVFoundation

nonisolated enum DemoMode: String, Sendable, CaseIterable {
    /// Primary: skinned 3D demonstrator model performing the exercise.
    case model3D = "3D Model"
    case coach = "Coach"
    /// 2D stick-figure fallback (also the ultimate fail-soft if 3D can't render).
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
    var currentMode: DemoMode = .model3D
    var videoLoadState: VideoLoadState = .idle
    var isTransitioning: Bool = false
    /// Set by ``ExerciseDemo3DView`` when the 3D skinned demo cannot render, so
    /// the view can fall back to the 2D avatar without changing the user's mode.
    var demo3DFailed: Bool = false

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

        guard let urlString = Self.videoMap[exerciseId],
              let url = URL(string: urlString) else {
            videoLoadState = .failed
            // 3D model demo is the primary experience; only the Coach tab is
            // gated on a video being available, so no mode change is needed.
            return
        }

        Task {
            let asset = AVURLAsset(url: url)
            do {
                let isPlayable = try await asset.load(.isPlayable)
                if isPlayable {
                    videoLoadState = .ready(url)
                } else {
                    videoLoadState = .failed
                }
            } catch {
                videoLoadState = .failed
            }
        }
    }

    /// Switch to a specific demo mode with the neural-scan transition sweep.
    func setMode(_ mode: DemoMode) {
        guard mode != currentMode else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            isTransitioning = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMode = mode
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
