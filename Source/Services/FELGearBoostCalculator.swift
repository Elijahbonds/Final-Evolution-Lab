import Foundation

/// Mirrors `FELArenaDifficultyScaling::CalculateGearBoost` — aggregate jersey + shoes + outfit for Swift PRQ + `readiness_snapshot.json`.
enum FELGearBoostCalculator {
    struct GearMultipliers: Sendable {
        var motionWarp: Double = 1.0
        var jumpVelocity: Double = 1.0
    }

    /// Single-gear id (e.g. `gear_jersey_cyan_pulse`, `outfit_gold`).
    static func multipliers(forGearId gearId: String) -> GearMultipliers {
        let id = gearId.lowercased()
        var m = GearMultipliers()
        if id.contains("jersey_cyan") || id.contains("gear_jersey_cyan") {
            m.motionWarp = 1.03
            m.jumpVelocity = 1.02
        } else if id.contains("shoes_signal") || id.contains("gear_shoes_signal") {
            m.motionWarp = 1.02
            m.jumpVelocity = 1.04
        } else if id.contains("outfit_neon") || id == "neon" || id.contains("neon") {
            m.motionWarp = 1.02
            m.jumpVelocity = 1.02
        } else if id.contains("outfit_gold") || id.contains("gold") {
            m.motionWarp = 1.05
            m.jumpVelocity = 1.05
        }
        return m
    }

    /// Stacks exclusive gear (by `ShopItem.id` resolved from texture path) + outfit string from `PerformanceMetrics.currentOutfit`.
    static func aggregatedMultipliers(profile: UserProfile) -> GearMultipliers {
        var out = GearMultipliers()
        func apply(_ g: GearMultipliers) {
            out.motionWarp *= g.motionWarp
            out.jumpVelocity *= g.jumpVelocity
        }
        if let path = profile.equippedGearTexturePaths["jersey"],
           let item = ShopCatalog.items.first(where: { $0.unrealGearTexturePath == path }) {
            apply(multipliers(forGearId: item.id))
        }
        if let path = profile.equippedGearTexturePaths["shoes"],
           let item = ShopCatalog.items.first(where: { $0.unrealGearTexturePath == path }) {
            apply(multipliers(forGearId: item.id))
        }
        let outfit = profile.metrics.currentOutfit
        if !outfit.isEmpty {
            apply(multipliers(forGearId: outfit))
        }
        out.motionWarp = min(max(out.motionWarp, 1.0), 1.06)
        out.jumpVelocity = min(max(out.jumpVelocity, 1.0), 1.06)
        return out
    }

    /// Small PRQ points for HUD / “Effective PRQ” before sending to Unreal.
    static func gearPrqPoints(profile: UserProfile) -> Double {
        let g = aggregatedMultipliers(profile: profile)
        let delta = (g.motionWarp - 1.0) * 50.0 + (g.jumpVelocity - 1.0) * 50.0
        return min(3.0, max(0, delta))
    }

    // MARK: - Sovereign skins → kinetic leakage (1–5% reduction vs scan baseline)

    private static func skinLeakageFactor(gearId: String) -> Double {
        let id = gearId.lowercased()
        if id.contains("jersey_cyan") || id.contains("gear_jersey_cyan") { return 0.98 }
        if id.contains("shoes_signal") || id.contains("gear_shoes_signal") { return 0.99 }
        if id.contains("outfit_neon") || id.contains("neon") { return 0.99 }
        if id.contains("outfit_gold") || id.contains("gold") { return 0.95 }
        if id.contains("outfit_shadow") { return 0.995 }
        if id.contains("outfit_chrome") { return 0.992 }
        return 1.0
    }

