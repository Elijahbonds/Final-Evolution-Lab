import Foundation

nonisolated enum ShardTransaction: String, Codable, Sendable {
    case workoutComplete
    case gameWin
    case gameDraw
    case gameLoss
    case matchComplete
    case comboBonus
    case criticalHit
    case outfitPurchase
    case blueprintPurchase
    case critiqueRequest
    case critiqueEarning
    case dailyBonus
    case streakBonus
    case achievementUnlock
    // Fuel the Freeway — Photo-to-Shard nutrition
    case mealStructuralRepair   // High leucine/protein
    case mealFascialElasticity  // Collagen / vitamin C
    case mealSignalVelocity     // Hydration / electrolytes
    case congestionCleared      // Movement snack after inflammatory detection
}

nonisolated struct ShardReward: Sendable {
    let amount: Int
    let transaction: ShardTransaction

    static func forGameResult(won: Bool, tied: Bool, combo: Int, criticals: Int) -> [ShardReward] {
        var rewards: [ShardReward] = []

        if won {
            rewards.append(ShardReward(amount: 50, transaction: .gameWin))
        } else if tied {
            rewards.append(ShardReward(amount: 25, transaction: .gameDraw))
        } else {
            rewards.append(ShardReward(amount: 15, transaction: .gameLoss))
        }

        rewards.append(ShardReward(amount: 5, transaction: .matchComplete))

        if combo >= 2 {
            rewards.append(ShardReward(amount: combo * 5, transaction: .comboBonus))
        }

        if criticals > 0 {
            rewards.append(ShardReward(amount: criticals * 10, transaction: .criticalHit))
        }

        return rewards
    }

    static func forWorkout(exercisesCompleted: Int, trackDifficulty: Exercise.Difficulty) -> [ShardReward] {
        let base: Int
        switch trackDifficulty {
        case .foundation: base = 10
        case .flight: base = 15
        case .elite: base = 25
        }
        return [ShardReward(amount: exercisesCompleted * base, transaction: .workoutComplete)]
    }

    /// Fuel the Freeway: shards for logging meals (AI vision or manual). High-grade fuel for CNS and fascia.
    static func forMealLog(
        structuralRepair: Bool,
        fascialElasticity: Bool,
        signalVelocity: Bool,
        hadCongestionCleared: Bool
    ) -> [ShardReward] {
        var rewards: [ShardReward] = []
        if structuralRepair { rewards.append(ShardReward(amount: 5, transaction: .mealStructuralRepair)) }
        if fascialElasticity { rewards.append(ShardReward(amount: 10, transaction: .mealFascialElasticity)) }
        if signalVelocity { rewards.append(ShardReward(amount: 5, transaction: .mealSignalVelocity)) }
        if hadCongestionCleared { rewards.append(ShardReward(amount: 5, transaction: .congestionCleared)) }
        return rewards
    }
}

nonisolated struct ShopItem: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let category: ShopCategory
    let iconName: String
    /// Unreal soft path for Digital Twin skeletal mesh material (jersey / shoes), e.g. `/Game/FEL/.../T_Jersey_Neon`.
    let unrealGearTexturePath: String?
    /// Slot key for `UserProfile.equippedGearTexturePaths` (`jersey`, `shoes`).
    let gearSlot: String?
    /// Neuro-Mechanic copy for marketplace (“kinetic leakage”, warp magnetism, etc.).
    let performanceImpactLabel: String?
    /// Creator Revenue Loop — when set, `FELCreatorRevenueQueue` records a payout slice on purchase.
    let creatorMerchantID: String?
    /// Basis points (10000 = 100%) of `cost` attributed to the creator as shard-equivalent accrual.
    let creatorRevenueShareBps: Int?

    init(
        id: String,
        name: String,
        description: String,
        cost: Int,
        category: ShopCategory,
        iconName: String,
        unrealGearTexturePath: String? = nil,
        gearSlot: String? = nil,
        performanceImpactLabel: String? = nil,
        creatorMerchantID: String? = nil,
        creatorRevenueShareBps: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.cost = cost
        self.category = category
        self.iconName = iconName
        self.unrealGearTexturePath = unrealGearTexturePath
        self.gearSlot = gearSlot
        self.performanceImpactLabel = performanceImpactLabel
        self.creatorMerchantID = creatorMerchantID
        self.creatorRevenueShareBps = creatorRevenueShareBps
    }

    nonisolated enum ShopCategory: String, Sendable, CaseIterable {
        case outfit = "Outfits"
        case blueprint = "Blueprints"
        case critique = "Coaching"
        case exclusiveGear = "Exclusive Gear"
    }
}

