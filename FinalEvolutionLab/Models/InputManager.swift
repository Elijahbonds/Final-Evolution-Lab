import Foundation

nonisolated struct InputManager: Sendable {
    static let ps2PollIntervalMs: Double = 17
    static let inputLatencyMs: Double = 28
    static let deadzoneRadius: Double = 0.08
    static let deadzoneInner: Double = 0.06

    static func applyDeadzone(_ value: Double, inner: Double = deadzoneInner, outer: Double = 1.0) -> Double {
        let v = max(0, min(outer, value))
        if v <= inner { return 0 }
        return (v - inner) / (outer - inner)
    }

    static func getAnalogStick(x: Double, y: Double, inner: Double = deadzoneInner) -> (x: Double, y: Double, magnitude: Double) {
        let mag = hypot(x, y)
        if mag <= inner { return (0, 0, 0) }
        let rescale = (mag - inner) / (1 - inner)
        let scale = rescale / mag
        return (x * scale, y * scale, min(1, rescale))
    }
}

nonisolated struct PS2MovementConfig: Sendable {
    let topSpeed: Float
    let acceleration: Float
    let deceleration: Float
    let airControl: Float
    let baseJump: Float
    let chargedJump: Float
    let cameraLerpFactor: Float
    let cameraTargetLerpFactor: Float

    static let standard = PS2MovementConfig(
        topSpeed: 8.5,
        acceleration: 12,
        deceleration: 28,
        airControl: 0.22,
        baseJump: 7.2,
        chargedJump: 13.2,
        cameraLerpFactor: 8,
        cameraTargetLerpFactor: 10
    )

    static func forMode(_ mode: GameModeId) -> PS2MovementConfig {
        switch mode {
        case .basketballHeadToHead, .basketballDunkContest, .basketball3v3:
            return .standard
        case .karate:
            return PS2MovementConfig(
                topSpeed: 7.0,
                acceleration: 14,
                deceleration: 32,
                airControl: 0.18,
                baseJump: 5.5,
                chargedJump: 9.0,
                cameraLerpFactor: 10,
                cameraTargetLerpFactor: 12
            )
        case .volleyball:
            return PS2MovementConfig(
                topSpeed: 6.5,
                acceleration: 11,
                deceleration: 26,
                airControl: 0.20,
                baseJump: 8.0,
                chargedJump: 14.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        case .football:
            return PS2MovementConfig(
                topSpeed: 9.5,
                acceleration: 10,
                deceleration: 20,
                airControl: 0.15,
                baseJump: 4.0,
                chargedJump: 7.0,
                cameraLerpFactor: 7,
                cameraTargetLerpFactor: 9
            )
        case .soccer:
            return PS2MovementConfig(
                topSpeed: 8.0,
                acceleration: 12,
                deceleration: 28,
                airControl: 0.20,
                baseJump: 5.0,
                chargedJump: 8.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        default:
            return PS2MovementConfig(
                topSpeed: 7.0,
                acceleration: 11,
                deceleration: 25,
                airControl: 0.20,
                baseJump: 5.0,
                chargedJump: 9.0,
                cameraLerpFactor: 8,
                cameraTargetLerpFactor: 10
            )
        }
    }
}
