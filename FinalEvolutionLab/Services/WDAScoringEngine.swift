import Foundation

/// Defines the difficulty and trick complexity levels for WDA/FIBA dunk scoring.
public enum DunkTrickComplexity: String, Codable, CaseIterable, Sendable {
    case rimGrazer = "Rim Grazer"
    case windmill = "Windmill"
    case betweenTheLegs = "Between-the-Legs (Eastbay)"
    case threeSixty = "360 Spin"
    case doubleClutch = "Double Clutch"
    case honeyDip = "Honey Dip (Elbow in Rim)"
    case freeThrowLine = "Free Throw Line Flight"
    case behindTheBack = "Behind-the-Back"
    case seventyTwo0 = "720 Spin"
    
    var baseDifficultyScore: Double {
        switch self {
        case .rimGrazer: return 12.0
        case .doubleClutch: return 16.0
        case .windmill: return 20.0
        case .honeyDip: return 22.0
        case .threeSixty: return 24.0
        case .freeThrowLine: return 26.0
        case .behindTheBack: return 28.0
        case .betweenTheLegs: return 29.0
        case .seventyTwo0: return 30.0
        }
    }
    
    var minimumRequiredHeightInches: Double {
        switch self {
        case .rimGrazer: return 20.0
        case .doubleClutch: return 24.0
        case .windmill: return 28.0
        case .honeyDip: return 30.0
        case .threeSixty: return 32.0
        case .freeThrowLine: return 28.0
        case .behindTheBack: return 34.0
        case .betweenTheLegs: return 36.0
        case .seventyTwo0: return 40.0
        }
    }
}

/// Raw real-time tracking metrics measured during a dunk attempt.
public struct DunkAttemptMetrics: Codable, Sendable {
    public var jumpHeightInches: Double
    public var takeoffAngleDegrees: Double
    public var takeoffVelocityFps: Double // Feet per second
    public var flightHangTimeSeconds: Double
    public var ballRotationDegrees: Double
    public var trick: DunkTrickComplexity
    public var attemptsCount: Int // Number of physical attempts within the 75s window
    public var timeSpentSeconds: Double // Duration of the current run/attempt
    
    // Artistic/Style metrics
    public var fluidMotionScore: Double // 1.0 - 10.0
    public var landingControlScore: Double // 1.0 - 10.0
    public var aestheticImpactScore: Double // 1.0 - 10.0
    
    // Safety & Biomechanical indicators
    public var kneeValgusDetected: Bool // True if knee buckles inwards on landing
    public var anklePronationDetected: Bool // True if ankle pronates on landing
    
    public init(
        jumpHeightInches: Double = 0.0,
        takeoffAngleDegrees: Double = 0.0,
        takeoffVelocityFps: Double = 0.0,
        flightHangTimeSeconds: Double = 0.0,
        ballRotationDegrees: Double = 0.0,
        trick: DunkTrickComplexity = .rimGrazer,
        attemptsCount: Int = 1,
        timeSpentSeconds: Double = 0.0,
        fluidMotionScore: Double = 5.0,
        landingControlScore: Double = 5.0,
        aestheticImpactScore: Double = 5.0,
        kneeValgusDetected: Bool = false,
        anklePronationDetected: Bool = false
    ) {
        self.jumpHeightInches = jumpHeightInches
        self.takeoffAngleDegrees = takeoffAngleDegrees
        self.takeoffVelocityFps = takeoffVelocityFps
        self.flightHangTimeSeconds = flightHangTimeSeconds
        self.ballRotationDegrees = ballRotationDegrees
        self.trick = trick
        self.attemptsCount = attemptsCount
        self.timeSpentSeconds = timeSpentSeconds
        self.fluidMotionScore = fluidMotionScore
        self.landingControlScore = landingControlScore
        self.aestheticImpactScore = aestheticImpactScore
        self.kneeValgusDetected = kneeValgusDetected
        self.anklePronationDetected = anklePronationDetected
    }
}

/// Detailed results of the WDA/FIBA scoring computation.
public struct DunkScoringResult: Codable, Sendable {
    public let metrics: DunkAttemptMetrics
    
    // Breakdowns
    public let executionScore: Double // Max 30
    public let artisticScore: Double // Max 10
    public let firstTrySuccessScore: Double // Max 10
    public let timePenalty: Double
    public let totalScore: Double // Max 50
    
