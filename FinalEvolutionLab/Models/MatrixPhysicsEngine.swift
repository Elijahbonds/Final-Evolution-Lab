import Foundation
import QuartzCore
import OSLog

private let physicsLogger = Logger(subsystem: "com.finalevolutionlab", category: "MatrixPhysicsEngine")

// MARK: - Delta-Time Tracking

/// Lightweight tracker that computes frame-rate independent delta time.
/// Wrap a var of this type and call update(currentTime:) each frame.
nonisolated struct DeltaTimeTracker: Sendable {
    var lastUpdateTime: CFTimeInterval = 0

    /// Returns the elapsed time (in seconds) since the last update call.
    /// Returns 0 on the very first call so physics don't spike on init.
    mutating func update(currentTime: CFTimeInterval) -> CFTimeInterval {
        let deltaTime: CFTimeInterval
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime
        physicsLogger.debug("DeltaTimeTracker: deltaTime=\(deltaTime, privacy: .public)")
        return deltaTime
    }
}

/// A mutable physics state whose position and velocity updates are
/// multiplied by deltaTime so they remain frame-rate independent.
nonisolated struct FrameIndependentPhysicsState: Sendable {
    var position: SIMD3<Double>
    var velocity: SIMD3<Double>
    private(set) var lastUpdateTime: CFTimeInterval

    init(position: SIMD3<Double> = .zero, velocity: SIMD3<Double> = .zero) {
        self.position = position
        self.velocity = velocity
        self.lastUpdateTime = 0
    }

    /// Advances position by velocity * deltaTime computed from currentTime.
    mutating func update(currentTime: CFTimeInterval) {
        let deltaTime: Double
        if lastUpdateTime == 0 {
            deltaTime = 0
        } else {
            deltaTime = currentTime - lastUpdateTime
        }
        lastUpdateTime = currentTime

        guard deltaTime > 0 else { return }

        position.x += velocity.x * deltaTime
        position.y += velocity.y * deltaTime
        position.z += velocity.z * deltaTime
    }

    /// Applies an acceleration vector for an explicit deltaTime slice.
    mutating func applyAcceleration(_ acceleration: SIMD3<Double>, deltaTime: Double) {
        guard deltaTime > 0 else { return }
        velocity.x += acceleration.x * deltaTime
        velocity.y += acceleration.y * deltaTime
        velocity.z += acceleration.z * deltaTime
    }
}

