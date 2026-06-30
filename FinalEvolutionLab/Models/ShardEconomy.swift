import Foundation

nonisolated enum ShardTransaction: String, Codable, Sendable {
    case workoutComplete
    case gameWin
    case gameDraw
    case gameLoss
    case comboBonus
    case criticalHit
    case outfitPurchase
    case blueprintPurchase
    case critiqueRequest
    case critiqueEarning
    case dailyBonus
    case streakBonus
    case achievementUnlock
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

        if combo > 3 {
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
}

nonisolated struct ShopItem: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let cost: Int
    let category: ShopCategory
    let iconName: String

    nonisolated enum ShopCategory: String, Sendable, CaseIterable {
        case outfit      = "Outfits"
        case blueprint   = "Blueprints"
        case critique    = "Coaching"
        case creatorCard = "Creator Cards"
    }
}

struct ShopCatalog {
    static let items: [ShopItem] = [
        ShopItem(id: "outfit_neon", name: "Neon Flux", description: "Electric cyan avatar skin with pulse effects", cost: 500, category: .outfit, iconName: "sparkles"),
        ShopItem(id: "outfit_shadow", name: "Shadow Elite", description: "Dark matte finish with ember accents", cost: 750, category: .outfit, iconName: "moon.fill"),
        ShopItem(id: "outfit_chrome", name: "Chrome V", description: "Reflective metallic with blue highlights", cost: 1000, category: .outfit, iconName: "light.max"),
        ShopItem(id: "outfit_gold", name: "Gold Standard", description: "Premium gold plated avatar", cost: 2000, category: .outfit, iconName: "crown.fill"),

        ShopItem(id: "bp_vertical", name: "Vertical Lab", description: "8-week jump training blueprint", cost: 300, category: .blueprint, iconName: "arrow.up.circle.fill"),
        ShopItem(id: "bp_speed", name: "Speed Matrix", description: "Sprint mechanics breakdown", cost: 300, category: .blueprint, iconName: "bolt.circle.fill"),
        ShopItem(id: "bp_recovery", name: "Neural Recovery", description: "Advanced CNS recovery protocols", cost: 200, category: .blueprint, iconName: "heart.circle.fill"),

        ShopItem(id: "critique_form", name: "Form Critique", description: "Expert movement analysis from Coach V", cost: 150, category: .critique, iconName: "eye.fill"),
        ShopItem(id: "critique_program", name: "Program Review", description: "Full training program audit", cost: 400, category: .critique, iconName: "doc.text.magnifyingglass"),
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

    /// Auto-releases held escrow entries older than `days` days so coaches
    /// are not permanently blocked by athletes who never submit a review.
    mutating func autoReleaseStaleEscrow(olderThanDays days: Int = 7) {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
        for index in escrowEntries.indices where escrowEntries[index].status == .held {
            guard escrowEntries[index].createdAt < cutoff else { continue }
            escrowEntries[index].status = .released
            escrowEntries[index].releasedAt = Date()
            let shards = escrowEntries[index].shards
            pendingEarnings = max(0, pendingEarnings - shards)
            clearedEarnings += shards
        }
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
