import Foundation
import OSLog

// MARK: - Animation library
//
// Loads bundled `.nexusanim.json` keyframe assets (assets/nexus/animations/)
// into `NexusAnimationAsset` for the existing keyframe player
// (CourtSceneView.playKeyframeAnimation and any avatar scene). Assets come
// from three interchangeable sources in the same format:
//   1. scripts/assets/mocap/bvh_to_nexus_animation.py — DeepMotion/Rokoko/
//      Plask BVH (AI-generated or real video → motion capture)
//   2. In-app Vision capture retargeted via NexusMoCapRetargeter
//   3. scripts/assets/mocap/generate_starter_animations.py — procedural
//      placeholders that mocap assets replace 1:1.

@MainActor
enum NexusAnimationLibrary {
    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "NexusAnimationLibrary"
    )

    private static var cache: [String: NexusAnimationAsset] = [:]
    private static var indexed = false
    private static var byId: [String: URL] = [:]

    /// All bundled animation asset ids, indexed lazily.
    static func availableIds() -> [String] {
        buildIndexIfNeeded()
        return byId.keys.sorted()
    }

    /// Load (and cache) an asset by header id, e.g. "starter_dunk_windmill".
    static func asset(id: String) -> NexusAnimationAsset? {
        buildIndexIfNeeded()
        if let cached = cache[id] { return cached }
        guard let url = byId[id],
              let data = try? Data(contentsOf: url),
              let asset = try? JSONDecoder().decode(NexusAnimationAsset.self, from: data) else {
            log.error("animation asset failed to load: \(id, privacy: .public)")
            return nil
        }
        cache[id] = asset
        return asset
    }

    /// Assets for a category ("dunk", "locomotion", "reaction").
    static func assets(category: String) -> [NexusAnimationAsset] {
        availableIds().compactMap { asset(id: $0) }.filter { $0.header.category == category }
    }

    private static func buildIndexIfNeeded() {
        guard !indexed else { return }
        indexed = true
        let urls = Bundle.main.urls(forResourcesWithExtension: "json",
                                    subdirectory: "assets/nexus/animations") ?? []
        for url in urls where url.lastPathComponent.hasSuffix(".nexusanim.json") {
            // Index by filename stem (== header.id by pipeline convention);
            // full decode happens on first use.
            let stem = url.lastPathComponent.replacingOccurrences(of: ".nexusanim.json", with: "")
            byId[stem] = url
        }
        log.info("indexed \(byId.count) bundled animation assets")
    }
}