    /// Multiplier in (0.95…1.0] — multiply with audit-derived leakage for “Sovereign Gear” damage reduction.
    static func sovereignKineticLeakageScale(profile: UserProfile) -> Double {
        var product = 1.0
        var any = false
        if let path = profile.equippedGearTexturePaths["jersey"],
           let item = ShopCatalog.items.first(where: { $0.unrealGearTexturePath == path }) {
            product *= skinLeakageFactor(gearId: item.id)
            any = true
        }
        if let path = profile.equippedGearTexturePaths["shoes"],
           let item = ShopCatalog.items.first(where: { $0.unrealGearTexturePath == path }) {
            product *= skinLeakageFactor(gearId: item.id)
            any = true
        }
        let outfit = profile.metrics.currentOutfit
        if !outfit.isEmpty {
            product *= skinLeakageFactor(gearId: outfit)
            any = true
        }
        guard any else { return 1.0 }
        return max(0.95, min(1.0, product))
    }

    // MARK: - Stood Creator Card → jump / neural (matches `FELArenaDifficultyScaling::StoodCardPhysicsFromId`)

    static func stoodCardPhysics(from active: CreatorCardState?) -> (jump: Double, neuralAlpha: Double) {
        guard let a = active,
              let c = CreatorCard.catalog.first(where: { $0.id == a.cardId }) else { return (1.0, 1.0) }
        let v = c.metricsBoost.verticalPotential
        let nd = c.metricsBoost.neuralDrive
        let jump = 1.0 + min(0.08, v / 1000.0)
        let neural = 1.0 + min(0.15, nd / 100.0 * 0.12)
        return (min(1.12, jump), min(1.15, neural))
    }

    static func stoodCardTierString(for active: CreatorCardState?) -> String {
        guard let a = active,
              let c = CreatorCard.catalog.first(where: { $0.id == a.cardId }) else { return "standard" }
        let score = c.metricsBoost.prqScore + c.metricsBoost.verticalPotential + c.metricsBoost.neuralDrive * 0.5
        if score >= 42 { return "diamond" }
        if score >= 28 { return "gold" }
        return "standard"
    }

    /// Social card: approximate VERT badge from equipped gear jump scale.
    static func verticalBoostPointsFromGear(profile: UserProfile) -> Int {
        let g = aggregatedMultipliers(profile: profile)
        return max(0, Int(round((g.jumpVelocity - 1.0) * 100.0)))
    }

    static func neuroFlowIntensityScale(activeCard: CreatorCardState?) -> Double {
        guard let a = activeCard,
              let c = CreatorCard.catalog.first(where: { $0.id == a.cardId }) else { return 1.0 }
        let nd = c.metricsBoost.neuralDrive
        return min(1.2, 1.0 + nd / 100.0 * 0.12)
    }

    static func stoodTraitLine(for active: CreatorCardState?) -> String {
        guard let a = active,
              let c = CreatorCard.catalog.first(where: { $0.id == a.cardId }) else { return "" }
        return "+\(Int(c.metricsBoost.neuralDrive)) NEURAL · \(c.title)"
    }

    /// Unreal `EFELSignatureTrait` / `readiness_snapshot.json` key `signature_trait_id`.
    static func signatureTraitId(for active: CreatorCardState?) -> String? {
        guard let a = active,
              let c = CreatorCard.catalog.first(where: { $0.id == a.cardId }) else { return nil }
        return c.signatureTraitId
    }

    /// Athlete Card + marketplace: short “Neuro-Mechanic” lines.
    static func displayBoostLines(profile: UserProfile) -> [String] {
        let g = aggregatedMultipliers(profile: profile)
        var lines: [String] = []
        if g.motionWarp > 1.001 {
            lines.append("MAG +\(Int(round((g.motionWarp - 1.0) * 100)))%")
        }
        let vertPts = verticalBoostPointsFromGear(profile: profile)
        if vertPts >= 3 {
            lines.append("+\(vertPts) VERT")
        } else if g.jumpVelocity > 1.001 {
            lines.append("VERT +\(Int(round((g.jumpVelocity - 1.0) * 100)))%")
        }
        if let card = profile.activeCreatorCard,
           let c = CreatorCard.catalog.first(where: { $0.id == card.cardId }) {
            lines.append("+\(Int(c.metricsBoost.prqScore)) PRQ")
        }
        return lines
    }
}
