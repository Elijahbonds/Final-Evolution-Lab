import Foundation

/// Reads `FELArenaModesPrecache` from Info.plist (comma-separated `GameModeId`s) for launch-time warm paths.
/// Pair with Unreal `UFELArenaPreloadSubsystem` + `DefaultEngine.ini` Bonds Bounce block.
enum ArenaLaunchPrecache {
    static func runAtLaunch() {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "FELArenaModesPrecache") as? String,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }
        let modes = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !modes.isEmpty else { return }
        // Unity / native asset pipelines can subscribe here; UFELArenaPreloadSubsystem covers Unreal data assets.
        PRQNativeBridge.postMetrics(["arenaPrecacheModeCount": modes.count])
    }
}
