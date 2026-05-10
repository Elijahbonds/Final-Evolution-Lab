import Foundation
import QuartzCore

nonisolated enum DunkPhase: String, Sendable {
    case idle
    case approach
    case launch
    case airborne
    case landing
    case scored
}

nonisolated enum DunkTrickSlot: String, Sendable, CaseIterable {
    case windmill = "WINDMILL"
    case betweenLegs = "BETWEEN THE LEGS"
    case tomahawk = "TOMAHAWK"
    case threeSixty = "360"
    case reverseJam = "REVERSE JAM"
    case elbowHang = "ELBOW HANG"
    case freeThrowLine = "FREE THROW LINE"
    case doubleClutch = "DOUBLE CLUTCH"

    var complexity: Double {
        switch self {
        case .tomahawk: return 0.6
        case .windmill: return 0.75
        case .betweenLegs: return 0.85
        case .threeSixty: return 0.8
        case .reverseJam: return 0.7
        case .elbowHang: return 0.9
        case .freeThrowLine: return 1.0
        case .doubleClutch: return 0.65
        }
    }

    var icon: String {
        switch self {
        case .windmill: return "wind"
        case .betweenLegs: return "arrow.down.forward.and.arrow.up.backward"
        case .tomahawk: return "bolt.fill"
        case .threeSixty: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .reverseJam: return "arrow.uturn.backward"
        case .elbowHang: return "hand.raised.fill"
        case .freeThrowLine: return "airplane"
        case .doubleClutch: return "hands.clap.fill"
        }
    }

    var baseStylePoints: Int {
        Int(complexity * 20)
    }

    var faceButtonCategory: ArcadeFaceButton {
        switch self {
        case .windmill, .doubleClutch: return .square
        case .betweenLegs, .threeSixty, .elbowHang: return .triangle
        case .tomahawk, .reverseJam: return .circle
        case .freeThrowLine: return .cross
        }
    }
}

/// Deterministic dunk math for production and tests; judge rolls are injected for `0..<spread`.
/// Uses scalar inputs only so scoring stays **`nonisolated`** and avoids MainActor isolation on ``DunkContestState`` (Swift 6–friendly).
nonisolated enum DunkContestScoring {
    static func calculate(
        jumpHeight: Double,
        launchQuality: Double,
        landingQuality: Double,
        completedRotation: Double,
        selectedTrick: DunkTrickSlot,
        trickHistory: [DunkTrickSlot],
        totalFreestylePoints: Int,
        midAirBranchCount: Int,
        activeModifier: DunkModifier,
        styleLandingSuccess: Bool,
        prq: Double,
        neuralBurst: Bool,
        judgeOffsets: (Int, Int, Int)
    ) -> (total: Int, j1: Int, j2: Int, j3: Int, message: String) {
        let normalized = min(max(prq / 100.0, 0), 1)

        let heightScore = jumpHeight * 20
        let trickScore = selectedTrick.complexity * 25
        let executionScore = ((launchQuality + landingQuality) / 2.0) * 20
        let rotationScore = completedRotation * 8

        var originalityBonus: Double = 0
        let previousCount = trickHistory.filter { $0 == selectedTrick }.count
        if previousCount == 0 { originalityBonus = 12 }
        else if previousCount == 1 { originalityBonus = 5 }

        let freestyleBonus = Double(min(totalFreestylePoints, 30))
        let chainBonus = Double(midAirBranchCount) * 5
        let modifierBonus = (activeModifier.scoreMultiplier - 1.0) * 15

        let styleLandingBonus: Double = styleLandingSuccess ? 8 : 0

        var rawScore = heightScore + trickScore + executionScore + rotationScore +
            originalityBonus + freestyleBonus + chainBonus + modifierBonus + styleLandingBonus
        rawScore *= (0.85 + normalized * 0.15)
        if neuralBurst { rawScore *= 1.12 }

        let base = min(50, Int(rawScore / 3.0) + 30)
        let spread = max(1, 5 - Int(executionScore / 8))
        let o1 = judgeOffsets.0 % spread
        let o2 = judgeOffsets.1 % spread
        let o3 = judgeOffsets.2 % spread
        let j1 = min(50, base + o1)
        let j2 = min(50, base + o2)
        let j3 = min(50, base + o3)
        let total = j1 + j2 + j3

        let message: String
        if total >= 145 { message = "PERFECT DUNK!" }
        else if total >= 140 { message = "LEGENDARY!" }
        else if total >= 135 { message = "CROWD GOES WILD!" }
        else if total >= 130 { message = "ELECTRIFYING!" }
        else if total >= 120 { message = "POWERFUL!" }
        else if total >= 110 { message = "SOLID DUNK" }
        else { message = "NEEDS WORK" }

        return (total, j1, j2, j3, message)
    }
}