nonisolated struct TimeScaleManager: Sendable {
    static let normalScale: Double = 1.0
    static let slowMoScale: Double = 0.2
    static let finisherScale: Double = 0.15
    static let perfectGuardScale: Double = 0.2
    static let apexScale: Double = 0.3

    static let slowMoDuration: Double = 1.2
    static let finisherDuration: Double = 1.8
    static let perfectGuardDuration: Double = 0.8
    static let apexDuration: Double = 0.6

    static let blendInDuration: Double = 0.2
    static let blendOutDuration: Double = 0.2

    let currentScale: Double
    let targetScale: Double
    let effectStartTime: Double
    let effectDuration: Double
    let blendPhase: BlendPhase
    let activeEffect: TimeEffect

    nonisolated enum BlendPhase: String, Sendable {
        case idle
        case blendingIn
        case sustained
        case blendingOut
    }

    nonisolated enum TimeEffect: String, Sendable {
        case none
        case slowMo
        case finisher
        case perfectGuard
        case apex
    }

    init() {
        self.currentScale = Self.normalScale
        self.targetScale = Self.normalScale
        self.effectStartTime = 0
        self.effectDuration = 0
        self.blendPhase = .idle
        self.activeEffect = .none
    }

    private init(currentScale: Double, targetScale: Double, effectStartTime: Double, effectDuration: Double, blendPhase: BlendPhase, activeEffect: TimeEffect) {
        self.currentScale = currentScale
        self.targetScale = targetScale
        self.effectStartTime = effectStartTime
        self.effectDuration = effectDuration
        self.blendPhase = blendPhase
        self.activeEffect = activeEffect
    }

    func triggerSlowMo(at time: Double) -> TimeScaleManager {
        TimeScaleManager(
            currentScale: currentScale,
            targetScale: Self.slowMoScale,
            effectStartTime: time,
            effectDuration: Self.slowMoDuration,
            blendPhase: .blendingIn,
            activeEffect: .slowMo
        )
    }

    func triggerFinisher(at time: Double) -> TimeScaleManager {
        TimeScaleManager(
            currentScale: currentScale,
            targetScale: Self.finisherScale,
            effectStartTime: time,
            effectDuration: Self.finisherDuration,
            blendPhase: .blendingIn,
            activeEffect: .finisher
        )
    }

    func triggerPerfectGuard(at time: Double) -> TimeScaleManager {
        TimeScaleManager(
            currentScale: currentScale,
            targetScale: Self.perfectGuardScale,
            effectStartTime: time,
            effectDuration: Self.perfectGuardDuration,
            blendPhase: .blendingIn,
            activeEffect: .perfectGuard
        )
    }

    func triggerApex(at time: Double) -> TimeScaleManager {
        TimeScaleManager(
            currentScale: currentScale,
            targetScale: Self.apexScale,
            effectStartTime: time,
            effectDuration: Self.apexDuration,
            blendPhase: .blendingIn,
            activeEffect: .apex
        )
    }

    func update(at time: Double) -> TimeScaleManager {
        guard activeEffect != .none else { return self }

        let elapsed = time - effectStartTime
        let totalDuration = Self.blendInDuration + effectDuration + Self.blendOutDuration

        if elapsed < Self.blendInDuration {
            let t = elapsed / Self.blendInDuration
            let smoothT = t * t * (3 - 2 * t)
            let blended = Self.normalScale + (targetScale - Self.normalScale) * smoothT
            return TimeScaleManager(
                currentScale: blended,
                targetScale: targetScale,
                effectStartTime: effectStartTime,
                effectDuration: effectDuration,
                blendPhase: .blendingIn,
                activeEffect: activeEffect
            )
        }

        if elapsed < Self.blendInDuration + effectDuration {
            return TimeScaleManager(
                currentScale: targetScale,
                targetScale: targetScale,
                effectStartTime: effectStartTime,
                effectDuration: effectDuration,
                blendPhase: .sustained,
                activeEffect: activeEffect
            )
        }

        if elapsed < totalDuration {
            let outElapsed = elapsed - Self.blendInDuration - effectDuration
            let t = outElapsed / Self.blendOutDuration
            let smoothT = t * t * (3 - 2 * t)
            let blended = targetScale + (Self.normalScale - targetScale) * smoothT
            return TimeScaleManager(
                currentScale: blended,
                targetScale: targetScale,
                effectStartTime: effectStartTime,
                effectDuration: effectDuration,
                blendPhase: .blendingOut,
                activeEffect: activeEffect
            )
        }

        return TimeScaleManager()
    }

    var isActive: Bool { activeEffect != .none }

    func scaledDelta(_ realDelta: Double) -> Double {
        realDelta * currentScale
    }
}

nonisolated struct MatrixStateMachine: Sendable {
    static let blendDuration: Double = 0.2

    nonisolated enum Phase: String, Sendable {
        case idle
        case action
        case result
        case recovery
    }

    let currentPhase: Phase
    let previousPhase: Phase
    let phaseStartTime: Double
    let phaseData: PhaseData

    nonisolated struct PhaseData: Sendable {
        let actionName: String
        let intensity: Double
        let isFinisher: Bool

        init(actionName: String = "", intensity: Double = 0, isFinisher: Bool = false) {
            self.actionName = actionName
            self.intensity = intensity
            self.isFinisher = isFinisher
        }
    }

    init() {
        self.currentPhase = .idle
        self.previousPhase = .idle
        self.phaseStartTime = 0
        self.phaseData = PhaseData()
    }

    private init(currentPhase: Phase, previousPhase: Phase, phaseStartTime: Double, phaseData: PhaseData) {
        self.currentPhase = currentPhase
        self.previousPhase = previousPhase
        self.phaseStartTime = phaseStartTime
        self.phaseData = phaseData
    }

    func blendFactor(at time: Double) -> Double {
        let elapsed = time - phaseStartTime
        return min(1.0, elapsed / Self.blendDuration)
    }

    func transition(to phase: Phase, at time: Double, data: PhaseData = PhaseData()) -> MatrixStateMachine {
        guard phase != currentPhase else { return self }
        return MatrixStateMachine(
            currentPhase: phase,
            previousPhase: currentPhase,
            phaseStartTime: time,
            phaseData: data
        )
    }

    func startAction(name: String, intensity: Double, isFinisher: Bool, at time: Double) -> MatrixStateMachine {
        transition(to: .action, at: time, data: PhaseData(actionName: name, intensity: intensity, isFinisher: isFinisher))
    }

    func resolveAction(at time: Double) -> MatrixStateMachine {
        transition(to: .result, at: time)
    }

    func recover(at time: Double) -> MatrixStateMachine {
        transition(to: .recovery, at: time)
    }

    func toIdle(at time: Double) -> MatrixStateMachine {
        transition(to: .idle, at: time)
    }

    var isInAction: Bool { currentPhase == .action }
    var isFinisher: Bool { phaseData.isFinisher }
}

