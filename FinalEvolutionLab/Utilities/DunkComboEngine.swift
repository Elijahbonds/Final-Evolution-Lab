import Foundation

// MARK: - Trick Definitions

/// One dunk/trick in the combo chain
public struct DunkTrick: Identifiable, Equatable {
    public let id: String
    public let displayName: String
    public let difficulty: Double   // 1.0 = easy, 2.5 = hardest
    public let baseScore: Int
    public let requiredGesture: TrickGestureKind

    public static let all: [DunkTrick] = [
        DunkTrick(id: "jam",              displayName: "JAM",                  difficulty: 1.0, baseScore: 120, requiredGesture: .flickUp),
        DunkTrick(id: "tomahawk",         displayName: "TOMAHAWK",             difficulty: 1.3, baseScore: 160, requiredGesture: .flickUp),
        DunkTrick(id: "windmill",         displayName: "WINDMILL",             difficulty: 1.7, baseScore: 220, requiredGesture: .circleLeft),
        DunkTrick(id: "reverse",          displayName: "REVERSE",              difficulty: 1.5, baseScore: 190, requiredGesture: .flickDown),
        DunkTrick(id: "betweenLegs",      displayName: "BETWEEN THE LEGS",     difficulty: 1.9, baseScore: 260, requiredGesture: .flickDown),
        DunkTrick(id: "threeSixty",       displayName: "360°",                 difficulty: 2.0, baseScore: 280, requiredGesture: .circleRight),
        DunkTrick(id: "alleyOop",         displayName: "ALLEY-OOP",            difficulty: 1.6, baseScore: 210, requiredGesture: .flickUp),
        DunkTrick(id: "pump_fake",        displayName: "PUMP FAKE SLAM",       difficulty: 1.4, baseScore: 175, requiredGesture: .flickLeft),
        DunkTrick(id: "scoopReverse",     displayName: "SCOOP REVERSE",        difficulty: 2.1, baseScore: 295, requiredGesture: .flickDown),
        DunkTrick(id: "360eastbay",       displayName: "360 EAST BAY",         difficulty: 2.4, baseScore: 380, requiredGesture: .circleLeft),
        DunkTrick(id: "360fakeEastbay",   displayName: "360 FAKE EAST BAY",    difficulty: 2.2, baseScore: 340, requiredGesture: .circleRight),
        DunkTrick(id: "offBackboard",     displayName: "OFF THE BACKBOARD",    difficulty: 2.5, baseScore: 420, requiredGesture: .flickLeft),
        DunkTrick(id: "windmillOBB",      displayName: "OBB WINDMILL",         difficulty: 2.5, baseScore: 450, requiredGesture: .circleLeft),
    ]

    public static func forId(_ id: String) -> DunkTrick {
        all.first { $0.id == id } ?? all[0]
    }
}

public enum TrickGestureKind: String {
    case flickUp    = "↑"
    case flickDown  = "↓"
    case flickLeft  = "←"
    case flickRight = "→"
    case circleLeft  = "↺"
    case circleRight = "↻"
}

// MARK: - Chain Slot

public struct TrickChainSlot: Identifiable {
    public let id = UUID()
    public let trick: DunkTrick
    /// Timing quality 0..1 (1 = perfectly on beat)
    public var timingScore: Double = 0
    /// Phase: .waiting, .winding, .peaking, .releasing, .landed
    public var phase: TrickPhase = .waiting
    public var phaseProgress: Double = 0   // 0→1 within current phase
    public var score: Int = 0
}

public enum TrickPhase: Equatable {
    case waiting     // not yet started
    case windUp      // approach & load
    case peak        // at apex of jump, trick motion
    case release     // arm/body extension, ball release
    case land        // touches rim / backboard
    case bailed      // crashed, combo lost
}

// MARK: - Combo Engine State

public enum ComboEnginePhase: Equatable {
    case idle           // no approach started
    case approach       // sprinting to basket
    case bulletWindow   // slow-motion chain input window open
    case executing      // running through trick queue
    case landing        // final slam / land animation
    case scoring        // calculating + displaying score
    case bailed         // wipe-out / fumble
}