    // Descriptive Feedback
    public let judgesCommentary: String
    public let feedbackBullets: [String]
    public let isValid: Bool
    
    // Personalized Judges Commentary
    public var randyCommentary: String = ""
    public var dominiqueCommentary: String = ""
    public var lisaCommentary: String = ""

    public init(
        metrics: DunkAttemptMetrics,
        executionScore: Double,
        artisticScore: Double,
        firstTrySuccessScore: Double,
        timePenalty: Double,
        totalScore: Double,
        judgesCommentary: String,
        feedbackBullets: [String],
        isValid: Bool,
        randyCommentary: String = "",
        dominiqueCommentary: String = "",
        lisaCommentary: String = ""
    ) {
        self.metrics = metrics
        self.executionScore = executionScore
        self.artisticScore = artisticScore
        self.firstTrySuccessScore = firstTrySuccessScore
        self.timePenalty = timePenalty
        self.totalScore = totalScore
        self.judgesCommentary = judgesCommentary
        self.feedbackBullets = feedbackBullets
        self.isValid = isValid
        self.randyCommentary = randyCommentary
        self.dominiqueCommentary = dominiqueCommentary
        self.lisaCommentary = lisaCommentary
    }

    /// WDA rubric breakdown mapped to the three-judge panel (execution / style / attempt).
    public var judgePanelScores: (j1: Int, j2: Int, j3: Int) {
        (
            Int(executionScore.rounded(.toNearestOrAwayFromZero)),
            Int(artisticScore.rounded(.toNearestOrAwayFromZero)),
            Int(firstTrySuccessScore.rounded(.toNearestOrAwayFromZero))
        )
    }

    public var wdaCrowdMessage: String {
        if totalScore >= 45 { return "PERFECT DUNK!" }
        if totalScore >= 42 { return "LEGENDARY!" }
        if totalScore >= 40 { return "CROWD GOES WILD!" }
        if totalScore >= 38 { return "ELECTRIFYING!" }
        if totalScore >= 35 { return "POWERFUL!" }
        if totalScore >= 30 { return "SOLID DUNK" }
        return "NEEDS WORK"
    }
}

/// Input channel for the shared WDA/FIBA scoring API.
public enum DunkScoringChannel: String, Codable, Sendable {
    case irlBiomechanical = "irl"
    case engine3D = "engine_3d"
}

/// IRL dunk capture — biomechanical telemetry from recorded pose / camera tracking.
public struct DunkIRLScoringInput: Sendable {
    public var jumpHeightInches: Double
    public var takeoffAngleDegrees: Double
    public var takeoffVelocityFps: Double
    public var flightHangTimeSeconds: Double
    public var ballRotationDegrees: Double
    public var trick: DunkTrickComplexity
    public var attemptsCount: Int
    public var timeSpentSeconds: Double
    public var fluidMotionScore: Double
    public var landingControlScore: Double
    public var aestheticImpactScore: Double
    public var kneeValgusDetected: Bool
    public var anklePronationDetected: Bool
    public var signatureAnimationId: String?
    public var signatureAnimationName: String?
    public var signatureDifficultyBonus: Double?

    public init(
        jumpHeightInches: Double,
        takeoffAngleDegrees: Double,
        takeoffVelocityFps: Double,
        flightHangTimeSeconds: Double,
        ballRotationDegrees: Double,
        trick: DunkTrickComplexity,
        attemptsCount: Int = 1,
        timeSpentSeconds: Double = 0,
        fluidMotionScore: Double = 5,
        landingControlScore: Double = 5,
        aestheticImpactScore: Double = 5,
        kneeValgusDetected: Bool = false,
        anklePronationDetected: Bool = false,
        signatureAnimationId: String? = nil,
        signatureAnimationName: String? = nil,
        signatureDifficultyBonus: Double? = nil
    ) {
        self.jumpHeightInches = jumpHeightInches
        self.takeoffAngleDegrees = takeoffAngleDegrees
        self.takeoffVelocityFps = takeoffVelocityFps
        self.flightHangTimeSeconds = flightHangTimeSeconds
        self.ballRotationDegrees = ballRotationDegrees
        self.trick = trick
        self.attemptsCount = attemptsCount
        self.timeSpentSeconds = timeSpentSeconds
        self.fluidMotionScore = fluidMotionScore
        self.landingControlScore = landingControlScore
        self.aestheticImpactScore = aestheticImpactScore
        self.kneeValgusDetected = kneeValgusDetected
        self.anklePronationDetected = anklePronationDetected
        self.signatureAnimationId = signatureAnimationId
        self.signatureAnimationName = signatureAnimationName
        self.signatureDifficultyBonus = signatureDifficultyBonus
    }
}

