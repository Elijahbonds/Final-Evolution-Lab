import Foundation

/// Camera follow + playable bounds aligned with `ArenaSceneConfig` court sizes (Phase 5).
enum ArenaSceneMovementConfig {

    struct CameraFollow: Sendable {
        let offsetX: Float
        let offsetY: Float
        let offsetZ: Float
        let lookAtY: Float
        let followSpeed: Float
        let targetSpeed: Float
        let fovNormal: CGFloat
        let fovAction: CGFloat
    }

    struct MovementBounds: Sendable {
        let minX: Float
        let maxX: Float
        let minZ: Float
        let maxZ: Float
        let baseSpeed: Float
    }

    private static let margin: Float = 0.22

    static func cameraFollow(for mode: GameModeId) -> CameraFollow {
        switch mode {
        case .basketballHeadToHead:
            let h = ArenaSceneConfig.BasketballH2H.self
            return CameraFollow(
                offsetX: 2.4, offsetY: 5.4, offsetZ: 9.2, lookAtY: 1.25,
                followSpeed: 5.2, targetSpeed: 7.2, fovNormal: 46, fovAction: 36
            )
        case .basketballDunkContest:
            return CameraFollow(
                offsetX: 2.0, offsetY: 6.0, offsetZ: 10.5, lookAtY: 2.05,
                followSpeed: 6.2, targetSpeed: 8.5, fovNormal: 45, fovAction: 34
            )
        case .basketball3v3:
            return CameraFollow(
                offsetX: 2.6, offsetY: 5.6, offsetZ: 9.8, lookAtY: 1.2,
                followSpeed: 5.0, targetSpeed: 7.0, fovNormal: 46, fovAction: 36
            )
        case .karate1v1, .karateEndless:
            return CameraFollow(offsetX: 0, offsetY: 3.6, offsetZ: 6.2, lookAtY: 1.2, followSpeed: 7.5, targetSpeed: 9.5, fovNormal: 48, fovAction: 36)
        case .football:
            return CameraFollow(offsetX: 0.5, offsetY: 6.5, offsetZ: 9.5, lookAtY: 1.05, followSpeed: 5.2, targetSpeed: 6.5, fovNormal: 52, fovAction: 42)
        case .soccer:
            return CameraFollow(offsetX: 1.2, offsetY: 4.2, offsetZ: 7.5, lookAtY: 0.85, followSpeed: 5.2, targetSpeed: 7.2, fovNormal: 50, fovAction: 40)
        case .baseball:
            return CameraFollow(offsetX: -2.2, offsetY: 3.8, offsetZ: 6.5, lookAtY: 1.45, followSpeed: 4.2, targetSpeed: 6.2, fovNormal: 48, fovAction: 38)
        case .golf:
            return CameraFollow(offsetX: 2.2, offsetY: 3.2, offsetZ: 7.5, lookAtY: 1.0, followSpeed: 3.2, targetSpeed: 5.0, fovNormal: 46, fovAction: 36)
        case .tennis:
            return CameraFollow(offsetX: 0, offsetY: 5.2, offsetZ: 9.5, lookAtY: 1.05, followSpeed: 5.2, targetSpeed: 7.2, fovNormal: 50, fovAction: 40)
        case .volleyball:
            return CameraFollow(offsetX: 0, offsetY: 5.2, offsetZ: 8.8, lookAtY: 1.45, followSpeed: 5.2, targetSpeed: 7.0, fovNormal: 48, fovAction: 38)
        case .gymnastics:
            return CameraFollow(offsetX: 1.2, offsetY: 4.2, offsetZ: 8.5, lookAtY: 1.45, followSpeed: 4.2, targetSpeed: 6.2, fovNormal: 48, fovAction: 36)
        }
    }

    static func movementBounds(for mode: GameModeId) -> MovementBounds {
        switch mode {
        case .basketballHeadToHead:
            let h = ArenaSceneConfig.BasketballH2H.self
            return MovementBounds(
                minX: -h.halfW + margin, maxX: h.halfW - margin,
                minZ: -h.halfD + margin, maxZ: h.halfD - margin,
                baseSpeed: 0.13
            )
        case .basketballDunkContest:
            let d = ArenaSceneConfig.BasketballDunk.self
            return MovementBounds(
                minX: -d.halfW + margin, maxX: d.halfW - margin,
                minZ: -d.halfD + margin, maxZ: d.halfD - margin,
                baseSpeed: 0.145
            )
        case .basketball3v3:
            let v = ArenaSceneConfig.Basketball3v3.self
            return MovementBounds(
                minX: -v.halfW + margin, maxX: v.halfW - margin,
                minZ: -v.halfD + margin, maxZ: v.halfD - margin,
                baseSpeed: 0.125
            )
        case .karate1v1, .karateEndless:
            return MovementBounds(minX: -2.35, maxX: 2.35, minZ: -2.35, maxZ: 2.35, baseSpeed: 0.11)
        case .football:
            return MovementBounds(minX: -4.5, maxX: 4.5, minZ: -12.0, maxZ: 12.0, baseSpeed: 0.17)
        case .soccer:
            return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, baseSpeed: 0.09)
        case .baseball:
            return MovementBounds(minX: -1.0, maxX: 1.0, minZ: -0.5, maxZ: 0.5, baseSpeed: 0.045)
        case .golf:
            return MovementBounds(minX: -1.0, maxX: 1.0, minZ: -0.5, maxZ: 0.5, baseSpeed: 0.035)
        case .tennis:
            return MovementBounds(minX: -3.2, maxX: 3.2, minZ: -2.2, maxZ: 2.2, baseSpeed: 0.105)
        case .volleyball:
            return MovementBounds(minX: -3.2, maxX: 3.2, minZ: -1.6, maxZ: 1.6, baseSpeed: 0.095)
        case .gymnastics:
            return MovementBounds(minX: -3.2, maxX: 3.2, minZ: -2.2, maxZ: 2.2, baseSpeed: 0.085)
        }
    }
}
