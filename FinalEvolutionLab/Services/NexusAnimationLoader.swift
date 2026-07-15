import Foundation
import SceneKit

/// Loads bundled NexusAnimationAsset keyframe files from the app bundle.
///
/// The `.nexusanim.json` files in `FinalEvolutionLab/Resources/Animations/` are the
/// runtime-usable version of the Seeles/DeepMotion FBX animations. They contain
/// joint quaternion keyframes in the format expected by `NexusMoCapRetargeter`.
///
/// Usage:
///   ```swift
///   let dunk = NexusAnimationLoader.shared.load("anim_basketball_dunk")
///   let pose  = NexusAnimationLoader.shared.samplePose(dunk, at: 0.65)
///   ```
public final class NexusAnimationLoader {

    public static let shared = NexusAnimationLoader()

    private var cache: [String: NexusAnimationAsset] = [:]
    private let queue = DispatchQueue(label: "com.nexus.animloader", attributes: .concurrent)

    private init() {}

    // MARK: - Load

    /// Synchronously loads an animation by id. Returns nil if the file is not found.
    /// Results are cached in memory after the first load.
    public func load(_ animationId: String) -> NexusAnimationAsset? {
        // Fast cache read
        var cached: NexusAnimationAsset?
        queue.sync { cached = cache[animationId] }
        if let cached { return cached }

        guard let url = Bundle.main.url(
            forResource: animationId,
            withExtension: "nexusanim.json",
            subdirectory: "Animations"
        ) else {
            // Fallback: flat resource lookup without subdirectory
            guard let flat = Bundle.main.url(forResource: animationId, withExtension: "nexusanim.json") else {
                return nil
            }
            return loadAndCache(from: flat, id: animationId)
        }
        return loadAndCache(from: url, id: animationId)
    }

    /// Asynchronously loads an animation, delivering on the main queue.
    public func loadAsync(_ animationId: String, completion: @escaping (NexusAnimationAsset?) -> Void) {
        queue.async { [weak self] in
            let asset = self?.load(animationId)
            DispatchQueue.main.async { completion(asset) }
        }
    }

    /// Pre-warms the cache with all known animation ids.
    public func preloadAll() {
        for id in NexusAnimationLoader.knownAnimationIds {
            queue.async(flags: .barrier) { [weak self] in
                _ = self?.load(id)
            }
        }
    }

    // MARK: - Sampling

    /// Returns interpolated joint rotations for a given playback time (in seconds).
    /// Time is clamped to [0, duration]. Returns the last frame if t >= duration.
    public func samplePose(
        _ asset: NexusAnimationAsset,
        at time: Double
    ) -> [String: SCNQuaternion] {
        let frames = asset.keyframes
        guard !frames.isEmpty else { return [:] }

        let clampedTime = max(0, min(time, asset.header.duration))

        // Binary search for surrounding keyframes
        var lo = 0; var hi = frames.count - 1
        while lo < hi - 1 {
            let mid = (lo + hi) / 2
            if frames[mid].timestamp <= clampedTime { lo = mid } else { hi = mid }
        }

        let f0 = frames[lo]
        if lo >= frames.count - 1 { return f0.jointRotations }
        let f1 = frames[hi]
        let dt = f1.timestamp - f0.timestamp
        let t  = dt < 1e-6 ? 0.0 : (clampedTime - f0.timestamp) / dt

        return interpolate(f0.jointRotations, f1.jointRotations, t: t)
    }

    /// Samples a looping animation (time wraps at duration).
    public func sampleLooping(
        _ asset: NexusAnimationAsset,
        at time: Double
    ) -> [String: SCNQuaternion] {
        let dur = asset.header.duration
        guard dur > 0 else { return [:] }
        let wrapped = time.truncatingRemainder(dividingBy: dur)
        return samplePose(asset, at: wrapped)
    }

    // MARK: - Apply to Mannequin

    /// Samples the animation at `time` and applies rotations to the named bone nodes in `root`.
    public func apply(
        _ asset: NexusAnimationAsset,
        at time: Double,
        looping: Bool = false,
        to root: SCNNode,
        retargeter: NexusMoCapRetargeter? = nil
    ) {
        let pose = looping ? sampleLooping(asset, at: time) : samplePose(asset, at: time)
        for (boneName, quat) in pose {
            let node = NexusMoCapRetargeter.findNode(named: boneName, in: root)
            node?.orientation = quat
        }
    }

    // MARK: - Private Helpers

    private func loadAndCache(from url: URL, id: String) -> NexusAnimationAsset? {
        guard let data = try? Data(contentsOf: url),
              let asset = try? NexusAnimationAsset.decode(from: data) else { return nil }
        queue.async(flags: .barrier) { [weak self] in
            self?.cache[id] = asset
        }
        return asset
    }

    private func interpolate(
        _ a: [String: SCNVector4],
        _ b: [String: SCNVector4],
        t: Double
    ) -> [String: SCNQuaternion] {
        var result: [String: SCNQuaternion] = [:]
        let allKeys = Set(a.keys).union(b.keys)
        for key in allKeys {
            let qa = a[key] ?? SCNVector4(0, 0, 0, 1)
            let qb = b[key] ?? SCNVector4(0, 0, 0, 1)
            result[key] = slerp(qa, qb, Float(t))
        }
        return result
    }

    private func slerp(_ a: SCNVector4, _ b: SCNVector4, _ t: Float) -> SCNQuaternion {
        var dot = a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w
        var bx = b.x, by = b.y, bz = b.z, bw = b.w
        if dot < 0 { bx = -bx; by = -by; bz = -bz; bw = -bw; dot = -dot }
        if dot > 0.9995 {
            let rx = a.x + (bx - a.x) * t
            let ry = a.y + (by - a.y) * t
            let rz = a.z + (bz - a.z) * t
            let rw = a.w + (bw - a.w) * t
            let m = sqrt(rx*rx+ry*ry+rz*rz+rw*rw)
            return SCNQuaternion(rx/m, ry/m, rz/m, rw/m)
        }
        let th0 = acos(dot)
        let th  = th0 * t
        let sth  = sin(th); let sth0 = sin(th0)
        let s1 = cos(th) - dot * sth / sth0
        let s2 = sth / sth0
        return SCNQuaternion(
            s1*a.x + s2*bx,
            s1*a.y + s2*by,
            s1*a.z + s2*bz,
            s1*a.w + s2*bw
        )
    }

    // MARK: - Known IDs

    public static let knownAnimationIds: [String] = [
        "anim_basketball_dunk",
        "anim_basketball_dribble_run",
        "anim_basketball_defensive_idle",
        "anim_basketball_jump_shot",
        "anim_sprint_run_loop",
        "anim_standing_idle",
        "anim_victory_celebration",
        "anim_karate_punch_kick_combo",
        "anim_karate_idle_stance",
        "anim_volleyball_spike",
        "anim_soccer_kick_shot",
        "anim_soccer_jog_loop",
        "anim_football_throw_pass",
        "anim_baseball_bat_swing",
        "anim_golf_swing",
        "anim_gymnastics_cartwheel",
        "anim_skateboard_ollie",
        "anim_snowboard_carve_loop",
        "anim_surf_ride_loop",
        "anim_defeat_knockdown",
        "anim_brain_brawl_thinking_loop",
    ]

    /// Maps a Seeles animation id to its local bundle file id (same key, kept for clarity).
    public static let seelesToBundleId: [String: String] = Dictionary(
        uniqueKeysWithValues: knownAnimationIds.map { ($0, $0) }
    )
}
