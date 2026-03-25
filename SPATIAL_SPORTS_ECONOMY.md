# Spatial Sports Economy — Design & Implementation Map

This document maps the **Live Stadium / Spatial Sports Economy** vision to the Final Evolution Lab codebase and defines new domains for implementation.

---

## Vision Summary

- **Dual currency**: Shards (soft, earned) + Credits (hard, purchased); creators cash out Credits.
- **Creator Card economy**: Packs (discovery), Auction House (Signature cards), weekly Shard tax to maintain buffs.
- **Spatial Stadium Gym**: Territory control (teams), Brain Barriers (quizzes), Live Performance Raids (Raid Boss on dunks).
- **GPS layer**: Launch Pads (verticality), Fundraising Lures (sponsor booths), Ghost Dunker Nodes (AR + AI Tutor).

---

## 1. Dual-Currency Engine

### Current state

| Concept | Location | Notes |
|--------|----------|--------|
| **Shards (soft)** | `UserProfile.evolutionShards`, `ShardEconomy`, `ShardReward`, `ShardTransaction` | Earned via workouts, game results, critiques, streaks. Used for cards, shop, critiques. |
| **Credits (hard)** | `UserProfile.blueprintCredits` only; no purchase/cash-out flow | Not yet used as “hard currency”; no IAP or creator payout. |

### Target design

| Currency | Source | Sinks | Creator flow |
|----------|--------|--------|--------------|
| **Shards** | Learning modules, GPS activities, workouts, game results, territory passive, raid rewards | Character evolution, card packs, card tax, shop items, enhancing card utility | N/A (soft only) |
| **Credits** | IAP (USD → Credits) | Buy Shards, real-time critiques, event tickets, Lures (sponsor booths) | Creators earn Credits from critiques/tickets; cash out Credits → fiat |

### Implementation

- Add **`credits: Int`** to `UserProfile` (hard currency). Keep or repurpose `blueprintCredits` per product decision.
- Add **`CreditTransaction`** enum and **`CreditsEconomy`** (or extend `ShardEconomy`) for audit: purchase, spend, creatorEarn, cashOut.
- **IAP**: StoreKit 2 for purchase; server or local ledger for balance. Placeholder in app until backend exists.
- **Creator cash-out**: Backend-only; app only shows “Earnings (Credits)” and history; no in-app payout UI required for MVP.

**New files / changes:**

- `Models/SpatialEconomy.swift` (or extend `ShardEconomy.swift`): `CreditTransaction`, `CreditsBalance`, optional `CreatorEarnings`.
- `UserProfile`: add `var credits: Int` and Codable key; default `0`.

---

## 2. Creator Card Auction House & Packs

### Current state

- **CreatorCard**: catalog, `costShards`, apply/clear; **CreatorCardState**: cardId, appliedAt, costShards, metricsBoost.
- **Shard shop**: `ShardShopView`, `ShopCatalog`, `ShopItem` (outfits, blueprints, critique).
- No packs, no auction, no ongoing cost for equipped cards.

### Target design

- **Card packs**: Spend Shards to open packs; discover common → rare → holographic cards (athletes/coaches). New card types: `CardRarity` (common, rare, holographic), `CardPack` (price in Shards, drop table).
- **Auction House**: Listings for “Signature” cards; bid with Shards; highest bid wins when timer ends; optional “Buy Now” for Credits.
- **Weekly Shard tax**: Equipped cards require a recurring Shard payment (e.g. per week) to keep buffs active; otherwise buffs suspend until tax paid.

### Implementation

- **Packs**: `CardPack` (id, name, costShards, rarityWeights), `CardRarity` enum, `openPack(profile)` → [CardDrop]. Add `CardSource` (catalog vs pack vs auction) to ownership if needed.
- **Auction**: `AuctionListing` (listingId, cardId, sellerId, minBid, currentBid, bidderId, endsAt), `placeBid`, `resolveAuction`. Server-authoritative in production; local/mock for MVP.
- **Tax**: `CreatorCardState.nextTaxDue: Date`, `weeklyShardTax: Int` per card or global. In `LabViewModel` or a small `CardTaxService`: each week (or on app open) check `nextTaxDue`; if past, deduct Shards and set next week, or suspend buff until paid.

