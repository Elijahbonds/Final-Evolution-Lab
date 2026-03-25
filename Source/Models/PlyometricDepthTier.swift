import Foundation

/// Progressive plyometric depth by movement demand — not a person’s name: extensive/regressed → progressed intensity → deep reactive.
nonisolated enum PlyometricDepthTier: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Extensive / regressed — more contacts, lower stress; elasticity and rhythm first.
    case elasticityExtensive = "elasticity_extensive"
    /// Progressed loading — intensity, braking, and stiffness before max rebound.
    case intensityProgressed = "intensity_progressed"
    /// Deep tier — short ground contact, reactive output, max intent.
    case reactiveDeep = "reactive_deep"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .elasticityExtensive: "Ext"
        case .intensityProgressed: "Mid"
        case .reactiveDeep: "Deep"
        }
    }

    /// Human-readable label for dashboards (movement language).
    var movementDescription: String {
        switch self {
        case .elasticityExtensive: "Elasticity — extensive / regressed plyos"
        case .intensityProgressed: "Intensity — progressed plyos"
        case .reactiveDeep: "Reactive — deep-tier plyos"
        }
    }

    /// Maps legacy stored strings from older builds.
    init?(legacyStored: String) {
        let s = legacyStored.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = PlyometricDepthTier(rawValue: s) {
            self = v
            return
        }
        switch s {
        case "Tier 1: Elasticity", "tier1Elasticity", "T1":
            self = .elasticityExtensive
        case "Tier 2: Intensity", "tier2Intensity", "T2":
            self = .intensityProgressed
        case "Tier 3: Reactive", "tier3Reactive", "T3":
            self = .reactiveDeep
        default:
            return nil
        }
    }
}
