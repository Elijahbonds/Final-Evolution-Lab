# Economy authority contract (shards & catalog)

This document defines **which layer is authoritative** for shard balance and purchasable inventory in Final Evolution Lab’s hybrid local + Firebase Data Connect setup.

## SQL shard balance (Data Connect)

- **Authoritative balance** for signed-in users lives on the SQL `User.evolutionShards` row, updated through ledger mutations.
- **`SpendEvolutionShards`** is the client-callable **spend** path (negative `deltaShards` only). The mutation allowlists `reason` so arbitrary labels cannot drain accounts:
  - **`creator_card_purchase`** — paired with **`ClaimCreatorCardOwnership`** after spend succeeds (same `referenceId` / `catalogCardId`).
  - **`shard_shop`** — verifies shard deduction for Shard Shop catalog purchases (outfits, blueprints, critiques UI). Does **not** imply SQL rows for shop inventory yet.
- **Arena / workout grants** use server-side **`AppendShardLedger`** (or equivalent admin pipeline), not client spend mutations.

## Creator Cards (paid vs free)

- **Paid** (`costShards > 0`): The app **must not** subtract local shards or append ownership until **`SpendEvolutionShards`** and **`ClaimCreatorCardOwnership`** both succeed. Otherwise the device could show ownership without SQL agreement (or lose shards without a ledger row).
- **Free** (`costShards == 0`): **Local-only** activation — no SQL spend or ownership claim (free catalog entries remain device-safe without backend coupling).

## Shard Shop (cosmetics / catalog)

- Purchase flow calls **`SpendEvolutionShards`** with **`reason: "shard_shop"`** and **`referenceId`** = stable shop item id (dedupes accidental double-spend per item/reason).
- **Owned item ids** are cached in **`UserDefaults`** on device. There is **no** SQL “owned shop items” table yet; until one exists, **reinstall / new device** may not reflect prior cosmetic ownership even though shard spend was recorded in SQL.
- Treat Shard Shop **inventory display** as **local cache** until a server-side ownership table is implemented and synced.

## Duplicate prevention

- `SpendEvolutionShards` rejects duplicate `(reason, referenceId)` for the same user via prior ledger lookup (`priorGrants`).

## Related files

- Data Connect: `dataconnect/social-connector/mutations.gql` (`SpendEvolutionShards`, `ClaimCreatorCardOwnership`).
- iOS bridge: `FinalEvolutionLab/Services/TrainingLabSocialBridge.swift`.
- Shard Shop UI: `FinalEvolutionLab/Views/ShardShopView.swift`.
- Creator Card apply: `FinalEvolutionLab/ViewModels/LabViewModel.swift` (`applyCreatorCard`).