/// 3D engine dunk event — arcade contest state or NEXUS C++ `dunk_details` payload.
public struct DunkEngine3DScoringInput: Sendable {
    public var jumpHeight: Double
    public var launchQuality: Double
    public var landingQuality: Double
    public var completedRotation: Double
    public var trick: DunkTrickComplexity
    public var ballRotationDegrees: Double?
    public var flightHangTimeSeconds: Double?
    public var attemptsCount: Int
    public var timeSpentSeconds: Double
    public var freestylePoints: Int
    public var midAirBranchCount: Int
    public var styleLandingSuccess: Bool
    public var modifierScoreMultiplier: Double
    public var kneeValgusDetected: Bool
    public var anklePronationDetected: Bool
    public var signatureAnimationId: String?
    public var signatureAnimationName: String?
    public var signatureDifficultyBonus: Double?

    public init(
        jumpHeight: Double,
        launchQuality: Double,
        landingQuality: Double,
        completedRotation: Double,
        trick: DunkTrickComplexity,
        ballRotationDegrees: Double? = nil,
        flightHangTimeSeconds: Double? = nil,
        attemptsCount: Int = 1,
        timeSpentSeconds: Double = 0,
        freestylePoints: Int = 0,
        midAirBranchCount: Int = 0,
        styleLandingSuccess: Bool = false,
        modifierScoreMultiplier: Double = 1.0,
        kneeValgusDetected: Bool = false,
        anklePronationDetected: Bool = false,
        signatureAnimationId: String? = nil,
        signatureAnimationName: String? = nil,
        signatureDifficultyBonus: Double? = nil
    ) {
        self.jumpHeight = jumpHeight
        self.launchQuality = launchQuality
        self.landingQuality = landingQuality
        self.completedRotation = completedRotation
        self.trick = trick
        self.ballRotationDegrees = ballRotationDegrees
        self.flightHangTimeSeconds = flightHangTimeSeconds
        self.attemptsCount = attemptsCount
        self.timeSpentSeconds = timeSpentSeconds
        self.freestylePoints = freestylePoints
        self.midAirBranchCount = midAirBranchCount
        self.styleLandingSuccess = styleLandingSuccess
        self.modifierScoreMultiplier = modifierScoreMultiplier
        self.kneeValgusDetected = kneeValgusDetected
        self.anklePronationDetected = anklePronationDetected
        self.signatureAnimationId = signatureAnimationId
        self.signatureAnimationName = signatureAnimationName
        self.signatureDifficultyBonus = signatureDifficultyBonus
    }
}

/// A specialized scoring engine implementing WDA and FIBA 3x3 Dunk Contest rules.
public final class WDAScoringEngine: Sendable {
    
    public static let shared = WDAScoringEngine()
    
    public static let fibaTimeLimitSeconds: Double = 75.0
    
    private init() {}

    /// IRL biomechanical path — recorded pose / camera telemetry.
    nonisolated public func scoreIRLDunk(input: DunkIRLScoringInput) -> DunkScoringResult {
        scoreDunk(
            metrics: Self.adaptIRL(input),
            signatureAnimationId: input.signatureAnimationId,
            signatureAnimationName: input.signatureAnimationName,
            signatureDifficultyBonus: input.signatureDifficultyBonus
        )
    }

    /// 3D engine path — arcade contest state or NEXUS dunk event payload.
    nonisolated public func scoreEngine3DDunk(input: DunkEngine3DScoringInput) -> DunkScoringResult {
        scoreDunk(
            metrics: Self.adaptEngine3D(input),
            signatureAnimationId: input.signatureAnimationId,
            signatureAnimationName: input.signatureAnimationName,
            signatureDifficultyBonus: input.signatureDifficultyBonus
        )
    }