struct ShopCatalog {
    static let items: [ShopItem] = [
        ShopItem(
            id: "outfit_neon",
            name: "Neon Flux",
            description: "Electric cyan avatar skin with pulse effects",
            cost: 500,
            category: .outfit,
            iconName: "sparkles",
            performanceImpactLabel: "Motion-warp magnetism +2% · Reduces kinetic leakage ~1%"
        ),
        ShopItem(
            id: "outfit_shadow",
            name: "Shadow Elite",
            description: "Dark matte finish with ember accents",
            cost: 750,
            category: .outfit,
            iconName: "moon.fill",
            performanceImpactLabel: "Recovery cadence +1% (stealth stance)"
        ),
        ShopItem(
            id: "outfit_chrome",
            name: "Chrome V",
            description: "Reflective metallic with blue highlights",
            cost: 1000,
            category: .outfit,
            iconName: "light.max",
            performanceImpactLabel: "Apex camera stability +1% (reflective read)"
        ),
        ShopItem(
            id: "outfit_gold",
            name: "Gold Standard",
            description: "Premium gold plated avatar",
            cost: 2000,
            category: .outfit,
            iconName: "crown.fill",
            performanceImpactLabel: "Elite tier: +5% warp +5% vertical scale"
        ),

        ShopItem(
            id: "bp_vertical",
            name: "Vertical Lab",
            description: "8-week jump training blueprint",
            cost: 300,
            category: .blueprint,
            iconName: "arrow.up.circle.fill",
            performanceImpactLabel: "Structured vertical PRQ pathway"
        ),
        ShopItem(
            id: "bp_speed",
            name: "Speed Matrix",
            description: "Sprint mechanics breakdown",
            cost: 300,
            category: .blueprint,
            iconName: "bolt.circle.fill",
            performanceImpactLabel: "First-step neural drive drills"
        ),
        ShopItem(
            id: "bp_recovery",
            name: "Neural Recovery",
            description: "Advanced CNS recovery protocols",
            cost: 200,
            category: .blueprint,
            iconName: "heart.circle.fill",
            performanceImpactLabel: "Lowers fatigue leakage in Arena sims"
        ),

        ShopItem(
            id: "critique_form",
            name: "Form Critique",
            description: "Expert movement analysis from Coach V",
            cost: 150,
            category: .critique,
            iconName: "eye.fill",
            performanceImpactLabel: "Biomechanics audit — PRQ calibration"
        ),
        ShopItem(
            id: "critique_program",
            name: "Program Review",
            description: "Full training program audit",
            cost: 400,
            category: .critique,
            iconName: "doc.text.magnifyingglass",
            performanceImpactLabel: "Full Neuro-Mechanic stack review"
        ),

        ShopItem(
            id: "gear_jersey_cyan_pulse",
            name: "Cyan Pulse Jersey",
            description: "Neuro-Mechanic broadcast jersey — syncs to Unreal twin",
            cost: 450,
            category: .exclusiveGear,
            iconName: "tshirt.fill",
            unrealGearTexturePath: "/Game/FEL/Characters/Gear/T_Jersey_CyanPulse.T_Jersey_CyanPulse",
            gearSlot: "jersey",
            performanceImpactLabel: "Reduces kinetic leakage ~2% · Motion-warp +3%",
            creatorMerchantID: "FELMerchant_CoachV",
            creatorRevenueShareBps: 1500
        ),
        ShopItem(
            id: "gear_shoes_signal",
            name: "Signal Velocity Kicks",
            description: "Elite traction texture for Lab + Arena",
            cost: 380,
            category: .exclusiveGear,
            iconName: "shoe.fill",
            unrealGearTexturePath: "/Game/FEL/Characters/Gear/T_Shoes_SignalVelocity.T_Shoes_SignalVelocity",
            gearSlot: "shoes",
            performanceImpactLabel: "Jump velocity scale +4% · Neural ground contact",
            creatorMerchantID: "FELMerchant_BondsBounce",
            creatorRevenueShareBps: 1200
        ),
    ]

    static func items(for category: ShopItem.ShopCategory) -> [ShopItem] {
        items.filter { $0.category == category }
    }
}

nonisolated struct CoachEconomy: Codable, Sendable {
    var totalEarned: Int = 0
    var pendingEarnings: Int = 0
    var clearedEarnings: Int = 0
    var escrowEntries: [EscrowEntry] = []
    var critiquesCompleted: Int = 0
    var rating: Double = 5.0
    var totalRatings: Int = 0

    mutating func completeCritique(shards: Int, critiqueId: String) {
        let entry = EscrowEntry(
            id: critiqueId,
            shards: shards,
            createdAt: Date(),
            status: .held
        )
        escrowEntries.append(entry)
        pendingEarnings += shards
        critiquesCompleted += 1
    }

    mutating func releaseCritique(critiqueId: String, athleteRating: Double) {
        guard let index = escrowEntries.firstIndex(where: { $0.id == critiqueId && $0.status == .held }) else { return }
        escrowEntries[index].status = .released
        escrowEntries[index].releasedAt = Date()
        let shards = escrowEntries[index].shards
        pendingEarnings = max(0, pendingEarnings - shards)
        clearedEarnings += shards

        let totalWeight = rating * Double(totalRatings)
        totalRatings += 1
        rating = (totalWeight + athleteRating) / Double(totalRatings)
    }

    mutating func claimEarnings() -> Int {
        let claimed = clearedEarnings
        totalEarned += claimed
        clearedEarnings = 0
        return claimed
    }
}

nonisolated struct EscrowEntry: Codable, Sendable, Identifiable {
    let id: String
    let shards: Int
    let createdAt: Date
    var status: EscrowStatus
    var releasedAt: Date?
}

nonisolated enum EscrowStatus: String, Codable, Sendable {
    case held
    case released
    case disputed
}
