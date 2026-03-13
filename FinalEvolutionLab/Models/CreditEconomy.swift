import Foundation

nonisolated enum CreditTransaction: String, Codable, Sendable {
    case fiatPurchase
    case critiqueEscrowHold
    case critiqueEscrowRelease
    case creatorCardPurchase
    case creatorPayoutClaim
    case shardConversion
}

nonisolated struct CreditPack: Codable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let creditAmount: Int
    let usdCentsPrice: Int
}

nonisolated enum DualCurrencyReservoir {
    // Hard currency peg: 100 credits == $1.00
    static let creditsPerDollar: Int = 100
    static let shardPerCreditRate: Int = 10
    static let creatorPayoutFeeBps: Int = 1500 // 15%
    static let auctionTaxBps: Int = 1000 // 10%
    static let signatureRoyaltyBps: Int = 500 // 5%
    static let signatureAnnualCap: Int = 10
    static let servicePoolFundingFromShardConversionBps: Int = 10_000 // 100%

    static var defaultPacks: [CreditPack] {
        [
            CreditPack(id: "credits_1000", displayName: "Starter", creditAmount: 1_000, usdCentsPrice: 1_000),
            CreditPack(id: "credits_2500", displayName: "Grinder", creditAmount: 2_500, usdCentsPrice: 2_500),
            CreditPack(id: "credits_5000", displayName: "Pro", creditAmount: 5_000, usdCentsPrice: 5_000),
        ]
    }

    static func usdCents(fromCredits credits: Int) -> Int {
        Int((Double(credits) / Double(creditsPerDollar)) * 100.0)
    }

    static func shardsFromCredits(_ credits: Int) -> Int {
        max(0, credits) * shardPerCreditRate
    }

    static func creatorNetCredits(afterFeeOn grossCredits: Int) -> Int {
        let fee = grossCredits * creatorPayoutFeeBps / 10_000
        return max(0, grossCredits - fee)
    }

    static func auctionTaxShards(for salePriceShards: Int) -> Int {
        guard salePriceShards > 0 else { return 0 }
        return max(1, salePriceShards * auctionTaxBps / 10_000)
    }

    static func servicePoolFundingCredits(fromShardConversionCredits creditsSpent: Int) -> Int {
        guard creditsSpent > 0 else { return 0 }
        return max(0, creditsSpent * servicePoolFundingFromShardConversionBps / 10_000)
    }

    static func estimatedCreditsFromShards(_ shards: Int) -> Int {
        guard shards > 0 else { return 0 }
        return shards / max(1, shardPerCreditRate)
    }

    static func signatureRoyaltyCredits(fromSaleShards saleShards: Int) -> Int {
        let notionalCredits = estimatedCreditsFromShards(saleShards)
        guard notionalCredits > 0 else { return 0 }
        return max(1, notionalCredits * signatureRoyaltyBps / 10_000)
    }
}
