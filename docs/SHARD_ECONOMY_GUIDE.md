# Shard Economy Guide

## Overview

Final Evolution Lab uses a dual-currency system called **Shards**. Earn them through gameplay and spend them in the Shard Store. No pay-to-win mechanics — everything is earnable for free.

## Currency Types

### Evolution Shards (Free Currency)
- Earned through gameplay, workouts, and challenges
- Primary currency for all purchases
- Free to earn — no real money required

### Premium Shards (Optional Paid Currency)
- Purchased with real money
- Provides faster access to items
- No exclusive premium-only items
- 100% optional

## Earning Evolution Shards

### Game Mode Rewards
| Action | Shards |
|--------|--------|
| Win a game | 75 |
| Lose a game | 35 |
| MVP award | +25 |
| Perfect game | +50 |
| Comeback win | +75 |

### Exercise/Workout Rewards
| Action | Shards |
|--------|--------|
| Complete workout | 45 |
| Perfect form bonus | +20 |
| New personal record | +40 |
| Streak bonus (per day) | +10 |

### Challenge Rewards
| Challenge | Shards |
|-----------|--------|
| Daily challenge | 50 |
| Weekly challenge | 200 |
| Creator challenge | 100–300 |
| Special event | 500+ |

### Achievement Rewards
| Achievement | Shards |
|-------------|--------|
| First dunk | 100 |
| 100 games played | 500 |
| 50 workouts completed | 300 |
| Unlock all environments | 1,000 |

### Daily Login Rewards
| Day | Shards |
|-----|--------|
| Day 1 | 10 |
| Day 2 | 20 |
| Day 3 | 30 |
| Day 4 | 40 |
| Day 5 | 50 |
| Day 6 | 75 |
| Day 7 | 100 |
| *Resets after missing a day* |

### Earning Rate Estimates
| Player Type | Shards/Hour |
|-------------|-------------|
| Casual | 100–200 |
| Average | 200–400 |
| Hardcore | 500–800 |

## Shard Store

### Categories & Price Ranges

#### Cosmetics (500–5,000 shards)
- Character skins & jerseys
- Shoes & accessories
- Emotes & celebrations
- Headbands, wristbands, etc.

#### Environments (1,000–3,000 shards)
- Night court, sunset court
- Rain effects, snow effects
- Time-of-day variations

#### Gameplay (500–1,500 shards)
- Temporary skill boosts
- XP multipliers
- Custom game mode modifiers

#### Customization (300–1,000 shards)
- Ball designs (chrome, galaxy, etc.)
- HUD themes
- Sound packs

#### Progression (100–500 shards)
- XP boosts
- Workout program unlocks
- Fast-track progression

### Rarity & Pricing
| Rarity | Evolution Shards | Time to Earn |
|--------|------------------|--------------|
| Common | 300–800 | 1–2 hours |
| Rare | 1,000–2,000 | 3–5 hours |
| Epic | 2,500–5,000 | 6–12 hours |
| Legendary | 5,000–10,000 | 12–25 hours |

## Premium Shard Packages

| Package | Price | Shards | Bonus |
|---------|-------|--------|-------|
| Starter | $0.99 | 100 | — |
| Value | $4.99 | 600 | 20% bonus |
| Premium | $9.99 | 1,300 | 30% bonus |
| Ultimate | $19.99 | 3,000 | 50% bonus |

### Premium vs Free
- **All items** purchasable with Evolution Shards
- Premium Shards = faster access only
- **No pay-to-win** mechanics
- **Cosmetic focus** — no gameplay advantages

## Transaction History

- All transactions logged with timestamps
- View history in **Settings → Shard Wallet → History**
- Up to 500 transactions stored
- Filter by type (earned/spent), source, and date

## Economy Design Philosophy

1. **Earning should feel rewarding** — Every play session nets meaningful shards
2. **Spending should feel meaningful** — Items feel worth the investment
3. **No frustration gates** — Never blocked by currency
4. **Optional premium** — Paying speeds things up but isn't required
5. **Balanced inflation** — New items added regularly to maintain economy

## UE5 Integration

### C++ Classes
| File | Purpose |
|------|---------|
| `FELShardEconomy.h/.cpp` | Complete economy system: wallet, earning, spending, store |
| `FELShardRewardTypes.h` | Reward type definitions |

### Key Blueprint Functions
- `AwardShards()` → Give shards for any source
- `AwardGameReward()` → Calculate game-end rewards
- `AwardWorkoutReward()` → Calculate workout rewards
- `PurchaseItem()` → Buy from store
- `ClaimDailyLogin()` → Process daily login reward
- `GetStoreItems()` → Browse store by category
- `GetTransactionHistory()` → View past transactions

### Events
- `OnShardsEarned` — Shards awarded
- `OnShardsSpent` — Shards spent
- `OnBalanceChanged` — Wallet balance updated
- `OnStoreItemPurchased` — Item bought
- `OnDailyLoginRewardClaimed` — Login reward collected