    nonisolated public static func adaptIRL(_ input: DunkIRLScoringInput) -> DunkAttemptMetrics {
        DunkAttemptMetrics(
            jumpHeightInches: input.jumpHeightInches,
            takeoffAngleDegrees: input.takeoffAngleDegrees,
            takeoffVelocityFps: input.takeoffVelocityFps,
            flightHangTimeSeconds: input.flightHangTimeSeconds,
            ballRotationDegrees: input.ballRotationDegrees,
            trick: input.trick,
            attemptsCount: input.attemptsCount,
            timeSpentSeconds: input.timeSpentSeconds,
            fluidMotionScore: input.fluidMotionScore,
            landingControlScore: input.landingControlScore,
            aestheticImpactScore: input.aestheticImpactScore,
            kneeValgusDetected: input.kneeValgusDetected,
            anklePronationDetected: input.anklePronationDetected
        )
    }

    nonisolated public static func adaptEngine3D(_ input: DunkEngine3DScoringInput) -> DunkAttemptMetrics {
        let jumpHeightInches = input.jumpHeight * 42.0 + input.trick.minimumRequiredHeightInches * 0.12
        let takeoffVelocityFps = 10.0 + input.jumpHeight * 14.0 + input.launchQuality * 4.0
        let hangTime = input.flightHangTimeSeconds
            ?? (0.45 + input.jumpHeight * 0.85 + input.completedRotation * 0.25)
        let rotationDegrees = input.ballRotationDegrees ?? (input.completedRotation * 360.0)
        let freestyleNorm = min(10.0, 5.0 + Double(min(input.freestylePoints, 30)) / 6.0)
        let chainBonus = min(2.0, Double(input.midAirBranchCount) * 0.5)
        let modifierBonus = max(0, (input.modifierScoreMultiplier - 1.0) * 4.0)
        let fluidMotion = min(10.0, max(1.0, input.launchQuality * 9.0 + modifierBonus + chainBonus * 0.5))
        let landingControl = min(10.0, max(1.0, input.landingQuality * 10.0))
        let aesthetic = min(
            10.0,
            max(1.0, freestyleNorm + chainBonus + (input.styleLandingSuccess ? 1.5 : 0))
        )

        return DunkAttemptMetrics(
            jumpHeightInches: jumpHeightInches,
            takeoffAngleDegrees: 72.0 + input.launchQuality * 12.0,
            takeoffVelocityFps: takeoffVelocityFps,
            flightHangTimeSeconds: hangTime,
            ballRotationDegrees: rotationDegrees,
            trick: input.trick,
            attemptsCount: input.attemptsCount,
            timeSpentSeconds: input.timeSpentSeconds,
            fluidMotionScore: fluidMotion,
            landingControlScore: landingControl,
            aestheticImpactScore: aesthetic,
            kneeValgusDetected: input.kneeValgusDetected,
            anklePronationDetected: input.anklePronationDetected
        )
    }

    /// Adapts a NEXUS C++ `mode_state.dunk.dunk_details[]` entry into WDA metrics.
    nonisolated public static func adaptEngine3D(
        dunkEvent: [String: Any],
        chargePower: Double = 0.5,
        attemptsCount: Int = 1,
        timeSpentSeconds: Double = 0,
        signatureAnimationId: String? = nil,
        signatureDifficultyBonus: Double? = nil
    ) -> DunkEngine3DScoringInput {
        let style = (dunkEvent["style"] as? Int) ?? (dunkEvent["style"] as? NSNumber)?.intValue ?? 0
        let hangTime = (dunkEvent["hang_time"] as? Double)
            ?? (dunkEvent["hang_time"] as? NSNumber)?.doubleValue
            ?? 0.6
        let timingLabel = (dunkEvent["timing_grade"] as? String) ?? "good"
        let timingQuality = timingQuality(fromEngineTimingGrade: timingLabel)

        return DunkEngine3DScoringInput(
            jumpHeight: min(1.0, max(0.15, chargePower)),
            launchQuality: timingQuality,
            landingQuality: timingQuality * 0.92,
            completedRotation: style >= 3 ? 1.0 : (style >= 1 ? 0.65 : 0.35),
            trick: trickComplexity(fromEngineStyle: style),
            flightHangTimeSeconds: hangTime,
            attemptsCount: attemptsCount,
            timeSpentSeconds: timeSpentSeconds,
            modifierScoreMultiplier: styleMultiplier(fromEngineStyle: style),
            signatureAnimationId: signatureAnimationId,
            signatureDifficultyBonus: signatureDifficultyBonus
        )
    }

    nonisolated public static func trickComplexity(fromEngineStyle style: Int) -> DunkTrickComplexity {
        switch style {
        case 3: return .threeSixty
        case 2: return .windmill
        case 1: return .doubleClutch
        default: return .rimGrazer
        }
    }

