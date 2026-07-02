import Foundation

enum FELFeatureFlags {
    static var enableNeurocognitiveEngine: Bool = false
}

struct HRVSample: Sendable {
    let timestamp: TimeInterval
    let rrIntervalMs: Double
}

struct TierAResult: Sendable {
    let arv: Double
    let modifier: Double
}

struct TierBResult: Sendable {
    let esi: Double
    let modifier: Double
}

struct TierCResult: Sendable {
    let pacingScore: Double
    let modifier: Double
}

struct MRIResult: Sendable {
    let mri: Double
    let tierA: TierAResult
    let tierB: TierBResult
    let tierC: TierCResult
}

struct SessionMetrics: Sendable {
    let hrvSamples: [HRVSample]
    let contextSwitchCount: Int
    let errorCount: Int
    let inputLagSamples: [Double]
    let smartPauseCount: Int
    let forcedRecoveryCount: Int
    let totalPauseEvents: Int
}

class MentalResiliencyEngine: @unchecked Sendable {
    static let shared = MentalResiliencyEngine()

    func computeTierA(_ m: SessionMetrics) -> TierAResult {
        guard FELFeatureFlags.enableNeurocognitiveEngine else { return TierAResult(arv: 0.5, modifier: 1.0) }
        let rmssd = calcRMSSD(m.hrvSamples)
        let arv   = min(1.0, max(0.0, rmssd / 100.0))
        return TierAResult(arv: arv, modifier: 0.5 + arv * 1.0)
    }

    func computeTierB(_ m: SessionMetrics) -> TierBResult {
        guard FELFeatureFlags.enableNeurocognitiveEngine else { return TierBResult(esi: 50.0, modifier: 1.0) }
        let csf = min(100.0, Double(m.contextSwitchCount) * 5.0)
        let eef = min(100.0, Double(m.errorCount) * 10.0)
        let ild = m.inputLagSamples.isEmpty ? 0.0 : min(100.0, m.inputLagSamples.reduce(0,+) / Double(m.inputLagSamples.count))
        let esi = (csf + eef + ild) / 3.0
        return TierBResult(esi: esi, modifier: 0.8 + ((100.0 - esi) / 100.0) * 0.4)
    }

    func computeTierC(_ m: SessionMetrics) -> TierCResult {
        guard FELFeatureFlags.enableNeurocognitiveEngine else { return TierCResult(pacingScore: 50.0, modifier: 1.0) }
        let total = m.smartPauseCount + m.forcedRecoveryCount
        let ps    = total == 0 ? 50.0 : (Double(m.smartPauseCount) / Double(total)) * 100.0
        return TierCResult(pacingScore: ps, modifier: 0.85 + (ps / 100.0) * 0.30)
    }

    func calculateMRI(_ m: SessionMetrics) -> MRIResult {
        let a = computeTierA(m); let b = computeTierB(m); let c = computeTierC(m)
        return MRIResult(mri: a.arv * 0.40 + (100.0 - b.esi) * 0.35 + c.pacingScore * 0.25, tierA: a, tierB: b, tierC: c)
    }

    private func calcRMSSD(_ s: [HRVSample]) -> Double {
        guard s.count > 1 else { return 50.0 }
        var sum = 0.0
        for i in 1..<s.count { let d = s[i].rrIntervalMs - s[i-1].rrIntervalMs; sum += d * d }
        return sqrt(sum / Double(s.count - 1))
    }
}