// MARK: - Dunk Combo Engine

/// THPS2 × NBA 07/08 trick chaining system.
/// Call `update(dt:)` every frame with the *real* delta time.
/// The engine internally applies `bulletTimeScale` to advance trick phases slowly.
public final class DunkComboEngine {

    // ── Public state ─────────────────────────────────────────────────────────

    public private(set) var enginePhase: ComboEnginePhase = .idle
    public private(set) var trickChain:  [TrickChainSlot] = []
    public private(set) var multiplier:  Double = 1.0

    /// 0.0 = frozen, 1.0 = real time. Drops to 0.15 when window is open.
    public private(set) var bulletTimeScale: Double = 1.0

    /// 0→1 window timer; chain input is accepted while this > 0
    public private(set) var chainWindowOpen: Double = 0

    /// Approach charge 0→1 (player holds button to charge sprint)
    public private(set) var approachCharge: Double = 0

    /// Jump height 0→1 during execution
    public private(set) var jumpHeight: Double = 0

    /// Position of player along court axis 0=start 1=rim
    public private(set) var courtProgress: Double = 0

    /// Total committed score from landed tricks
    public private(set) var comboScore: Int = 0

    /// The trick slot currently being animated
    public var activeTrickIndex: Int? {
        trickChain.indices.first { trickChain[$0].phase == .windUp || trickChain[$0].phase == .peak || trickChain[$0].phase == .release }
    }

    /// Rotation progress 0→1 for the active trick (drives body rotation FX)
    public private(set) var rotationProgress: Double = 0

    // ── Private timing ────────────────────────────────────────────────────────

    private var phaseClock: Double = 0

    // Phase durations (real-time seconds before bullet-time scaling)
    private let approachDuration    = 2.0
    private let windUpDuration      = 0.30
    private let peakDuration        = 0.55
    private let releaseDuration     = 0.30
    private let landDuration        = 0.45
    private let chainWindowDuration = 1.2   // seconds of window (in bullet-time)
    private let bailDuration        = 1.2

    // Maximum tricks in one combo chain
    public let maxChainLength = 4

    // ── Callbacks ─────────────────────────────────────────────────────────────

    /// Called when the chain successfully lands on the rim
    public var onComboLand: ((Int) -> Void)?
    /// Called when the chain bails
    public var onComboBail: (() -> Void)?
    /// Called when bullet-time window opens for next trick input
    public var onWindowOpen: (() -> Void)?

    // MARK: - Init

    public init() {}

    // MARK: - Public API

    /// Hold/press approach charge button (call while player holds)
    public func chargeApproach(dt: Double) {
        guard enginePhase == .idle else { return }
        approachCharge = min(1.0, approachCharge + dt * 0.8)
    }

    /// Release approach — begins the run-up
    public func releaseApproach() {
        guard enginePhase == .idle && approachCharge > 0.15 else { return }
        enginePhase = .approach
        courtProgress = 0
        phaseClock = 0
    }

    /// Input a trick during the chain window
    /// Returns true if accepted, false if window is closed or chain is full
    @discardableResult
    public func inputTrick(_ trick: DunkTrick, timingFraction: Double = 0.5) -> Bool {
        guard enginePhase == .bulletWindow || (enginePhase == .approach && trickChain.isEmpty) else { return false }
        guard trickChain.count < maxChainLength else { return false }

        var slot = TrickChainSlot(trick: trick)
        slot.timingScore = timingFraction
        slot.phase = .waiting
        trickChain.append(slot)

        // Close window immediately to prevent accidental double-input
        if enginePhase == .bulletWindow {
            chainWindowOpen = 0
            enginePhase = .executing
            phaseClock = 0
        }
        return true
    }

