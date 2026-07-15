import Foundation

nonisolated enum AvatarPoseState: String, Sendable {
    case idle
    case sprint
    case gather
    case dunk
    case shoot
    case jump
    case land
    case block
    case counter
    case vanish
    case hitStun
    case special
    case swing
    case kick
    case spike
    case serve
    case catch_ball
    case celebrate
}

nonisolated struct AvatarStateMachine: Sendable {
    static let blendTimeSeconds: Double = 0.2
    static let hitStopFrames: Int = 3
    static let hitStopDuration: Double = Double(hitStopFrames) / 60.0

    let currentState: AvatarPoseState
    let previousState: AvatarPoseState
    let transitionStartTime: Double

    init() {
        self.currentState = .idle
        self.previousState = .idle
        self.transitionStartTime = 0
    }

    private init(currentState: AvatarPoseState, previousState: AvatarPoseState, transitionStartTime: Double) {
        self.currentState = currentState
        self.previousState = previousState
        self.transitionStartTime = transitionStartTime
    }

    func transitioning(to next: AvatarPoseState, at time: Double) -> AvatarStateMachine {
        if next == currentState { return self }
        return AvatarStateMachine(
            currentState: next,
            previousState: currentState,
            transitionStartTime: time
        )
    }

    func blendFactor(at currentTime: Double) -> Double {
        let elapsed = currentTime - transitionStartTime
        return min(1.0, elapsed / Self.blendTimeSeconds)
    }

    var isAttacking: Bool {
        switch currentState {
        case .dunk, .shoot, .special: return true
        default: return false
        }
    }

    var isDefending: Bool {
        switch currentState {
        case .block, .counter, .vanish: return true
        default: return false
        }
    }

    var canTransitionTo: Set<AvatarPoseState> {
        switch currentState {
        case .idle: return [.sprint, .gather, .jump, .shoot, .block, .special, .swing, .kick, .spike, .serve, .catch_ball]
        case .sprint: return [.idle, .gather, .jump, .block, .catch_ball]
        case .gather: return [.jump, .dunk, .idle]
        case .jump: return [.dunk, .shoot, .land, .idle, .spike]
        case .dunk: return [.land, .idle, .celebrate]
        case .shoot: return [.idle, .land]
        case .land: return [.idle, .sprint, .gather, .celebrate]
        case .block: return [.idle, .counter, .vanish, .hitStun]
        case .counter: return [.idle, .special]
        case .vanish: return [.idle, .counter, .special]
        case .hitStun: return [.idle]
        case .special: return [.idle, .land, .celebrate]
        case .swing: return [.idle, .celebrate]
        case .kick: return [.idle, .celebrate]
        case .spike: return [.idle, .land, .celebrate]
        case .serve: return [.idle]
        case .catch_ball: return [.idle, .sprint]
        case .celebrate: return [.idle]
        }
    }

    static func poseRotationX(for state: AvatarPoseState) -> Float {
        switch state {
        case .idle: return 0
        case .sprint: return -0.1
        case .gather: return 0.15
        case .dunk: return 0.35
        case .shoot: return -0.2
        case .jump: return 0
        case .land: return 0.1
        case .block: return -0.15
        case .counter: return 0.25
        case .vanish: return 0
        case .hitStun: return -0.3
        case .special: return 0.4
        case .swing: return 0.3
        case .kick: return -0.25
        case .spike: return 0.4
        case .serve: return -0.15
        case .catch_ball: return 0.05
        case .celebrate: return -0.1
        }
    }

    static func poseScale(for state: AvatarPoseState, heightScale: Float = 1.0, weightScale: Float = 1.0) -> (x: Float, y: Float, z: Float) {
        let h = heightScale
        let w = weightScale
        switch state {
        case .idle:
            return (w, h, w)
        case .sprint:
            return (w * 0.97, h * 1.03, w * 0.97)
        case .gather:
            return (w * 1.04, h * 0.94, w * 1.04)
        case .dunk:
            return (w * 1.06, h * 1.06, w * 1.06)
        case .shoot:
            return (w * 0.98, h * 1.02, w * 0.98)
        case .jump:
            return (w * 0.95, h * 1.10, w * 0.95)
        case .land:
            return (w * 1.06, h * 0.92, w * 1.06)
        case .block:
            return (w * 1.05, h * 0.93, w * 1.05)
        case .counter:
            return (w * 0.94, h * 1.05, w * 0.94)
        case .vanish:
            return (w * 0.75, h * 0.75, w * 0.75)
        case .hitStun:
            return (w * 1.08, h * 0.90, w * 1.08)
        case .special:
            return (w * 1.14, h * 1.14, w * 1.14)
        case .swing:
            return (w * 1.05, h * 0.98, w * 0.95)
        case .kick:
            return (w * 0.94, h * 1.07, w * 0.94)
        case .spike:
            return (w * 0.93, h * 1.12, w * 0.93)
        case .serve:
            return (w * 0.97, h * 1.05, w * 0.97)
        case .catch_ball:
            return (w * 1.03, h * 0.97, w * 1.03)
        case .celebrate:
            return (w * 1.10, h * 1.10, w * 1.10)
        }
    }

    // MARK: - Canonical Animation IDs

    /// Returns the bundled NexusAnimationLoader animation id for this state.
    /// These map directly to `.nexusanim.json` files in Resources/Animations/.
    static func canonicalAnimationId(for state: AvatarPoseState, sport: String = "basketball") -> String? {
        switch state {
        case .idle:      return "anim_standing_idle"
        case .sprint:    return "anim_sprint_run_loop"
        case .gather:    return "anim_sprint_run_loop"
        case .dunk:      return "anim_basketball_dunk"
        case .shoot:     return "anim_basketball_jump_shot"
        case .jump:
            switch sport {
            case "volleyball": return "anim_volleyball_spike"
            default:           return "anim_basketball_jump_shot"
            }
        case .land:      return "anim_standing_idle"
        case .block:     return "anim_basketball_defensive_idle"
        case .swing:
            switch sport {
            case "baseball": return "anim_baseball_bat_swing"
            case "golf":     return "anim_golf_swing"
            case "tennis":   return "anim_tennis_serve"
            default:         return nil
            }
        case .kick:
            return sport == "karate" ? "anim_karate_punch_kick_combo" : "anim_soccer_kick_shot"
        case .spike:     return "anim_volleyball_spike"
        case .serve:     return "anim_tennis_serve"
        case .celebrate: return "anim_victory_celebration"
        case .hitStun:   return "anim_defeat_knockdown"
        case .special:
            switch sport {
            case "karate":   return "anim_karate_punch_kick_combo"
            case "football": return "anim_football_throw_pass"
            default:         return "anim_victory_celebration"
            }
        case .counter, .vanish, .catch_ball:
            return "anim_standing_idle"
        }
    }

    /// Returns true if this animation should loop continuously.
    static func isLooping(for state: AvatarPoseState) -> Bool {
        switch state {
        case .idle, .sprint, .gather, .block: return true
        default: return false
        }
    }
}

nonisolated enum ReadinessTier: String, Sendable, CaseIterable {
    case elite = "Elite"
    case primed = "Primed"
    case ready = "Ready"
    case recovering = "Recovering"
    case depleted = "Depleted"

    static func tier(for prq: Double) -> ReadinessTier {
        switch prq {
        case 90...: return .elite
        case 75..<90: return .primed
        case 60..<75: return .ready
        case 40..<60: return .recovering
        default: return .depleted
        }
    }

    var speedMultiplier: Double {
        switch self {
        case .elite: return 1.25
        case .primed: return 1.10
        case .ready: return 1.00
        case .recovering: return 0.85
        case .depleted: return 0.65
        }
    }

    var label: String { rawValue }
}
