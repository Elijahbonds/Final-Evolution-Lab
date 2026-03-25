import Foundation

/// Unreal `FELPRQScanFormula` parity — System Scan PRQ policy (keep in sync with C++).
nonisolated enum FELPRQScanFormula {
    /// Mirrors Unreal `FELPRQScanFormula::ScoreFromVerticalInches` — smoothstep + sqrt blend (non-linear).
    static func scoreFromVerticalInches(_ verticalInches: Double) -> Double {
        guard verticalInches.isFinite, verticalInches >= 0 else { return PRQ.default }
        let v = min(55, max(0, verticalInches))
        let t = (v - 15) / 35
        let s = min(1, max(0, t))
        let smooth = s * s * (3 - 2 * s)
        let neural = sqrt(s + 1e-6)
        let blend = 0.58 * smooth + 0.42 * neural
        return PRQ.clamp(100 * blend)
    }

    /// Core blend aligned with Unreal `ComputePRQ0to100` — single 0–100 readiness (vertical + reactive flight + tier).
    static func computeScanPRQ(verticalInches: Double, flightSeconds: Double, goalTier: Int) -> Double {
        let pqVert = scoreFromVerticalInches(verticalInches)
        let pqFlight = min(100, max(0, flightSeconds * 95))
        let tierBias = Double(goalTier) * 2.5
        var prq = 0.48 * pqVert + 0.42 * pqFlight + tierBias * 0.10
        prq = PRQ.clamp(prq)
        return prq
    }

    static func goalTier(from goal: String?) -> Int {
        guard let g = goal?.lowercased() else { return 0 }
        if g.contains("jump") { return 2 }
        if g.contains("faster") { return 1 }
        if g.contains("power") { return 3 }
        return 0
    }
}