**New files / changes:**

- `Models/CardPacksAndAuction.swift`: `CardRarity`, `CardPack`, `CardDrop`, `AuctionListing`, `AuctionHouse` (in-memory or service stub).
- `Models/CreatorCard.swift` / `UserProfile.CreatorCardState`: add `nextTaxDue: Date?`, optional `weeklyTaxShards: Int`.
- `ViewModels/LabViewModel` or `Services/CardTaxService`: `payCardTaxIfNeeded()`, `suspendCardIfTaxOverdue()`.

---

## 3. Spatial Stadium Gym Mechanics

### Current state

- No venue/gym entity; no teams (e.g. Team Magnus vs Team Jax); no territory or “control” state.
- Game scenes use “stadium” theming (stands, lights, crowd) but no persistent gym identity or control.

### Target design

- **Gym (venue)**: Real-world stadium/venue with an ID, name, GPS region; linked to a **Territory**.
- **Territory control**: Two (or more) teams compete; control flips based on fan/player activity; fans of controlling team earn **passive Shards** while their team dominates.
- **Brain Barriers**: To challenge a rival gym, users complete rapid quizzes. “Study Sessions” (learning modules) strengthen gym defenses (e.g. harder quiz or more HP).
- **Live Performance Raids**: When an athlete performs a notable dunk (in real life or in-app), a **Raid Boss** activates in the app; fans vote/tap to contribute; on success, participants get **event cards** or Shards.

### Implementation

- **Gym**: `SpatialGym` (id, name, region/cluster, teamId controlling, lastFlipAt).
- **Team**: `StadiumTeam` (id, name, color, roster of fan/player IDs for passive rewards).
- **Territory**: `TerritoryControl` (gymId, controllingTeamId, scoreA, scoreB, contributionByUser).
- **Brain Barrier**: `BrainBarrier` (gymId, quizSetId, difficulty, defenseStrength); `StudySession` completion → update defense or user’s “key” to challenge.
- **Raid**: `RaidBoss` (id, eventId, athleteId, triggerType “dunk”/“milestone”, startedAt, endsAt, totalHealth, currentHealth, participantIds); `contributeToRaid(userId, action)`; on defeat → grant `RaidReward` (event card, Shards).

**New files:**

- `Models/SpatialStadium.swift`: `SpatialGym`, `StadiumTeam`, `TerritoryControl`, `BrainBarrier`, `RaidBoss`, `RaidReward`, `StudySessionDefense`.

---

## 4. GPS-Enhanced Verticality & Fundraising

### Current state

- No GPS or location services in the app (no `CLLocation`, no geofencing).
- “Launch Pad” / “Lure” / “Ghost Dunker” are net-new concepts.

### Target design

- **Launch Pads**: GPS zones near a rim/court; app detects presence and (optionally) vertical/jump data. Higher jumps → rarer Shard rewards.
- **Fundraising Lures**: Teams or organizers spend **Credits** to place Lures at sponsor booths; fans in zone get high-value Shard drops; sponsors get foot traffic.
- **Ghost Dunker Nodes**: GPS + AR; at specific coordinates, fans watch AR replays of pro dunks and engage AI Tutor; rewards (Shards, XP, or cards).

### Implementation

- **Zones**: `GPSZone` (id, type: launchPad | lure | ghostDunker, center, radius, metadata). Use Core Location geofencing (enter/exit) or periodic location + distance check.
- **Launch Pad**: `LaunchPadZone` extends or uses `GPSZone`; on enter + optional “jump” event (from device or manual), grant `ShardReward` with rarity by jump height.
- **Lure**: `LurePlacement` (id, sponsorId, gymId, boothLocation, creditsSpent, shardRewardPerVisit, activeUntil); on enter zone, grant Shards once per window (e.g. per day).
- **Ghost Dunker**: `GhostDunkerNode` (id, coordinate, clipId, aiTutorEnabled); AR view at node; complete viewing + optional quiz → reward.