    nonisolated public static func styleMultiplier(fromEngineStyle style: Int) -> Double {
        switch style {
        case 3: return 1.5
        case 2: return 1.3
        case 1: return 1.2
        default: return 1.0
        }
    }

    nonisolated public static func timingQuality(fromEngineTimingGrade label: String) -> Double {
        switch label.lowercased() {
        case "perfect": return 1.0
        case "great": return 0.85
        case "good": return 0.65
        default: return 0.35
        }
    }
    
    /// Computes the official WDA/FIBA score for a dunk attempt based on telemetry data.
    nonisolated public func scoreDunk(
        metrics: DunkAttemptMetrics,
        signatureAnimationId: String? = nil,
        signatureAnimationName: String? = nil,
        signatureDifficultyBonus: Double? = nil
    ) -> DunkScoringResult {
        // 1. Time Limit Check (Official FIBA 75-second limit per dunk)
        let isTimeExpired = metrics.timeSpentSeconds > Self.fibaTimeLimitSeconds
        let timePenalty: Double
        if isTimeExpired {
            // Apply severe deduction if they went overtime
            let overSeconds = metrics.timeSpentSeconds - Self.fibaTimeLimitSeconds
            timePenalty = min(10.0, 3.0 + (overSeconds * 0.25)) // 3pt base + scaling overtime penalty
        } else {
            timePenalty = 0.0
        }
        
        // 2. Execution & Difficulty (10.0 - 30.0 pts)
        // Base is derived from the trick difficulty, scaled based on vertical performance
        var rawExecution = metrics.trick.baseDifficultyScore
        
        // Apply signature animation difficulty bonus if provided
        if let bonus = signatureDifficultyBonus {
            rawExecution += bonus
        }
        
        // Add performance bonuses
        // Vertical Impulse Bonus
        if metrics.jumpHeightInches >= metrics.trick.minimumRequiredHeightInches {
            let extraHeight = metrics.jumpHeightInches - metrics.trick.minimumRequiredHeightInches
            rawExecution += min(3.0, extraHeight * 0.15) // Up to +3.0 pts for clearing reqs
        } else {
            let deficitHeight = metrics.trick.minimumRequiredHeightInches - metrics.jumpHeightInches
            rawExecution -= min(4.0, deficitHeight * 0.2) // Up to -4.0 pts for under-jumping the difficulty tier
        }
        
        // Takeoff Impulse Bonus (Velocity)
        if metrics.takeoffVelocityFps > 12.0 {
            rawExecution += min(1.0, (metrics.takeoffVelocityFps - 12.0) * 0.1)
        }
        
        // Flight Hang Time Bonus
        if metrics.flightHangTimeSeconds > 0.8 {
            rawExecution += min(1.5, (metrics.flightHangTimeSeconds - 0.8) * 3.0)
        }
        
        // Ball Rotation / Trick Amplification
        if metrics.ballRotationDegrees >= 360 {
            rawExecution += 1.5
        } else if metrics.ballRotationDegrees >= 180 {
            rawExecution += 0.75
        }
        
        let executionScore = min(30.0, max(10.0, rawExecution))
        
        // 3. Artistic Expression & Style (1.0 - 10.0 pts)
        // Average of visual and aesthetic inputs
        let baseArtistic = (metrics.fluidMotionScore + metrics.landingControlScore + metrics.aestheticImpactScore) / 3.0
        var rawArtistic = min(10.0, max(1.0, baseArtistic))
        
        // Apply biomechanical landing safety/style deductions
        var feedbackBullets: [String] = []
        if metrics.kneeValgusDetected {
            rawArtistic -= 1.5
            feedbackBullets.append("Biomechanical Warning: Knee valgus (buckling) detected on landing (-1.5 Style pts). Work on lateral glute stability.")
        }
        if metrics.anklePronationDetected {
            rawArtistic -= 1.0
            feedbackBullets.append("Biomechanical Warning: Severe ankle pronation on landing (-1.0 Style pts). Verify shoe support or ankle flexion.")
        }
        
        let artisticScore = min(10.0, max(1.0, rawArtistic))
        
        // 4. First-Try Success (1.0 - 10.0 pts)
        // Official WDA rules reward dunks completed on the first attempt
        let firstTrySuccessScore: Double
        switch metrics.attemptsCount {
        case 1:
            firstTrySuccessScore = 10.0
            feedbackBullets.append("First-Try Clean Success: Maximized attempt efficiency (+10.0 pts).")
        case 2:
            firstTrySuccessScore = 7.0
            feedbackBullets.append("Second-Try Completion: -3.0 pts deduction.")
        case 3:
            firstTrySuccessScore = 4.0
            feedbackBullets.append("Third-Try Completion: -6.0 pts deduction.")
        default:
            firstTrySuccessScore = 1.0
            feedbackBullets.append("Multiple Misses/Attempts: Minimum success rating (-9.0 pts deduction).")
        }
        
        // 5. Total Score calculation
        let rawTotal = executionScore + artisticScore + firstTrySuccessScore - timePenalty
        let totalScore = min(50.0, max(0.0, rawTotal))
        
        // Feedback and Judges Commentary Generation
        let levelOfDunk: String
        if totalScore >= 45.0 {
            levelOfDunk = "HISTORIC. World-class vertical extension, extreme trick complexity, and elite landing mechanics."
        } else if totalScore >= 38.0 {
            levelOfDunk = "EXCELLENT. High-flying athletic showcase. A top-tier WDA tournament performance."
        } else if totalScore >= 30.0 {
            levelOfDunk = "SOLID. Strong execution. Increase hang time or rotational degrees to push for elite scores."
        } else if totalScore >= 20.0 {
            levelOfDunk = "DEVELOPING. Decent launch mechanics. Work on landing control and completing tricks on the first attempt."
        } else {
            levelOfDunk = "QUALIFYING. Requires focus on core takeoff explosive velocity and knee landing mechanics."
        }
        
        // Add specific metric highlights to feedback
        feedbackBullets.append("Max Vertical Reach: \(String(format: "%.1f", metrics.jumpHeightInches)) inches")
        feedbackBullets.append("Flight Hang Time: \(String(format: "%.2f", metrics.flightHangTimeSeconds)) seconds")
        feedbackBullets.append("Explosive Takeoff Velocity: \(String(format: "%.1f", metrics.takeoffVelocityFps)) ft/s")
        
        if timePenalty > 0 {
            feedbackBullets.append("FIBA Overtime Penalty: -\(String(format: "%.1f", timePenalty)) pts for exceeding the 75s run limit.")
        }
        
        let comment = "WDA Judges' Consensus: \(levelOfDunk) Execution: \(String(format: "%.1f", executionScore))/30, Style: \(String(format: "%.1f", artisticScore))/10, Attempt: \(String(format: "%.1f", firstTrySuccessScore))/10."
        
        let animName = signatureAnimationName ?? "Standard Preset"
        let randyComment: String
        if let bonus = signatureDifficultyBonus {
            randyComment = "Randy: \"That custom \(animName) is pure box office! A difficulty bonus of \(String(format: "%.1f", bonus)) is well deserved.\""
        } else {
            randyComment = "Randy: \"Solid execution of a standard pattern. Let's see some custom mocap flair next time!\""
        }
        
        let dominiqueComment: String
        if signatureAnimationId != nil {
            dominiqueComment = "Dominique: \"Man, the style on that \(animName) was crazy! The keyframe flow was so fluid.\""
        } else if metrics.ballRotationDegrees >= 180 {
            dominiqueComment = "Dominique: \"That \(Int(metrics.ballRotationDegrees)) degree rotation in mid-air was beautiful. Pure art!\""
        } else {
            dominiqueComment = "Dominique: \"Nice power, but we need more rotational flair or custom keyframe styling!\""
        }
        
        let lisaComment: String
        if metrics.kneeValgusDetected || metrics.anklePronationDetected {
            lisaComment = "Lisa: \"Warning! Biomechanics alert on landing. Knee/ankle instability detected. Safety first!\""
        } else {
            lisaComment = "Lisa: \"Impeccable landing control! Perfect biomechanics and knee alignment on impact.\""
        }
        
        return DunkScoringResult(
            metrics: metrics,
            executionScore: executionScore,
            artisticScore: artisticScore,
            firstTrySuccessScore: firstTrySuccessScore,
            timePenalty: timePenalty,
            totalScore: totalScore,
            judgesCommentary: comment,
            feedbackBullets: feedbackBullets,
            isValid: !isTimeExpired || totalScore > 10.0,
            randyCommentary: randyComment,
            dominiqueCommentary: dominiqueComment,
            lisaCommentary: lisaComment
        )
    }
}
