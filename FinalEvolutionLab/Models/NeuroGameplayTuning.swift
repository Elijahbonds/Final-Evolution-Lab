import Foundation

/// Bonds-standard style neuro scalars for UE ``GameState`` tuning (power meter, karate impact).
/// Derived from biomechanical audit + efficiency proxy until full pose mesh fills ``BiomechanicsStabilitySnapshot``.
nonisolated enum NeuroGameplayTuning {
    /// 0…1 — higher means more kinetic fault signal from the audit proxy.
    static func kineticLeakageComposite01(audit: BiomechanicsAudit?) -> Double {
        guard let audit else { return 0.12 }
        return min(1.0, max(0.0, audit.leakagePercentage / 100.0))
    }

    /// 0…1 — IAP / trunk stability proxy (efficiency + neural drive until pose IAP scalar exists).
    static func iapStability01(metrics: PerformanceMetrics) -> Double {
        let e = min(1.0, max(0.0, metrics.efficiencyScore / 100.0))
        let n = min(1.0, max(0.0, metrics.neuralDrive / 100.0))
        return min(1.0, max(0.15, 0.55 * e + 0.45 * n))
    }

    /// Drives dunk **power meter** scale (Basketball_Dunk).
    static func powerMeterScale01(mode: GameModeId, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) -> Double {
        guard mode == .basketballDunkContest else { return 1.0 }
        let leak = kineticLeakageComposite01(audit: audit)
        let iap = iapStability01(metrics: metrics)
        let prqN = min(1.0, max(0.0, metrics.prqScore / 100.0))
        let raw = 0.42 + 0.58 * prqN * iap * (1.0 - 0.45 * leak)
        return min(1.35, max(0.25, raw))
    }

    /// Drives **impact force** scale (Karate_Endless / karate sparring).
    static func karateImpactScale01(mode: GameModeId, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) -> Double {
        guard mode == .karateEndless || mode == .karate else { return 1.0 }
        let leak = kineticLeakageComposite01(audit: audit)
        let iap = iapStability01(metrics: metrics)
        let prqN = min(1.0, max(0.0, metrics.prqScore / 100.0))
        let raw = 0.48 + 0.52 * prqN * iap * (1.0 - 0.38 * leak)
        return min(1.28, max(0.3, raw))
    }

    static func jsonDictionary(
        arenaGameModeId: String,
        audit: BiomechanicsAudit?,
        metrics: PerformanceMetrics,
        mode: GameModeId
    ) -> [String: Any] {
        let leak = kineticLeakageComposite01(audit: audit)
        let iap = iapStability01(metrics: metrics)
        return [
            "type": "fel_neuro_gameplay",
            "schemaVersion": 1,
            "arenaGameModeId": arenaGameModeId,
            "kineticLeakageComposite01": leak,
            "iapStability01": iap,
            "powerMeterScale01": powerMeterScale01(mode: mode, audit: audit, metrics: metrics),
            "karateImpactScale01": karateImpactScale01(mode: mode, audit: audit, metrics: metrics),
        ]
    }
}
