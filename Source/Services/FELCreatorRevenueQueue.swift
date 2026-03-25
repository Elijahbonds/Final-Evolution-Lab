import Foundation

/// Bridges call sites to Sovereign shard API (`finalevolutiongroup.com/api/v1/shards`) then `UFELCreatorRevenueSubsystem` (70/30 ledger + `CreatorPayoutLedger.json`).
enum FELCreatorRevenueQueue {
    @MainActor
    static func recordShardPurchase(item: ShopItem, shardCost: Int, athleteId: String, displayName: String) async -> Bool {
        let ok = await FELSovereignShardEconomy.postMarketplacePurchase(
            item: item,
            grossShards: shardCost,
            athleteId: athleteId,
            displayName: displayName
        )
        guard ok else { return false }
        UFELCreatorRevenueSubsystem.shared.recordMarketplacePurchase(item: item, grossShards: shardCost)
        return true
    }
}