**New files:**

- `Models/GPSZones.swift`: `GPSZoneType`, `GPSZone`, `LaunchPadZone`, `LurePlacement`, `GhostDunkerNode`.
- **Services**: `LocationZoneService` (CLLocationManager, monitor regions, resolve zone type and grant rewards); `LureService` (fetch active lures, validate visit); optional `ARReplayService` for Ghost Dunker.

**Privacy / permissions**: Request “When In Use” location; explain Shards/Lures/Ghost in onboarding; do not track continuously when not needed.

---

## 5. Swift ↔ Existing Code Quick Map

| New concept | Fits into / extends |
|-------------|----------------------|
| Credits (hard currency) | `UserProfile`, `ShardEconomy` or `SpatialEconomy` |
| Card packs & auction | `CreatorCard`, `ShardShopView`, new `CardPacksAndAuction` |
| Weekly card tax | `CreatorCardState`, `LabViewModel` / `CardTaxService` |
| Spatial Gym / Territory | New `SpatialStadium`; UI: new “Stadium” or “Live” tab/section |
| Brain Barrier / Study | Link to existing learning/training modules; `CurriculumTrack` or new quiz model |
| Raid Boss | New `SpatialStadium.RaidBoss`; UI: banner or Arena entry when raid active |
| Launch Pad / Lure / Ghost | New `GPSZones`; `LocationZoneService`; optional AR view |

---

## 6. Suggested Implementation Order

1. **Dual currency**: Add `credits` to profile and `CreditTransaction`; stub IAP and creator earnings.
2. **Card tax**: Add `nextTaxDue` and weekly tax logic; suspend buff if overdue.
3. **Card packs**: Add `CardRarity`, `CardPack`, open-pack flow; show in Shard Shop or new “Packs” section.
4. **Auction House**: Add `AuctionListing` and in-memory/mock auction; simple “Auction” tab or sheet.
5. **Spatial Gym**: Add `SpatialGym`, `StadiumTeam`, `TerritoryControl`; UI for “Live Gym” and control status.
6. **Brain Barrier**: Add `BrainBarrier` and link to quizzes; “Challenge Gym” flow.
7. **Raid Boss**: Add `RaidBoss` and contribution API; “Raid” banner and reward claim.
8. **GPS zones**: Add `GPSZone`, `LaunchPadZone`, `LurePlacement`, `GhostDunkerNode`; `LocationZoneService`; permission and reward hooks.
9. **Lures (Credits)**: Teams spend Credits to place Lures; backend or local stub.
10. **Ghost Dunker**: AR + AI Tutor integration (can be placeholder until AR/API ready).

---

## 7. Implementation Added (Codebase)

The following Swift models and profile changes are in the repo and ready for UI/backend wiring:

| Area | Files | Profile/VM changes |
|------|--------|---------------------|
| **Dual currency** | `Models/SpatialEconomy.swift` | `UserProfile.credits` (default 0), `CreditTransaction`, `CreditsBalance`, `CreatorEarnings` |
| **Card packs & auction** | `Models/CardPacksAndAuction.swift` | `CardRarity`, `CardPack`, `CardDrop`, `AuctionListing`, `AuctionHouse` |
| **Weekly card tax** | — | `CreatorCardState.nextTaxDue`, `CreatorCardState.weeklyTaxShards`; `LabViewModel.weeklyCardTaxShards`, `applyCreatorCard` sets next tax due in 7 days |
| **Spatial stadium** | `Models/SpatialStadium.swift` | `SpatialGym`, `StadiumTeam`, `TerritoryControl`, `BrainBarrier`, `RaidBoss`, `RaidReward` |
| **GPS zones** | `Models/GPSZones.swift` | `GPSZoneType`, `GPSZone`, `LaunchPadZone`, `LurePlacement`, `GhostDunkerNode` |

Next steps: IAP for Credits, Auction/Pack UI, tax payment flow in Lab/Vault, Stadium tab and raid banner, LocationZoneService + permissions for GPS zones.

---

*This document is the single product/design reference for the Spatial Sports Economy. Implementation details live in the linked models and services.*
