import Foundation

/// User-facing economy copy — internal keys (PRQ, evolutionShards) stay in models/services.
nonisolated enum FELEconomyLabels: Sendable {
    static let performanceScore = "Performance Score"
    static let performanceScoreShort = "Score"
    static let rankedTier = "Rank Tier"

    static let shards = "Shards"
    static let shardBalance = "Shard Balance"
    static let evolutionShardsLong = "Evolution Shards"

    static let focusEnergy = "Focus Energy"
    static let focusEnergyShort = "Focus"

    static let shopTitle = "Evolution Shop"
    static let marketplaceTitle = "Creator Marketplace"

    static func shardCost(_ amount: Int) -> String {
        "\(amount) shards"
    }

    static func purchasePrompt(itemName: String, cost: Int) -> String {
        "Spend \(cost) shards on \(itemName)?"
    }

    static let earnShardsHint = "Earn shards by completing workouts and arena matches."
    static let insufficientShards = "Not enough shards"
    static let marketplaceConnected = "Marketplace connected"
    static let loadingMarketplace = "Loading marketplace…"
    static let connectionError = "Couldn’t reach the marketplace"
}
