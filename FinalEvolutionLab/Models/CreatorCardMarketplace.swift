import Foundation

nonisolated enum CreatorCardRarity: String, Codable, Sendable, CaseIterable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
    case signature

    var maintenanceShardFeePerHour: Int {
        switch self {
        case .common: 1
        case .uncommon: 2
        case .rare: 3
        case .epic: 5
        case .legendary: 8
        case .signature: 10
        }
    }
}

nonisolated enum CreatorCardAssetSource: String, Codable, Sendable {
    case directPurchase
    case creatorPack
    case auctionHouse
    case reward
}

nonisolated struct CreatorCardAsset: Identifiable, Codable, Sendable {
    let id: String
    let templateCardId: String
    var ownerId: String
    var rarity: CreatorCardRarity
    let acquiredAt: Date
    let source: CreatorCardAssetSource
    var maintenanceExpiresAt: Date?
    var totalMaintenanceShardsPaid: Int
    var isLockedInAuction: Bool
    var signedByCreatorId: String?
    var signatureYear: Int?
    var signatureSerial: Int?

    func utilityActive(now: Date, currentShardBalance: Int) -> Bool {
        guard currentShardBalance > 0 else { return false }
        guard let maintenanceExpiresAt else { return false }
        return maintenanceExpiresAt > now
    }
}

nonisolated struct CreatorPackOdds: Codable, Sendable {
    let commonWeight: Int
    let rareWeight: Int
    let epicWeight: Int
    let legendaryWeight: Int

    static let myTeamStyle = CreatorPackOdds(
        commonWeight: 70,
        rareWeight: 20,
        epicWeight: 8,
        legendaryWeight: 2
    )

    func rollRarity() -> CreatorCardRarity {
        let total = max(1, commonWeight + rareWeight + epicWeight + legendaryWeight)
        let roll = Int.random(in: 0..<total)
        let commonCutoff = commonWeight
        let rareCutoff = commonCutoff + rareWeight
        let epicCutoff = rareCutoff + epicWeight

        if roll < commonCutoff { return .common }
        if roll < rareCutoff { return .rare }
        if roll < epicCutoff { return .epic }
        return .legendary
    }
}

nonisolated enum AuctionListingStatus: String, Codable, Sendable {
    case active
    case sold
    case cancelled
    case expired
}

nonisolated struct CreatorCardBid: Codable, Sendable {
    let bidderId: String
    let amountShards: Int
    let placedAt: Date
}

nonisolated struct CreatorCardAuctionListing: Identifiable, Codable, Sendable {
    let id: String
    let assetId: String
    let templateCardId: String
    let sellerId: String
    let listedAt: Date
    let endsAt: Date
    let startingBidShards: Int
    let buyNowShards: Int?
    var highestBid: CreatorCardBid?
    var status: AuctionListingStatus

    var currentBidShards: Int {
        highestBid?.amountShards ?? startingBidShards
    }

    func isActive(now: Date) -> Bool {
        status == .active && endsAt > now
    }
}

nonisolated struct CreatorCardAuctionSale: Identifiable, Codable, Sendable {
    let id: String
    let listingId: String
    let assetId: String
    let templateCardId: String
    let sellerId: String
    let buyerId: String
    let salePriceShards: Int
    let burnedTaxShards: Int
    let sellerNetShards: Int
    let royaltyCreditsPaid: Int
    let soldAt: Date
}

nonisolated struct CreatorCardMarketplaceState: Codable, Sendable {
    var inventory: [CreatorCardAsset] = []
    var activeListings: [CreatorCardAuctionListing] = []
    var salesHistory: [CreatorCardAuctionSale] = []

    var shardBurnedByPackPulls: Int = 0
    var shardBurnedByMaintenance: Int = 0
    var shardBurnedByAuctionTax: Int = 0
    var shardBurnedByServiceBridge: Int = 0

    var servicePoolAvailableCredits: Int = 0
    var servicePoolReservedCredits: Int = 0
    var servicePoolPaidOutCredits: Int = 0
    var serviceFundingReservations: [String: Int] = [:] // requestId -> reserved credits

    var royaltyCreditsByCreatorId: [String: Int] = [:]
    var signatureMintCountByCreatorYear: [String: Int] = [:] // creatorId:year -> count

    mutating func fundServicePool(credits: Int) {
        guard credits > 0 else { return }
        servicePoolAvailableCredits += credits
    }

    mutating func reserveServicePoolCredits(requestId: String, credits: Int) -> Bool {
        guard credits > 0, servicePoolAvailableCredits >= credits else { return false }
        servicePoolAvailableCredits -= credits
        servicePoolReservedCredits += credits
        serviceFundingReservations[requestId] = credits
        return true
    }

    @discardableResult
    mutating func settleReservedServiceCredits(requestId: String) -> Int {
        guard let reserved = serviceFundingReservations.removeValue(forKey: requestId) else { return 0 }
        servicePoolReservedCredits = max(0, servicePoolReservedCredits - reserved)
        servicePoolPaidOutCredits += reserved
        return reserved
    }

    @discardableResult
    mutating func releaseReservedServiceCredits(requestId: String) -> Int {
        guard let reserved = serviceFundingReservations.removeValue(forKey: requestId) else { return 0 }
        servicePoolReservedCredits = max(0, servicePoolReservedCredits - reserved)
        servicePoolAvailableCredits += reserved
        return reserved
    }

    func availableServiceCreditsAfterReserves() -> Int {
        max(0, servicePoolAvailableCredits)
    }

    func signatureMintCount(creatorId: String, year: Int) -> Int {
        signatureMintCountByCreatorYear["\(creatorId):\(year)"] ?? 0
    }

    mutating func recordSignatureMint(creatorId: String, year: Int) -> Int {
        let key = "\(creatorId):\(year)"
        let next = (signatureMintCountByCreatorYear[key] ?? 0) + 1
        signatureMintCountByCreatorYear[key] = next
        return next
    }

    mutating func addRoyaltyCredits(creatorId: String, credits: Int) {
        guard credits > 0 else { return }
        royaltyCreditsByCreatorId[creatorId, default: 0] += credits
    }
}

extension CreatorCard {
    var creatorId: String {
        creatorName
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "_" }
            .reduce(into: "") { partial, char in
                if char == "_" && partial.last == "_" { return }
                partial.append(char)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
