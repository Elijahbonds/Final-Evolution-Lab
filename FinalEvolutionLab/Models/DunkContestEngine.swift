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
}

struct DunkContestState {
    var phase: DunkPhase = .idle
    var round: Int = 1
    var totalRounds: Int = 3
    var totalScore: Int = 0
    var roundScores: [(round: Int, score: Int, message: String)] = []

    var sprintCharge: Double = 0
    var sprintChargeRate: Double = 1.8
    var isSprintHeld: Bool = false

    var launchTiming: Double = 0
    var launchTimingDirection: Double = 1
    var launchTimingSpeed: Double = 2.2
    var launchGreenZone: ClosedRange<Double> = 0.4...0.7

    var selectedTrick: DunkTrickSlot = .tomahawk
    var rotationAmount: Double = 0
    var isRotating: Bool = false
    var rotationTarget: Double = 1.0
    var airTime: Double = 0
    var maxAirTime: Double = 2.5
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

    mutating func calculateDunkScore(prq: Double, neuralBurst: Bool) -> (total: Int, j1: Int, j2: Int, j3: Int, message: String) {
        let normalized = min(max(prq / 100.0, 0), 1)

        let heightScore = jumpHeight * 25
        let trickScore = selectedTrick.complexity * 30
        let executionScore = ((launchQuality + landingQuality) / 2.0) * 25
        let rotationScore = completedRotation * 10
        let originalityBonus: Double = trickHistory.filter({ $0 == selectedTrick }).count <= 1 ? 10 : 0

        var rawScore = heightScore + trickScore + executionScore + rotationScore + originalityBonus
        rawScore *= (0.85 + normalized * 0.15)
        if neuralBurst { rawScore *= 1.12 }

        let base = min(50, Int(rawScore / 3.0) + 30)
        let spread = max(1, 5 - Int(executionScore / 8))
        let j1 = min(50, base + Int.random(in: 0..<spread))
        let j2 = min(50, base + Int.random(in: 0..<spread))
        let j3 = min(50, base + Int.random(in: 0..<spread))
        let total = j1 + j2 + j3

        let message: String
        if total >= 145 { message = "PERFECT DUNK!" }
        else if total >= 138 { message = "CROWD GOES WILD!" }
        else if total >= 130 { message = "ELECTRIFYING!" }
        else if total >= 120 { message = "POWERFUL!" }
        else if total >= 110 { message = "SOLID DUNK" }
        else { message = "NEEDS WORK" }

        impactIntensity = jumpHeight * landingQuality
        trickHistory.append(selectedTrick)

        return (total, j1, j2, j3, message)
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
    }

    mutating func releaseSprint() {
        guard phase == .approach else { return }
        isSprintHeld = false
        phase = .launch
        launchTiming = 0
        launchTimingDirection = 1

        let difficulty = selectedTrick.complexity
        let greenWidth = max(0.15, 0.35 - difficulty * 0.12)
        let center = 0.5 + Double.random(in: -0.08...0.08)
        launchGreenZone = (center - greenWidth / 2)...(center + greenWidth / 2)
        launchTimingSpeed = 2.0 + difficulty * 0.8
    }

    mutating func confirmLaunch() {
        guard phase == .launch else { return }
        phase = .airborne
        airPhaseStart = CACurrentMediaTime()
        maxAirTime = 1.8 + jumpHeight * 0.8
        rotationTarget = 0.5 + selectedTrick.complexity * 0.5

        let difficulty = selectedTrick.complexity
        let landGreenWidth = max(0.12, 0.30 - difficulty * 0.1)
        let landCenter = 0.5 + Double.random(in: -0.06...0.06)
        landingGreenZone = (landCenter - landGreenWidth / 2)...(landCenter + landGreenWidth / 2)
        landingTimingSpeed = 2.4 + difficulty * 0.6
    }

    mutating func updateAirborne(delta: Double) {
        guard phase == .airborne else { return }
        airTime += delta
        if isRotating {
            rotationAmount += delta * (1.2 + jumpHeight * 0.5)
        }
        landingTiming += landingTimingDirection * landingTimingSpeed * delta
        if landingTiming >= 1.0 { landingTimingDirection = -1 }
        if landingTiming <= 0.0 { landingTimingDirection = 1 }
        landingTiming = max(0, min(1, landingTiming))

        let apexThreshold = maxAirTime * 0.4
        showApexFreeze = airTime >= apexThreshold && airTime <= apexThreshold + 0.3
        showSlowMo = airTime >= maxAirTime * 0.3 && airTime <= maxAirTime * 0.7

        if airTime >= maxAirTime {
            phase = .landing
        }
    }

    mutating func confirmLanding() {
        guard phase == .airborne || phase == .landing else { return }
        phase = .scored
    }

    mutating func advanceRound() {
        round += 1
        phase = .idle
        selectedTrick = .tomahawk
    }
}
