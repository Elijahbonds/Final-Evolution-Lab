import Foundation

nonisolated enum AvatarPoseState: String, Sendable {
    case idle
    case sprint
    case gather
    case dunk
    case shoot
    case jump
}

nonisolated struct AvatarStateMachine: Sendable {
    static let blendTimeSeconds: Double = 0.2

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

    static func poseRotationX(for state: AvatarPoseState) -> Float {
        switch state {
        case .idle: return 0
        case .sprint: return -0.1
        case .gather: return 0.15
        case .dunk: return 0.35
        case .shoot: return -0.2
        case .jump: return 0
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
        }
    }
}
