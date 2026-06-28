import Foundation

nonisolated struct DefensivePhysics: Sendable {
    static let bodyUpRadius: Double = 1.4
    static let bodyUpDecelerateFactor: Double = 0.35
    static let bodyUpMoveThresholdSq: Double = 0.25

    static let clampAngleDeg: Double = 45

    static let quickProtectDurationSeconds: Double = 1.2
    static let quickProtectSpeedMultiplier: Double = 0.75

    static let contestProximityMax: Double = 40
    static let contestHandsUpBonus: Double = 60
    static let smotheredDistance: Double = 1.2
    static let contestMaxDistance: Double = 6.0

    static let blockApexWindowSeconds: Double = DunkPhysicsConfig.qteWindowSeconds

    static func lateralQuicknessScale(perimeterDefense: Double) -> Double {
        let p = min(max(perimeterDefense, 0), 100)
        return 0.6 + (p / 100.0) * 0.7
    }

    static func contestPercent(distance: Double, handsUp: Bool) -> Int {
        let d = max(0, distance)
        guard d < contestMaxDistance else { return 0 }

        let proximityPct: Double
        if d <= smotheredDistance {
            proximityPct = contestProximityMax
        } else {
            proximityPct = contestProximityMax * (1 - (d - smotheredDistance) / (contestMaxDistance - smotheredDistance))
        }

        let handsUpAdd: Double = handsUp
            ? contestHandsUpBonus * (1 - d / contestMaxDistance)
            : 0

        return min(100, Int((proximityPct + handsUpAdd).rounded()))
    }

    static func contestLabel(percent: Int) -> String {
        switch percent {
        case 70...: return "Smothered"
        case 45..<70: return "Heavy Contest"
        case 25..<45: return "Contested"
        case 10..<25: return "Light Contest"
        default: return "Open"
        }
    }

    static func contestShotPenalty(percent: Int) -> Double {
        Double(percent) / 100.0 * 0.5
    }

    static func contestMeterColor(percent: Int) -> ContestTier {
        switch percent {
        case 70...: return .smothered
        case 45..<70: return .heavy
        case 25..<45: return .contested
        case 10..<25: return .light
        default: return .open
        }
    }

    static func checkBodyUp(
        ballHandlerPos: SIMD3<Double>,
        ballHandlerVel: SIMD3<Double>,
        defenderPos: SIMD3<Double>
    ) -> Bool {
        let dx = ballHandlerPos.x - defenderPos.x
        let dz = ballHandlerPos.z - defenderPos.z
        let distSq = dx * dx + dz * dz
        guard distSq <= bodyUpRadius * bodyUpRadius else { return false }
        let velSq = ballHandlerVel.x * ballHandlerVel.x + ballHandlerVel.z * ballHandlerVel.z
        return velSq >= bodyUpMoveThresholdSq
    }

    static func checkClamp(
        offenseDir: SIMD2<Double>,
        defenderDir: SIMD2<Double>
    ) -> Bool {
        let oLen = sqrt(offenseDir.x * offenseDir.x + offenseDir.y * offenseDir.y)
        let dLen = sqrt(defenderDir.x * defenderDir.x + defenderDir.y * defenderDir.y)
        guard oLen > 0.001, dLen > 0.001 else { return false }
        let dot = offenseDir.x * defenderDir.x + offenseDir.y * defenderDir.y
        let cosAngle = dot / (oLen * dLen)
        let clamped = min(1, max(-1, cosAngle))
        let angleDeg = acos(clamped) * 180.0 / .pi
        return angleDeg <= clampAngleDeg
    }

    static func isBlockSuccessful(shooterReleaseTime: Double, defenderApexTime: Double) -> Bool {
        abs(shooterReleaseTime - defenderApexTime) <= blockApexWindowSeconds
    }
}

// MARK: - DefenseGrade

nonisolated enum DefenseGrade: String, Sendable, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
}

// MARK: - HelpDefenseBreakdown

/// Aggregates per-defender coverage scores (0–100) and derives
/// a team help-rotation grade based on their average.
nonisolated struct HelpDefenseBreakdown: Sendable {
    /// Maps player ID to a coverage score in the range 0–100.
    let defenderCoverageScores: [String: Double]

    var averageCoverageScore: Double {
        guard !defenderCoverageScores.isEmpty else { return 0.0 }
        return defenderCoverageScores.values.reduce(0, +) / Double(defenderCoverageScores.count)
    }

    var helpRotationGrade: DefenseGrade {
        switch averageCoverageScore {
        case 90...100: return .a
        case 80..<90:  return .b
        case 70..<80:  return .c
        case 60..<70:  return .d
        default:       return .f
        }
    }
}

nonisolated enum ContestTier: String, Sendable {
    case smothered = "SMOTHERED"
    case heavy = "HEAVY CONTEST"
    case contested = "CONTESTED"
    case light = "LIGHT CONTEST"
    case open = "OPEN"

    var sortOrder: Int {
        switch self {
        case .smothered: return 5
        case .heavy: return 4
        case .contested: return 3
        case .light: return 2
        case .open: return 1
        }
    }
}
