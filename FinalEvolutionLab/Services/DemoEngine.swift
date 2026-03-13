import SwiftUI
import Foundation

nonisolated enum DemoMode: String, Sendable, CaseIterable {
    case coach = "Coach"
    case avatar = "Avatar"
}

nonisolated enum DemoLoadState: Sendable {
    case idle
    case loading
    case ready(DemoContentPayload)
    case needsRealClip
}

nonisolated enum DemoContentPayload: Sendable {
    case generatedAnimation(ExerciseDemoAsset)
    case localClip(ExerciseDemoAsset, URL)
    case referenceOnly(ExerciseDemoAsset)
}

@Observable
@MainActor
class DemoEngine {
    var currentMode: DemoMode = .coach
    var loadState: DemoLoadState = .idle
    var isTransitioning: Bool = false

    func loadDemo(for exerciseId: String, movementDatabase: MovementDatabase) {
        loadState = .loading

        // Priority: generated animation > local clip > request real clip.
        if let generated = movementDatabase.asset(for: exerciseId, sourceType: .generatedAnimation) {
            loadState = .ready(.generatedAnimation(generated))
            return
        }

        if let local = movementDatabase.asset(for: exerciseId, sourceType: .localClip),
           let clipFile = local.localClipFilename,
           let clipURL = resolveLocalClipURL(filename: clipFile) {
            loadState = .ready(.localClip(local, clipURL))
            return
        }

        if let referenceOnly = movementDatabase.asset(for: exerciseId, sourceType: .referenceOnly) {
            loadState = .ready(.referenceOnly(referenceOnly))
            currentMode = .avatar
            return
        }

        loadState = .needsRealClip
        currentMode = .avatar
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

    var isCoachDemoAvailable: Bool {
        guard case .ready(let payload) = loadState else { return false }
        switch payload {
        case .generatedAnimation, .localClip:
            return true
        case .referenceOnly:
            return false
        }
    }

    var isReferenceOnly: Bool {
        guard case .ready(let payload) = loadState else { return false }
        if case .referenceOnly = payload { return true }
        return false
    }

    var shouldShowRequestRealClip: Bool {
        if case .needsRealClip = loadState { return true }
        return isReferenceOnly
    }

    var activeAsset: ExerciseDemoAsset? {
        guard case .ready(let payload) = loadState else { return nil }
        switch payload {
        case .generatedAnimation(let asset), .localClip(let asset, _), .referenceOnly(let asset):
            return asset
        }
    }

    var qualityPercentText: String {
        guard let asset = activeAsset else { return "--" }
        return "\(Int((max(0, min(1, asset.qualityScore))) * 100))%"
    }

    var sourceBadgeText: String {
        guard let asset = activeAsset else {
            if case .needsRealClip = loadState { return "REAL CLIP NEEDED" }
            return "RESOLVING"
        }
        switch asset.sourceType {
        case .generatedAnimation:
            return "DIGITAL CLONE DEMO"
        case .localClip:
            return "LOCAL REAL CLIP"
        case .referenceOnly:
            return "REFERENCE PROCESSING"
        }
    }

    private func resolveLocalClipURL(filename: String) -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let documents, FileManager.default.fileExists(atPath: documents.appendingPathComponent(filename).path) {
            return documents.appendingPathComponent(filename)
        }

        let ns = filename as NSString
        let name = ns.deletingPathExtension
        let ext = ns.pathExtension
        if !name.isEmpty, !ext.isEmpty {
            return Bundle.main.url(forResource: name, withExtension: ext)
        }
        return nil
    }
}
