import Foundation

/// Unified NEXUS 3D gameplay contract — Metal venue backdrop + SceneKit player rig + chase camera.
enum Nexus3DGameplayCoordinator {
    /// Active when `NEXUS_3D_GAMEPLAY=1`, or emulator shell is on (default for cartridge library).
    static var isEnabled: Bool { Config.useNexus3DGameplay }

    /// Hybrid Metal venue + transparent SceneKit overlay when bundled mesh resolves for the mode.
    static func shouldUseHybridMetal(for gameMode: GameModeId, explicit3D: Bool) -> Bool {
        guard explicit3D || GameSceneHostView.prefersMetalRenderer(for: gameMode) else {
            return false
        }
        guard nexus_metal_bridge_is_linked() else { return false }
        return gameMode.nexusRuntimeModeId.withCString { modeCStr in
            nexus_metal_bridge_bundled_venue_mesh_loadable(modeCStr)
        }
    }

    /// SceneKit-only 3D path (player rig + chase camera) when hybrid Metal is unavailable.
    static func usesSceneKitGameplay(for gameMode: GameModeId, explicit3D: Bool) -> Bool {
        explicit3D || !shouldUseHybridMetal(for: gameMode, explicit3D: explicit3D)
    }
}