struct DunkContestState {
    var phase: DunkPhase = .idle
    var round: Int = 1
    var totalRounds: Int = 3
    var totalScore: Int = 0
    var roundScores: [(round: Int, score: Int, message: String)] = []

    var sprintCharge: Double = 0
    var sprintChargeRate: Double = 2.2
    var isSprintHeld: Bool = false

    var launchTiming: Double = 0
    var launchTimingDirection: Double = 1
    var launchTimingSpeed: Double = 2.5
    var launchGreenZone: ClosedRange<Double> = 0.4...0.7

    var selectedTrick: DunkTrickSlot = .tomahawk
    var rotationAmount: Double = 0
    var isRotating: Bool = false
    var rotationTarget: Double = 1.0
    var airTime: Double = 0
    var maxAirTime: Double = 2.8
    var airPhaseStart: Double = 0

    var landingTiming: Double = 0
    var landingTimingDirection: Double = 1
    var landingTimingSpeed: Double = 2.8
    var landingGreenZone: ClosedRange<Double> = 0.35...0.65

    var trickHistory: [DunkTrickSlot] = []
    var showSlowMo: Bool = false
    var showApexFreeze: Bool = false
    var impactIntensity: Double = 0
    var crowdReaction: String = ""
    var judgeScores: (Int, Int, Int)?

    var activeModifier: DunkModifier = .standard
    var midAirState = MidAirTrickState()
    var inputBuffer = ArcadeInputBuffer()
    var freestyleComboMultiplier: Double = 1.0
    var styleLandingWindow: Bool = false
    var styleLandingSuccess: Bool = false
    var totalFreestylePoints: Int = 0
    var rimDistortionAmount: Double = 0

    var isComplete: Bool {
        round > totalRounds
    }

    var launchQuality: Double {
        let center = (launchGreenZone.lowerBound + launchGreenZone.upperBound) / 2
        let maxDist = (launchGreenZone.upperBound - launchGreenZone.lowerBound) / 2
        let dist = abs(launchTiming - center)
        if dist > maxDist * 2.5 { return 0 }
        return max(0, 1.0 - (dist / (maxDist * 2.0)))
    }

    var landingQuality: Double {
        let center = (landingGreenZone.lowerBound + landingGreenZone.upperBound) / 2
        let maxDist = (landingGreenZone.upperBound - landingGreenZone.lowerBound) / 2
        let dist = abs(landingTiming - center)
        if dist > maxDist * 2.5 { return 0 }
        return max(0, 1.0 - (dist / (maxDist * 2.0)))
    }

    var jumpHeight: Double {
        let sprintBonus = sprintCharge * 0.4
        let launchBonus = launchQuality * 0.6
        return min(1.0, sprintBonus + launchBonus)
    }

    var completedRotation: Double {
        min(1.0, rotationAmount / rotationTarget)
    }

    var dunkDifficulty: Double {
        let complexityScore = selectedTrick.complexity
        let heightScore = jumpHeight
        let contortionScore = Double(midAirState.branchCount) * 0.2
        return complexityScore * heightScore * (1.0 + contortionScore)
    }

    mutating func processArcadeInput(button: ArcadeFaceButton) {
        guard phase == .airborne else { return }
        let entry = InputBufferEntry(
            button: button,
            timestamp: CACurrentMediaTime(),
            modifier: activeModifier
        )
        inputBuffer = inputBuffer.adding(entry)
        let isDouble = inputBuffer.isDoubleTap(button)
        let trick = DunkTrickResolver.resolve(
            button: button,
            modifier: activeModifier,
            isDoubleTap: isDouble
        )
        selectedTrick = trick
        midAirState.addTrick(button)
        let points = DunkTrickResolver.freestylePoints(
            button: button,
            modifier: activeModifier,
            isDoubleTap: isDouble,
            chainLength: inputBuffer.chainLength
        )
        midAirState.addStylePoints(points)
        totalFreestylePoints += Int(Double(points) * midAirState.comboMultiplier)
        if !isRotating { isRotating = true }
    }

    mutating func setModifier(styleTrigger: Bool, powerTrigger: Bool) {
        if styleTrigger && powerTrigger {
            activeModifier = .signature
        } else if styleTrigger {
            activeModifier = .flashy
        } else if powerTrigger {
            activeModifier = .power
        } else {
            activeModifier = .standard
        }
    }