    /// Call every frame with *real* elapsed seconds (not scaled).
    public func update(dt: Double) {
        switch enginePhase {

        case .idle:
            // Passive charge decay when not pressing
            if approachCharge > 0 {
                approachCharge = max(0, approachCharge - dt * 0.4)
            }

        case .approach:
            let scaled = dt * bulletTimeScale
            phaseClock += scaled
            courtProgress = min(1.0, phaseClock / approachDuration)

            // Open the first trick window when halfway down the lane
            if courtProgress > 0.45 && trickChain.isEmpty && chainWindowOpen == 0 {
                openBulletWindow()
            }

            // Reached the rim with no trick queued — auto-jam
            if courtProgress >= 1.0 && trickChain.isEmpty {
                inputTrick(DunkTrick.forId("jam"), timingFraction: 0.5)
            }

            if courtProgress >= 1.0 && !trickChain.isEmpty {
                enginePhase = .executing
                phaseClock = 0
                jumpHeight = 0
                trickChain[0].phase = .windUp
            }

        case .bulletWindow:
            // Pure bullet-time input window — time is ultra-slow
            bulletTimeScale = 0.15
            phaseClock += dt   // real time (not scaled) for window countdown
            chainWindowOpen = max(0, 1.0 - phaseClock / chainWindowDuration)

            if chainWindowOpen <= 0 {
                // Window closed without new input — start executing with what we have
                if trickChain.isEmpty {
                    bail()
                } else {
                    enginePhase = .executing
                    phaseClock = 0
                    trickChain[0].phase = .windUp
                    bulletTimeScale = 1.0
                }
            }

        case .executing:
            bulletTimeScale = 1.0
            guard let idx = activeTrickIndex else {
                // No active trick — advance to next in queue
                if let nextIdx = trickChain.indices.first(where: { trickChain[$0].phase == .waiting }) {
                    trickChain[nextIdx].phase = .windUp
                    phaseClock = 0
                } else {
                    // All tricks complete → landing
                    enginePhase = .landing
                    jumpHeight  = 1.0
                    phaseClock  = 0
                }
                return
            }

            phaseClock += dt
            advanceTrickPhase(idx: idx, dt: dt)

        case .landing:
            phaseClock += dt
            jumpHeight = max(0, 1.0 - phaseClock / landDuration)
            rotationProgress = 0
            if phaseClock >= landDuration {
                commitScore()
                enginePhase = .scoring
                phaseClock  = 0
            }

        case .scoring:
            phaseClock += dt
            if phaseClock > 3.0 {
                reset()
            }

        case .bailed:
            phaseClock += dt
            jumpHeight = max(0, jumpHeight - dt * 2.0)
            if phaseClock > bailDuration {
                reset()
            }
        }
    }

    // MARK: - Private helpers

    private func openBulletWindow() {
        bulletTimeScale = 0.15
        chainWindowOpen = 1.0
        phaseClock = 0
        enginePhase = .bulletWindow
        onWindowOpen?()
    }

    private func advanceTrickPhase(idx: Int, dt: Double) {
        let scaled = dt   // full speed during execution (bullet time is only in window)
        let phase  = trickChain[idx].phase

        switch phase {
        case .windUp:
            trickChain[idx].phaseProgress += scaled / windUpDuration
            jumpHeight = min(0.6, trickChain[idx].phaseProgress * 0.6)
            if trickChain[idx].phaseProgress >= 1.0 {
                trickChain[idx].phase = .peak
                trickChain[idx].phaseProgress = 0
                phaseClock = 0

                // Open chain window for next trick if chain not full
                if trickChain.count < maxChainLength {
                    openBulletWindow()
                }
            }

        case .peak:
            trickChain[idx].phaseProgress += scaled / peakDuration
            jumpHeight = 0.6 + trickChain[idx].phaseProgress * 0.4  // rises to 1.0
            rotationProgress = trickChain[idx].phaseProgress

            // If bullet window closed without new input, continue to release
            if chainWindowOpen <= 0 || enginePhase == .executing {
                if trickChain[idx].phaseProgress >= 1.0 {
                    trickChain[idx].phase = .release
                    trickChain[idx].phaseProgress = 0
                }
            }

        case .release:
            trickChain[idx].phaseProgress += scaled / releaseDuration
            jumpHeight = max(0, 1.0 - trickChain[idx].phaseProgress * 0.3)
            rotationProgress = 1.0

            if trickChain[idx].phaseProgress >= 1.0 {
                // Score this trick
                let score = computeTrickScore(slot: trickChain[idx])
                trickChain[idx].score = score
                trickChain[idx].phase = .land
                comboScore += score
                multiplier  = min(4.0, 1.0 + Double(trickChain.filter { $0.phase == .land }.count) * 0.5)
                phaseClock = 0
            }

        default:
            break
        }
    }

