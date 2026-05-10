import Foundation

#if DEBUG
/// Supplemental QA hooks (FPS / bridge latency). Extend with CADisplayLink or signposts when profiling builds.
enum DebugQualityMetrics {
    static func logEvent(_ name: String, metadata: [String: String] = [:]) {
        let suffix = metadata.isEmpty ? "" : " \(metadata)"
        print("[QualityMetrics] \(name)\(suffix)")
    }
}
#endif
