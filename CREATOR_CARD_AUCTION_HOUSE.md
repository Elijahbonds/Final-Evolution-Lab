# Creator Card Auction House & Shard Utility

This module extends the dual-currency economy with:

- **Rarity-driven Creator Card inventory**
- **Shard-burn card maintenance**
- **Shard-based pack openings (gacha odds)**
- **Peer-to-peer auction house with 10% shard tax**
- **Signature card cap + resale royalty in credits**
- **Shard-to-service bridge backed by a credit reserve pool**

## Implemented Core Types

File: `FinalEvolutionLab/Models/CreatorCardMarketplace.swift`

- `CreatorCardRarity`
- `CreatorCardAsset`
- `CreatorPackOdds` (`70/20/8/2` weights)
- `CreatorCardAuctionListing`, `CreatorCardBid`, `CreatorCardAuctionSale`
- `CreatorCardMarketplaceState`

## Economics Constants

File: `FinalEvolutionLab/Models/CreditEconomy.swift`

- `auctionTaxBps = 1000` (10%)
- `signatureRoyaltyBps = 500` (5%)
- `signatureAnnualCap = 10`
- `servicePoolFundingFromShardConversionBps = 10000` (100% of conversion credits into reserve)

## ViewModel APIs

File: `FinalEvolutionLab/ViewModels/LabViewModel.swift`

- `openCreatorPacks(count:odds:)`
- `activateCardMaintenance(assetId:hours:)`
- `listOwnedCardForAuction(assetId:startingBidShards:buyNowShards:durationHours:)`
- `placeBidOnListing(listingId:bidAmountShards:)`
- `buyNowListing(listingId:)`
- `settleExpiredAuctionListings()`
- `signCardAsSignature(assetId:creatorId:year:)`
- `requestCritiqueUsingShardBridge(exerciseName:notes:shardCost:)`

## Persistence

File: `FinalEvolutionLab/Services/SaveSystem.swift`

- Added local state persistence key:
  - `finalEvolution_creatorMarketplace`
- Methods:
  - `saveCreatorMarketplace(_:)`
  - `loadCreatorMarketplace()`

## Flow Summary

1. Players can buy packs with **Shards**.
2. Cards can be activated via **maintenance shard burn**.
3. Players list cards and trade via **shard auctions**.
4. Every sale burns **10% shard tax**.
5. Signed cards pay **credit royalties** on resale (if reserve pool has available credits).
6. Shard-funded creator services reserve and pay creator credits from the **conversion-backed service pool**.