nonisolated struct ImpactFXConfig: Sendable {
    let screenShakeIntensity: Double
    let radialBlurRadius: Double
    let chromaticAberration: Double
    let rimFlexPercent: Double
    let backboardBounce: Double
    let flashDuration: Double

    static func forImpact(modifier: ModifierState, qteGrade: QTEGrade, jumpHeight: Double) -> ImpactFXConfig {
        let baseShake: Double
        let baseBlur: Double
        switch modifier {
        case .none:
            baseShake = 4.0
            baseBlur = 3.0
        case .style:
            baseShake = 6.0
            baseBlur = 6.0
        case .power:
            baseShake = 10.0
            baseBlur = 12.0
        case .special:
            baseShake = 14.0
            baseBlur = 16.0
        }

        let gradeScale = qteGrade.multiplier
        let heightScale = 0.6 + jumpHeight * 0.4

        return ImpactFXConfig(
            screenShakeIntensity: baseShake * gradeScale * heightScale,
            radialBlurRadius: baseBlur * gradeScale,
            chromaticAberration: modifier == .power || modifier == .special ? 3.0 * gradeScale : 0,
            rimFlexPercent: (modifier == .power ? 15.0 : (modifier == .special ? 20.0 : 5.0)) * gradeScale,
            backboardBounce: (modifier == .power ? 0.3 : 0.1) * gradeScale,
            flashDuration: qteGrade == .perfect ? 0.3 : 0.15
        )
    }

    static func forCombat(modifier: ModifierState, qteGrade: QTEGrade) -> ImpactFXConfig {
        let baseShake: Double = modifier == .special ? 12.0 : (modifier == .power ? 8.0 : 4.0)
        let gradeScale = qteGrade.multiplier
        return ImpactFXConfig(
            screenShakeIntensity: baseShake * gradeScale,
            radialBlurRadius: modifier == .special ? 14.0 : 4.0,
            chromaticAberration: modifier == .special ? 4.0 : 0,
            rimFlexPercent: 0,
            backboardBounce: 0,
            flashDuration: 0.2
        )
    }
}

nonisolated struct MatrixCameraDirector: Sendable {
    static let standardFOV: Float = 48
    static let gatherFOV: Float = 42
    static let flightFOV: Float = 55
    static let impactFOV: Float = 36
    static let finisherFOV: Float = 32
    static let highAngleDeg: Float = 27

    static let gatherZoom: Float = 0.85
    static let flightZoom: Float = 1.3
    static let impactZoom: Float = 0.65
    static let finisherZoom: Float = 0.5

    static func fovForPhase(_ phase: MatrixStateMachine.Phase, isFinisher: Bool) -> Float {
        switch phase {
        case .idle: return standardFOV
        case .action: return isFinisher ? finisherFOV : flightFOV
        case .result: return impactFOV
        case .recovery: return standardFOV
        }
    }

    static func zoomForPhase(_ phase: MatrixStateMachine.Phase, isFinisher: Bool) -> Float {
        switch phase {
        case .idle: return 1.0
        case .action: return isFinisher ? finisherZoom : flightZoom
        case .result: return impactZoom
        case .recovery: return 1.0
        }
    }
}
