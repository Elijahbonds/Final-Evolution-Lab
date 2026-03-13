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
}