    mutating func calculateDunkScore(prq: Double, neuralBurst: Bool) -> (total: Int, j1: Int, j2: Int, j3: Int, message: String) {
        let executionScore = ((launchQuality + landingQuality) / 2.0) * 20
        let spread = max(1, 5 - Int(executionScore / 8))
        let judgeOffsets = (
            Int.random(in: 0..<spread),
            Int.random(in: 0..<spread),
            Int.random(in: 0..<spread)
        )
        let out = DunkContestScoring.calculate(
            jumpHeight: jumpHeight,
            launchQuality: launchQuality,
            landingQuality: landingQuality,
            completedRotation: completedRotation,
            selectedTrick: selectedTrick,
            trickHistory: trickHistory,
            totalFreestylePoints: totalFreestylePoints,
            midAirBranchCount: midAirState.branchCount,
            activeModifier: activeModifier,
            styleLandingSuccess: styleLandingSuccess,
            prq: prq,
            neuralBurst: neuralBurst,
            judgeOffsets: judgeOffsets
        )

        impactIntensity = jumpHeight * landingQuality
        rimDistortionAmount = activeModifier == .power ? 0.15 : (activeModifier == .signature ? 0.2 : 0.08)
        trickHistory.append(selectedTrick)

        return (out.total, out.j1, out.j2, out.j3, out.message)
    }

    mutating func startApproach() {
        phase = .approach
        sprintCharge = 0
        isSprintHeld = true
        launchTiming = 0
        rotationAmount = 0
        isRotating = false
        airTime = 0
        landingTiming = 0
        showSlowMo = false
        showApexFreeze = false
        impactIntensity = 0
        crowdReaction = ""
        judgeScores = nil
        midAirState.reset()
        inputBuffer = ArcadeInputBuffer()
        freestyleComboMultiplier = 1.0
        styleLandingWindow = false
        styleLandingSuccess = false
        totalFreestylePoints = 0
        rimDistortionAmount = 0
        activeModifier = .standard
    }

    mutating func releaseSprint() {
        guard phase == .approach else { return }
        isSprintHeld = false
        phase = .launch
        launchTiming = 0
        launchTimingDirection = 1

        let difficulty = selectedTrick.complexity
        let greenWidth = max(0.18, 0.38 - difficulty * 0.12)
        let center = 0.5 + Double.random(in: -0.06...0.06)
        launchGreenZone = max(0, center - greenWidth / 2)...min(1, center + greenWidth / 2)
        launchTimingSpeed = 2.0 + difficulty * 0.7
    }

    mutating func confirmLaunch() {
        guard phase == .launch else { return }
        phase = .airborne
        airPhaseStart = CACurrentMediaTime()
        maxAirTime = 2.4 + jumpHeight * 1.0
        rotationTarget = 0.5 + selectedTrick.complexity * 0.5

        let difficulty = selectedTrick.complexity
        let dd = dunkDifficulty
        let landGreenWidth = max(0.14, 0.32 - dd * 0.07)
        let landCenter = 0.5 + Double.random(in: -0.05...0.05)
        landingGreenZone = max(0, landCenter - landGreenWidth / 2)...min(1, landCenter + landGreenWidth / 2)
        landingTimingSpeed = 2.4 + difficulty * 0.5
    }

    mutating func updateAirborne(delta: Double) {
        guard phase == .airborne else { return }
        airTime += delta
        if isRotating {
            rotationAmount += delta * (1.4 + jumpHeight * 0.6)
        }
        landingTiming += landingTimingDirection * landingTimingSpeed * delta
        if landingTiming >= 1.0 { landingTimingDirection = -1 }
        if landingTiming <= 0.0 { landingTimingDirection = 1 }
        landingTiming = max(0, min(1, landingTiming))

        let apexThreshold = maxAirTime * 0.4
        showApexFreeze = airTime >= apexThreshold && airTime <= apexThreshold + 0.3
        showSlowMo = airTime >= maxAirTime * 0.3 && airTime <= maxAirTime * 0.7

        if airTime >= maxAirTime * 0.85 {
            styleLandingWindow = true
            midAirState.isStyleLandingAvailable = true
        }

        if airTime >= maxAirTime {
            phase = .landing
        }
    }

    mutating func attemptStyleLanding() -> Int {
        guard styleLandingWindow else { return 0 }
        styleLandingSuccess = true
        freestyleComboMultiplier += 0.5
        let bonus = midAirState.styleLandingRevert()
        return bonus
    }

    mutating func confirmLanding() {
        guard phase == .airborne || phase == .landing else { return }
        phase = .scored
    }

    mutating func advanceRound() {
        round += 1
        phase = .idle
        selectedTrick = .tomahawk
        midAirState.reset()
        inputBuffer = ArcadeInputBuffer()
        totalFreestylePoints = 0
    }
}
