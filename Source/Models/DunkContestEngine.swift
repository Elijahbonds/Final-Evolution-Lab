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
    case eastbay360 = "360 EASTBAY"
    case kickUp = "KICK UP"
    case doubleEastbayOverCar = "DOUBLE UP EASTBAY OVER CAR"
    case honeyDip = "HONEY DIP"
    case superman = "SUPERMAN"
    case cradle = "ROCK THE CRADLE"
    case selfAlleyOop = "SELF ALLEY-OOP"
    case statueOfLiberty = "STATUE OF LIBERTY"
    case sevenTwenty = "720"

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
        case .eastbay360: return 0.92
        case .kickUp: return 0.88
        case .doubleEastbayOverCar: return 0.96
        case .honeyDip: return 0.93
        case .superman: return 0.91
        case .cradle: return 0.87
        case .selfAlleyOop: return 0.89
        case .statueOfLiberty: return 0.84
        case .sevenTwenty: return 0.94
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
        case .eastbay360: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .kickUp: return "arrow.up.and.down"
        case .doubleEastbayOverCar: return "car.fill"
        case .honeyDip: return "hand.raised.fill"
        case .superman: return "figure.run"
        case .cradle: return "figure.stand"
        case .selfAlleyOop: return "square.and.arrow.down"
        case .statueOfLiberty: return "figure.arms.open"
        case .sevenTwenty: return "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }

    var baseStylePoints: Int {
        Int(complexity * 20)
    }

    var faceButtonCategory: ArcadeFaceButton {
        switch self {
        case .windmill, .doubleClutch, .honeyDip, .superman: return .square
        case .betweenLegs, .threeSixty, .elbowHang, .eastbay360, .cradle, .sevenTwenty: return .triangle
        case .tomahawk, .reverseJam, .kickUp, .selfAlleyOop, .statueOfLiberty: return .circle
        case .freeThrowLine, .doubleEastbayOverCar: return .cross
        }
    }
}

struct DunkContestState {
    var phase: DunkPhase = .idle
    var round: Int = 1
    var totalRounds: Int = 3
    var totalScore: Int = 0
    var roundScores: [(round: Int, score: Int, message: String)] = []

    var sprintCharge: Double = 0
    /// Time to full charge ~0.6s at 60fps; feels intentional without dragging.
    var sprintChargeRate: Double = 1.65
    var isSprintHeld: Bool = false

    var launchTiming: Double = 0
    var launchTimingDirection: Double = 1
    var launchTimingSpeed: Double = 2.0
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
    var landingTimingSpeed: Double = 2.2
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

    /// When true, contest never ends (freestyle practice).
    var isFreestylePractice: Bool = false

    var isComplete: Bool {
        guard !isFreestylePractice, totalRounds > 0 else { return false }
        return round > totalRounds
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

    /// `academyPlyosNeuroMultiplier`: Vertical Velocity Academy Plyos (`mod9`) mastery — permanent +2% neuro to contest scoring.
    mutating func calculateDunkScore(prq: Double, neuralBurst: Bool, academyPlyosNeuroMultiplier: Double = 1.0) -> (total: Int, j1: Int, j2: Int, j3: Int, message: String) {
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
        let chainBonus = Double(midAirState.branchCount) * 5
        let modifierBonus = (activeModifier.scoreMultiplier - 1.0) * 15

        let styleLandingBonus: Double = styleLandingSuccess ? 8 : 0

        var rawScore = heightScore + trickScore + executionScore + rotationScore +
                       originalityBonus + freestyleBonus + chainBonus + modifierBonus + styleLandingBonus
        rawScore *= (0.85 + normalized * 0.15)
        rawScore *= min(1.06, max(1.0, academyPlyosNeuroMultiplier))
        if neuralBurst { rawScore *= 1.12 }

        let base = min(50, Int(rawScore / 3.0) + 30)
        let spread = max(1, 5 - Int(executionScore / 8))
        let j1 = min(50, base + Int.random(in: 0..<spread))
        let j2 = min(50, base + Int.random(in: 0..<spread))
        let j3 = min(50, base + Int.random(in: 0..<spread))
        let total = j1 + j2 + j3

        let message: String
        if total >= 148 { message = "PERFECT 50!" }
        else if total >= 145 { message = "LEGENDARY!" }
        else if total >= 140 { message = "CROWD GOES WILD!" }
        else if total >= 135 { message = "ELECTRIFYING!" }
        else if total >= 130 { message = "VINCE CARTER STYLE!" }
        else if total >= 125 { message = "POWERFUL!" }
        else if total >= 118 { message = "SOLID DUNK" }
        else if total >= 108 { message = "NICE TRY" }
        else { message = "NEXT TIME" }

        impactIntensity = jumpHeight * landingQuality
        rimDistortionAmount = activeModifier == .power ? 0.15 : (activeModifier == .signature ? 0.2 : 0.08)
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
        let greenWidth = max(0.24, 0.44 - difficulty * 0.1)
        let center = 0.5 + Double.random(in: -0.05...0.05)
        launchGreenZone = max(0, center - greenWidth / 2)...min(1, center + greenWidth / 2)
        launchTimingSpeed = 1.5 + difficulty * 0.5
    }

    mutating func confirmLaunch() {
        guard phase == .launch else { return }
        phase = .airborne
        airPhaseStart = CACurrentMediaTime()
        maxAirTime = 2.6 + jumpHeight * 0.9
        rotationTarget = 0.5 + selectedTrick.complexity * 0.5

        let difficulty = selectedTrick.complexity
        let dd = dunkDifficulty
        let landGreenWidth = max(0.18, 0.36 - dd * 0.06)
        let landCenter = 0.5 + Double.random(in: -0.04...0.04)
        landingGreenZone = max(0, landCenter - landGreenWidth / 2)...min(1, landCenter + landGreenWidth / 2)
        landingTimingSpeed = 2.0 + difficulty * 0.4
    }

    mutating func updateAirborne(delta: Double) {
        if phase == .landing {
            landingTiming += landingTimingDirection * landingTimingSpeed * delta
            if landingTiming >= 1.0 { landingTimingDirection = -1 }
            if landingTiming <= 0.0 { landingTimingDirection = 1 }
            landingTiming = max(0, min(1, landingTiming))
            return
        }
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

    /// Best single-dunk score this session (for practice display).
    var bestDunkScore: Int {
        roundScores.map(\.score).max() ?? 0
    }
}
