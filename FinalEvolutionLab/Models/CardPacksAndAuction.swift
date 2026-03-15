// MARK: - Creator Card Packs, Rarity, and Auction House (Spatial Sports Economy)

import Foundation

nonisolated enum CardRarity: String, Codable, Sendable, CaseIterable {
    case common
    case rare
    case holographic

    var displayName: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .holographic: return "Holographic"
        }
    }

    var shardValueMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .rare: return 2.0
        case .holographic: return 4.0
        }
    }
}

nonisolated struct CardDrop: Sendable {
    let cardId: String
    let rarity: CardRarity
    let displayName: String
    let creatorName: String
}

/// Pack definition: cost in Shards, drop table by rarity weight (0.0...1.0).
nonisolated struct CardPack: Identifiable, Sendable {
    let id: String
    let name: String
    let costShards: Int
    /// Weights for [common, rare, holographic]; should sum to 1.0
    let rarityWeights: (common: Double, rare: Double, holographic: Double)
    let iconName: String

    static let standard: CardPack = CardPack(
        id: "pack_standard",
        name: "Standard Pack",
        costShards: 100,
        rarityWeights: (0.7, 0.25, 0.05),
        iconName: "rectangle.stack.fill"
    )

    static let premium: CardPack = CardPack(
        id: "pack_premium",
        name: "Premium Pack",
        costShards: 300,
        rarityWeights: (0.5, 0.35, 0.15),
        iconName: "star.fill"
    )

    static let catalog: [CardPack] = [.standard, .premium]
}

/// Single auction listing for a Signature (or any) card. Server-authoritative in production.
nonisolated struct AuctionListing: Identifiable, Sendable {
    let id: String
    let cardId: String
    let cardDisplayName: String
    let creatorName: String
    let sellerId: String
    let minBidShards: Int
    var currentBidShards: Int
    var highBidderId: String?
    let endsAt: Date
    var buyNowCredits: Int? // Optional instant buy with hard currency

    var isActive: Bool { endsAt > Date() }
}

/// In-memory or stub implementation; replace with network service.
nonisolated struct AuctionHouse {
    static func placeBid(listing: inout AuctionListing, bidShards: Int, bidderId: String) -> Bool {
        guard listing.isActive, bidShards >= listing.minBidShards, bidShards > listing.currentBidShards else { return false }
        listing.currentBidShards = bidShards
        listing.highBidderId = bidderId
        return true
    }

    static func resolveListing(_ listing: AuctionListing, now: Date = Date()) -> (winnerId: String?, shardsToSeller: Int)? {
        guard !listing.isActive, now >= listing.endsAt else { return nil }
        return (listing.highBidderId, listing.currentBidShards)
    }
}