    private func computeTrickScore(slot: TrickChainSlot) -> Int {
        let timing = slot.timingScore   // 0..1
        let mult   = multiplier
        let base   = Double(slot.trick.baseScore)
        let diff   = slot.trick.difficulty
        // Timing bonus: perfect (>0.85) = 1.3×, good (>0.65) = 1.1×
        let timingBonus = timing > 0.85 ? 1.3 : timing > 0.65 ? 1.1 : timing > 0.40 ? 1.0 : 0.7
        return Int((base * diff * mult * timingBonus).rounded())
    }

    private func commitScore() {
        onComboLand?(comboScore)
    }

    private func bail() {
        enginePhase = .bailed
        phaseClock  = 0
        bulletTimeScale = 1.0
        chainWindowOpen = 0
        onComboBail?()
    }

    private func reset() {
        enginePhase  = .idle
        trickChain   = []
        multiplier   = 1.0
        bulletTimeScale = 1.0
        chainWindowOpen = 0
        approachCharge  = 0
        jumpHeight      = 0
        courtProgress   = 0
        comboScore      = 0
        rotationProgress = 0
        phaseClock      = 0
    }
}

// MARK: - Gesture Recognition for Trick Input

extension DunkComboEngine {

    /// Recognize a trick gesture and input it into the chain.
    /// Call from DragGesture.onEnded.
    @discardableResult
    public func recognizeTrickGesture(translation: CGSize, velocity: CGSize) -> DunkTrick? {
        let tx = translation.width
        let ty = translation.height
        let vx = velocity.width
        let vy = velocity.height
        let speed = sqrt(vx * vx + vy * vy)
        let dist  = sqrt(tx * tx + ty * ty)

        guard dist > 18 else { return nil }

        let isCircle = abs(tx) > 28 && abs(ty) > 28 && dist < abs(tx) + abs(ty) * 1.4

        let gesture: TrickGestureKind
        if isCircle {
            gesture = tx > 0 ? .circleRight : .circleLeft
        } else if abs(ty) > abs(tx) {
            gesture = ty < 0 ? .flickUp : .flickDown
        } else {
            gesture = tx > 0 ? .flickRight : .flickLeft
        }

        // Timing quality based on gesture speed (faster = better)
        let timingQ = min(1.0, Double(speed) / 1200.0)

        // Find the best trick matching this gesture (pick highest difficulty that matches)
        let candidates = DunkTrick.all.filter { $0.requiredGesture == gesture }
        guard let trick = candidates.last else { return nil }

        let accepted = inputTrick(trick, timingFraction: timingQ)
        return accepted ? trick : nil
    }
}

// MARK: - Bullet Time Visual Data

extension DunkComboEngine {
    /// Visual time-scale to apply to all animations in the renderer.
    /// 1.0 = real time, 0.15 = bullet time slow-mo.
    public var rendererTimeScale: Double { bulletTimeScale }

    /// True when the screen should show a bullet-time vignette / shimmer
    public var isSlowMo: Bool { bulletTimeScale < 0.5 }

    /// Current trick display name (empty if idle)
    public var activeTrickName: String {
        guard let idx = activeTrickIndex else { return "" }
        return trickChain[idx].trick.displayName
    }

    /// Full combo name string e.g. "WINDMILL + 360° + BETWEEN THE LEGS"
    public var comboDisplayName: String {
        trickChain.map { $0.trick.displayName }.joined(separator: " + ")
    }
}
