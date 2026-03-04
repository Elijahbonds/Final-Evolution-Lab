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
        case .idle: return [.sprint, .gather, .jump, .shoot, .block, .special]
        case .sprint: return [.idle, .gather, .jump, .block]
        case .gather: return [.jump, .dunk, .idle]
        case .jump: return [.dunk, .shoot, .land, .idle]
        case .dunk: return [.land, .idle]
        case .shoot: return [.idle, .land]
        case .land: return [.idle, .sprint, .gather]
        case .block: return [.idle, .counter, .vanish, .hitStun]
        case .counter: return [.idle, .special]
        case .vanish: return [.idle, .counter, .special]
        case .hitStun: return [.idle]
        case .special: return [.idle, .land]
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
        }
    }

    static func poseScale(for state: AvatarPoseState, heightScale: Float = 1.0, weightScale: Float = 1.0) -> (x: Float, y: Float, z: Float) {
        switch state {
        case .idle:
            return (weightScale, heightScale, weightScale)
        case .sprint:
            return (weightScale * 0.98, heightScale * 1.02, weightScale * 0.98)
        case .gather:
            return (weightScale * 1.03, heightScale * 0.95, weightScale * 1.03)
        case .dunk:
            return (1.05, 1.05, 1.05)
        case .shoot:
            return (weightScale, heightScale, weightScale)
        case .jump:
            return (weightScale * 0.96, heightScale * 1.08, weightScale * 0.96)
        case .land:
            return (weightScale * 1.04, heightScale * 0.93, weightScale * 1.04)
        case .block:
            return (weightScale * 1.06, heightScale * 0.92, weightScale * 1.06)
        case .counter:
            return (weightScale * 0.95, heightScale * 1.04, weightScale * 0.95)
        case .vanish:
            return (weightScale * 0.8, heightScale * 0.8, weightScale * 0.8)
        case .hitStun:
            return (weightScale * 1.1, heightScale * 0.88, weightScale * 1.1)
        case .special:
            return (1.12, 1.12, 1.12)
        }
    }
}
