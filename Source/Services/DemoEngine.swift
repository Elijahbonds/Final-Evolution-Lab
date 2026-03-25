import SwiftUI
import AVFoundation

// MARK: - DemoEngine (UE5 / Console sync)
// Single source of truth for Coach (video) vs Avatar (skeletal/3D). When loading or failed, UI must show Avatar path (ExerciseCharacterView / AvatarDemoView or UE high-fidelity skeletal model). Do not remove fallback animations for plyometric, strength, mobility, agility, recovery — they are the universal hardware.

nonisolated enum DemoMode: String, Sendable, CaseIterable {
    case coach = "Coach"
    case avatar = "Avatar"
}

nonisolated enum VideoLoadState: Sendable, Equatable {
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

    /// Canonical video keys (SampleData / blueprint style): f1–f5, fl1–fl5, e1–e5.
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

    /// Resolve video key for any exercise id (program ids like f_w1, f_d1a_1 → canonical f1, fl1, e1).
    /// Safe for empty or arbitrary strings; returns nil when no mapping exists.
    private static func videoKey(for exerciseId: String) -> String? {
        let trimmed = exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if Self.videoMap[trimmed] != nil { return trimmed }
        if trimmed.hasPrefix("fl") { return "fl1" }
        if trimmed.hasPrefix("e")  { return "e1" }
        if trimmed.hasPrefix("f")  { return "f1" }
        return nil
    }

    /// Load video for the given exercise id. Updates videoLoadState and currentMode; @Observable propagates to all SwiftUI subscribers (TrainingExerciseDetailView, ExerciseDemoView). Resets to .avatar at start so high-end UE fallback stays in sync.
    func loadVideo(for exerciseId: String) {
        videoLoadState = .loading
        currentMode = .avatar

        let url: URL? = {
            let id = exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
            if !id.isEmpty, let bundled = Bundle.main.url(forResource: id, withExtension: "mp4") {
                return bundled
            }
            let key = Self.videoKey(for: exerciseId)
            guard let key else { return nil as URL? }
            guard let urlString = Self.videoMap[key] else { return nil as URL? }
            guard let u = URL(string: urlString) else { return nil as URL? }
            if u.scheme == "file" { return u }
            return u
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

    /// Call when VideoPlayerView reports runtime playback failure (e.g. codec unsupported on device). Keeps UE/avatar fallback as single source of truth without interrupting workout.
    func reportPlaybackFailed() {
        videoLoadState = .failed
        currentMode = .avatar
    }
}

