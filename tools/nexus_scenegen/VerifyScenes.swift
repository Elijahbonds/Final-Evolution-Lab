import Foundation

// Drives the REAL NexusSceneLoader against the REAL descriptors. This is the
// check that would have caught the original bug: the descriptor that shipped
// looked plausible, parsed as JSON, and could not decode into NexusScene.
// JSON-parses is not the same as loads.

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
guard let bundle = Bundle(path: dir) else {
    print("FAIL: no bundle at \(dir)"); exit(1)
}

var bundled = 0, failed: [String] = []
for mode in GameModeId.allCases {
    let r = NexusSceneLoader.load(mode, prq: 72, bundle: bundle)
    switch r.outcome {
    case .bundled:
        // sanity-check the loaded content, not just that it decoded
        guard r.scene.gameModeId == mode else { failed.append("\(mode.rawValue): wrong gameModeId"); continue }
        guard !r.scene.entities.isEmpty else { failed.append("\(mode.rawValue): no entities"); continue }
        guard r.scene.entities.contains(where: { $0.isCamera }) else {
            failed.append("\(mode.rawValue): no camera entity"); continue }
        // PRQ must be applied at load, not baked in
        guard r.scene.physicsConfig.prqSpeedMultiplier > 1.0 else {
            failed.append("\(mode.rawValue): PRQ not applied"); continue }
        bundled += 1
    case .fallbackMissing, .fallbackInvalid:
        failed.append("\(mode.rawValue): \(r.detail ?? "fallback")")
    }
}

print("loaded from descriptor: \(bundled)/\(GameModeId.allCases.count)")
for f in failed { print("  FAIL \(f)") }
exit(failed.isEmpty ? 0 : 1)
