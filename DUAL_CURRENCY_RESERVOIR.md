# Dual-Currency Reservoir (Shards + Credits)

## Currency Separation

1. **Shards (Soft Currency)**
   - Earned through gameplay and learning loops.
   - Used for progression/evolution systems.
   - Non-withdrawable.

2. **Credits (Hard Currency)**
   - Purchased via fiat rails (App Store/Stripe integration layer).
   - Used for creator services and creator-card access.
   - Creator-facing and payout-oriented.

## Implemented Direction in this repo

- User profile now tracks:
  - `evolutionShards`
  - `premiumCredits`
  - `creatorCredits`
- Critique requests:
  - Deduct **Credits** from athlete wallet.
  - Hold amount in escrow until review completion.
  - Grant a small shard bonus for creator engagement.
- Creator cards:
  - Purchased with **Credits**.
- One-way bridge:
  - Credits can be converted into Shards.
  - Shards cannot be converted back into Credits.

## Core constants

Defined in `FinalEvolutionLab/Models/CreditEconomy.swift`:

- `creditsPerDollar = 100`
- `shardPerCreditRate = 10`
- `creatorPayoutFeeBps = 1500` (15%)

These are placeholders and should be finalized by product/finance.
