# Master Architecture Blueprint — Final Evolution Lab

Authoritative reference for Final Evolution Lab covering the full game-mode registry (19 modes across 13 venues), map-to-mode routing, PRQ/readiness/scan truth boundaries, Creator Cards & Module Library, Shard Ledger economy, session receipt contracts, backend schemas, StoreKit/App Store compliance, Unreal Engine cooked payload pipeline, build/deploy infrastructure, and per-mode acceptance tests. Built from the `anti-gravity-fel` branch.

---

## Goals

- Document the complete game-mode registry: 19 modes (12 production, 5 staging, 2 late additions) with per-mode map, gamemode class, binary, status, input scheme, PRQ weight, and scoring contract
- Define the map-to-mode routing architecture across 3 layers: UE deep link subsystem, backend ue_mode_maps.json, and E3DS Pixel Streaming
- Specify PRQ/readiness/scan truth boundaries: Swift HealthKit source → Firestore sync → UnrealSystemScanPayload bridge → backend weighted composite
- Document Creator Cards & Module Library boundaries: 4-card catalog, MovementSignature physics, metricsBoost contract, PayPal purchase flow
- Specify Shard Ledger economy: transaction types, reward formulas, coach escrow, shop catalog
- Define session receipt data contracts: Swift GameSessionResult, backend game_sessions schema, XP/PRQ/Shard award formulas
- Document backend mode schemas across MongoDB, Firestore, and Firebase Data Connect (PostgreSQL)
- Specify StoreKit/App Store compliance requirements: prohibited distribution channels, required plist keys, export compliance
- Define cooked payload requirements: 11 MapsToCook, descriptor-safe packaging, 3 build targets
- Establish per-mode acceptance test matrix: launch, scoring, deep link, session persistence, PRQ impact
- Flag critical discrepancies between registries that must be resolved before shipping

---

## 1. System Architecture Overview

FEL is a polyglot monorepo with 5 runtime layers:

```
┌─────────────────────────────────────────────────┐
│  UE 5.7 Native Host (iOS Shipping / Linux E3DS) │
│  ┌──────────────┐  ┌──────────────────────────┐ │
│  │ Game Modes   │  │ Subsystems               │ │
│  │ (19 BPs)     │  │ EmergentBridge           │ │
│  │              │  │ DeepLink                 │ │
│  │              │  │ PerformanceManager       │ │
│  │              │  │ Overlay (WKWebView)      │ │
│  │              │  │ FocusKeepalive           │ │
│  └──────────────┘  └──────────────────────────┘ │
├─────────────────────────────────────────────────┤
│  Swift Shell (FinalEvolutionLab/)               │
│  Models / Services / HealthKit / Firebase Auth   │
│  PRQ Scoring / System Scan / Shard Economy       │
├─────────────────────────────────────────────────┤
│  WKWebView Overlay (frontend/ React SPA)        │
│  Dashboard / FEL OS / Arena / Cards / Education  │
├─────────────────────────────────────────────────┤
│  FastAPI Backend (backend/)                      │
│  Auth / Games / Education / BioFuel / Pass Image │
├─────────────────────────────────────────────────┤
│  Data Layer                                      │
│  MongoDB │ Firestore │ Data Connect (PostgreSQL) │
└─────────────────────────────────────────────────┘
```

### Key Source Paths

| Layer | Path | Stack |
|-------|------|-------|
| UE C++ Integration | `UnrealIntegration/Source/FinalEvolutionLab/` | C++/ObjC++, UE 5.7 |
| UE Project | `UnrealStarter/BasketballGame/` | UE 5.7 Blueprints + C++ |
| Swift App | `FinalEvolutionLab/` | Swift, SwiftUI, Firebase, HealthKit |
| React SPA | `frontend/src/` | React 19, Tailwind, Axios, PayPal SDK |
| Backend | `backend/` | FastAPI, MongoDB (Motor), PayPal REST |
| Infra | `infra/` | Pulumi (E3DS), UE5 config, CI scripts |
| Marketing Sites | `sites/` | React + Vite + Tailwind |
| Data Connect | `dataconnect/` | GraphQL, PostgreSQL (Cloud SQL) |

---

## 2. Full Game-Mode Registry (19 Modes)

### 2.1 Production Modes (14)

| # | mode_id | Display Name | Map | Gamemode Class | Binary | Input Scheme | Sport Category | Multiplayer | PRQ Weight |
|---|---------|-------------|-----|----------------|--------|-------------|----------------|-------------|------------|
| 1 | `basketball_h2h` | Head to Head | Venice_Beach_Court | BP_Basketball_H2H | FEL-Basketball-H2H | charge | Basketball | realtime | 1.2 |
| 2 | `basketball_dunk` | Dunk Contest | Venice_Beach_Court | BP_DunkContest | FEL-DunkContest | charge | Basketball | realtime | 1.0 |
| 3 | `basketball_3v3` | 3v3 Streetball | Venice_Beach_Court | BP_Basketball_3v3 | FEL-Basketball-3v3 | charge | Basketball | realtime | 1.3 |
| 4 | `karate_h2h` | Karate · 1v1 | Zen_Dojo | BP_Karate_H2H | FEL-Karate-H2H | charge | Combat | realtime | 1.4 |
| 5 | `karate_endless` | Karate · Endless | Zen_Dojo | BP_Karate_Endless | FEL-Karate-Endless | charge | Combat | realtime | 1.4 |
| 6 | `baseball` | Home Run Derby | Baseball_Park | BP_Baseball | FEL-Baseball | swipe | Field | turnBased | 1.0 |
| 7 | `football` | Kick Return | Gridiron_Stadium | BP_Football_KickReturn | FEL-Football | kickReturn | Field | turnBased | 1.5 |
| 8 | `soccer` | Penalty Shootout | Soccer_Stadium | BP_Soccer | FEL-Soccer | penaltyKick | Field | realtime | 1.1 |
| 9 | `golf` | Closest to Pin | Links_Course | BP_Golf | FEL-Golf | swipeGolf | Precision | turnBased | 0.9 |
| 10 | `tennis` | Rally Ace | Tennis_Court | BP_Tennis | FEL-Tennis | rallyAce | Precision | realtime | 1.1 |
| 11 | `volleyball` | Rally Ace | Sand_Court | BP_Volleyball | FEL-Volleyball | rallyAce | Field | realtime | 1.2 |
| 12 | `surfing` | Surfing | Venice_Beach_Surf | BP_Surfing | FEL-Surfing | rhythmTap | Board | realtime | 1.05 |
| 13 | `who_scene_it` | Who Scene It | Neuro_Arena | BP_WhoSceneIt | FEL-WhoSceneIt | — | Academy | — | — |
| 14 | `mario_party_fever` | Party Mode | Venice_Beach_Court | BP_PartyMode | FEL-PartyMode | — | Party | — | — |

### 2.2 Staging Modes (5)

| # | mode_id | Display Name | Map | Binary | Input Scheme | Sport | Notes |
|---|---------|-------------|-----|--------|-------------|-------|-------|
| 15 | `skateboarding` | Skateboarding | Skate_Park | FEL-Skateboarding | rhythmTap | Board | Park Lines |
| 16 | `snowboarding` | Snowboarding | Mountain_Slope | FEL-Snowboarding | rhythmTap | Board | Slope Control |
| 17 | `gymnastics` | Gymnastics | Training_Floor | FEL-Gymnastics | rhythmTap | Precision | Olympic Routines |
| 18 | `brain_brawl` | Brain Brawl | Neuro_Arena | FEL-BrainBrawl | — | Academy | Deep-link launch only: `finalevolution://brain-brawl/launch` |
| 19 | `market_browse` | Market Browse | Sovereign_Shop | FEL-Market | — | Commerce | 3D shop browsing, no scoring |

### 2.3 ⚠️ Registry Discrepancies (Must Resolve Before Ship)

| Issue | Source A | Source B | Delta |
|-------|----------|----------|-------|
| Mode count | `FEL_ModeManager.production.json` declares `total_modes: 17` | Actual entries: 19 | `who_scene_it` + `mario_party_fever` added post-declaration |
| Swift enum | `GameModeId` has 17 cases | ModeManager has 19 | Missing: `who_scene_it`, `mario_party_fever`, `market_browse` |
| Map routing | `ue_mode_maps.json` has 16 mappings | ModeManager has 19 | Missing: `who_scene_it`, `mario_party_fever`, `market_browse` |
| Venue registry | `FEL_VenueRegistry` says `total_game_modes: 16` | 13 venues × modes | No venue for `who_scene_it`, `mario_party_fever`, `market_browse` |
| PRQ weights | `PRQScoring.swift` covers 17 modes | 2 production modes unweighted | `who_scene_it`, `mario_party_fever` have no PRQ weight |
| PRD count | PRD mentions "19 UE5 game modes" | ModeManager says 17 | PRD is ahead of registry metadata |

---

## 3. Map-to-Mode Routing Architecture

### 3.1 Three-Layer Resolution

**Layer 1 — Deep Link (iOS native):**
```
finalevolution://launch?map={MapToken}&mode={mode_id}
  → UFELEmergentDeepLinkSubsystem::ProcessDeepLinkUrl()
  → ParseQueryString() extracts map + mode params
  → ResolveModeToMapToken() → /Game/FEL/Maps/{MapToken}
  → OpenMapFromTokens() → UGameplayStatics::OpenLevel()
  → BroadcastMapLoaded() via EmergentBridge WebSocket
```

**Layer 2 — Dashboard WebSocket (WKWebView overlay):**
```
Frontend GameModesView → launchNativeMode(mode)
  → POST /api/streaming/launch-mode {mode_id}
  → Deep link to finalevolution:// scheme
  → UE subsystem processes deep link (Layer 1)
  → MapLoaded event fires on WebSocket
  → Frontend receives MapLoaded within 10s timeout
  → If timeout → system re-auth (NOT browser fallback)
```

**Layer 3 — E3DS Pixel Streaming (remote):**
```
backend/ue_mode_maps.json (mode_id → UE map token)
  → Pulumi e3ds/__main__.py reads game_mode_maps
  → E3DS stream config provisioned per mode
  → Travel command sent to Pixel Streaming server
  → 1920×1080, NVENC H264, 60fps, 10-30Mbps WebRTC
```

### 3.2 Resolution Chain Priority

1. `[EmergentPlayMap]` INI section (button_id → `/Game/FEL/Maps/...`)
2. `[EmergentButtonArenaMode]` INI section (button_id → arena_mode_id)
3. Hardcoded `ResolveModeToMapToken()` C++ fallback
4. `ue_mode_maps.json` for E3DS/backend routing

### 3.3 Venue Registry (13 Venues)

| Venue | Map Path | Modes | Max Concurrent | Environment |
|-------|----------|-------|----------------|-------------|
| Venice_Beach_Court | `/Game/FEL/Maps/Venice_Beach_Court` | basketball_h2h, basketball_dunk, basketball_3v3 | 4 | venice_beach_sunset |
| Zen_Dojo | `/Game/FEL/Maps/Zen_Dojo` | karate_h2h, karate_endless | 4 | zen_dojo |
| Baseball_Park | `/Game/FEL/Maps/Baseball_Park` | baseball | 2 | stadium_night_game |
| Gridiron_Stadium | `/Game/FEL/Maps/Gridiron_Stadium` | football | 2 | stadium_night_game |
| Soccer_Stadium | `/Game/FEL/Maps/Soccer_Stadium` | soccer | 4 | classic_nba_arena |
| Links_Course | `/Game/FEL/Maps/Links_Course` | golf | 4 | beach_tropical |
| Tennis_Court | `/Game/FEL/Maps/Tennis_Court` | tennis | 2 | rooftop_cityscape |
| Sand_Court | `/Game/FEL/Maps/Sand_Court` | volleyball | 4 | venice_beach_sunset |
| Training_Floor | `/Game/FEL/Maps/Training_Floor` | gymnastics | 2 | cyberpunk_gym |
| Venice_Beach_Surf | `/Game/FEL/Maps/Venice_Beach_Surf` | surfing | 2 | venice_beach_sunset |
| Skate_Park | `/Game/FEL/Maps/Skate_Park` | skateboarding | 4 | neon_arcade |
| Mountain_Slope | `/Game/FEL/Maps/Mountain_Slope` | snowboarding | 4 | winter_outdoor |
| Neuro_Arena | `/Game/FEL/Maps/Neuro_Arena` | brain_brawl | 8 | neon_arcade |

**Missing from VenueRegistry:** Sovereign_Shop (market_browse), Luma_Venice_Shop (in MapsToCook but no venue entry)

### 3.4 Sovereign Sync Protocol

- Target: M4 Pro Mac Mini
- Protocol: WSS over Cloudflare Tunnel
- Encryption: AES-256-GCM
- Signaling: Private (local network)
- UE bridge: `UFELEmergentBridgeSubsystem` with auto-reconnect, bounded outbound queue (128 messages), LAN subnet scanning for hub discovery

---

## 4. PRQ / Readiness / Scan Truth Boundaries

### 4.1 Source of Truth Chain

```
HealthKit (device sensors)
  → Swift HealthKitService (real-time queries)
  → SystemScanRecord (VitalsSnapshot + ReadinessSnapshot + AvatarPerformanceAttributes)
  → Firestore users/{uid}/system_scans/{docId} (append-only archive)
  → Firestore users/{uid}/avatar_performance/current (mutable latest)
  → UnrealSystemScanPayload (epoch-ms JSON for UE bridge)
  → UE C++ FELEmergentBridgeSubsystem (WebSocket → game state)
```

### 4.2 Swift-Side PRQ (Neural Readiness Score)

**Inputs:** HRV SDNN (ms), Resting HR, Heart Rate, Active kcal, Weekly HRV average, Sleep hours

**Formula:**
```
hrvN = clamp(0, 1, (hrv - 18) / 72)
rhrAdj = rhr > 68 ? -12 : (rhr < 55 ? +6 : 0)
calAdj = min(12, kcal / 55)
sleepAdj = (min(1, sleep/8) - 0.5) * 18
PRQ = clamp(15, 100, 32 + hrvN*48 + calAdj + sleepAdj + rhrAdj ± random(-6, 8))
```

**Grades:**
| Score Range | Grade | Arcade Speed | Hang Time | Recovery Mode |
|-------------|-------|-------------|-----------|---------------|
| ≥ 80 | ELITE | 1.15× | +0.30 | No |
| 60–79 | PRIMED | 1.05× | +0.15 | No |
| 40–59 | READY | 1.00× | 0 | No |
| < 40 | RECOVERING | 0.90× | -0.10 | Yes |

### 4.3 Backend PRQ (Weighted Composite)

```json
{
  "strength": 0.15, "speed": 0.15, "endurance": 0.12, "agility": 0.12,
  "power": 0.12, "flexibility": 0.10, "recovery": 0.12, "mental": 0.12
}
```
- **Update trigger:** `on_session_complete`
- **Decay rate:** 0.5 per day idle
- **Boost on streak:** true

### 4.4 Avatar Performance Attributes (0–1 Normalized)

| Attribute | Formula |
|-----------|---------|
| explosiveness | 28% tierExpl + 22% hrReserve + 18% activity + 17% rhrReserve + 15% recoveryHeadroom |
| neuralFocus | 34% hrvVsBaseline + 28% sleepScore + 22% hrvLevel + 16% prqN + trendBoost |
| endurance | 55% prqN + 25% activity + 20% sleep |
| recovery | 45% recoveryHeadroom + 35% sleep + 20% hrvVsBaseline |
| biomechanicalEfficiency | 50% hrvLevel + 30% hrvVsBaseline + 20% rhrReserve |

### 4.5 Firestore Boundaries

- **`users/{uid}/system_scans/{docId}`** — Append-only. Client can create new docs but cannot update/delete historical records. One doc per sync event.
- **`users/{uid}/avatar_performance/current`** — Single mutable document. Latest avatar vector for UE bridge consumption. Client can read/write own doc only.

### 4.6 Unreal Bridge Payload Schema

```json
{
  "schemaVersion": 1,
  "capturedAtEpochMs": 1716422400000,
  "vitals": {
    "heartRateBpm": 72.0,
    "restingHeartRateBpm": 55.0,
    "hrvSdnnMs": 48.0,
    "activeKcal": 320.0,
    "weeklyHrvAverageMs": 42.0,
    "sleepHoursLastNight": 7.5
  },
  "readiness": {
    "neuralReadinessScore": 78.0,
    "grade": "PRIMED",
    "hrvTrend": "IMPROVING",
    "recoveryEstimateHours": 2.0
  },
  "avatar": {
    "schemaVersion": 1,
    "updatedAtEpochMs": 1716422400000,
    "explosiveness": 0.72,
    "endurance": 0.65,
    "recovery": 0.80,
    "neuralFocus": 0.68,
    "biomechanicalEfficiency": 0.71,
    "prqScore": 78.0,
    "readinessGrade": "PRIMED",
    "speedMultiplier": 1.05,
    "hangTimeBonus": 0.15,
    "isRecoveryMode": false
  }
}
```

---

## 5. Scoring & Session Receipt Contracts

### 5.1 Swift Session Receipt

```swift
struct GameSessionResult: Codable, Sendable, Identifiable {
    let id: String
    let gameModeId: String        // GameModeId.rawValue
    let date: Date
    let score: Int
    let opponentScore: Int
    let shardsEarned: Int
    let prqBonus: Double
    let isMultiplayer: Bool
    let duration: Int             // seconds
    var didWin: Bool              // computed: playerScore > opponentScore
}
```

### 5.2 Backend Session Receipt

```json
{
  "user_id": "string",
  "mode_id": "string (GameModeId rawValue)",
  "score": 0,
  "duration": 0,
  "created_at": "2026-05-22T00:00:00Z",
  "xp_awarded": "max(10, score / 5)",
  "activity_feed_entry": {
    "type": "game",
    "detail": "{mode_id}: {score} pts",
    "score": 0
  }
}
```

**XP formula:** `max(10, score / 5)` — no upper cap (risk: exploitable)

### 5.3 PRQ Mode Rewards

```swift
PRQ.modeReward(mode, won, tied, combo, criticals, scoreDifferential):
  base = won ? 2.0 : (tied ? 0.5 : 0.2)
  modeMultiplier = PRQ.modeWeight(mode)  // 0.9–1.5×
  comboBonus = min(1.0, combo × 0.05)
  criticalBonus = min(0.5, criticals × 0.1)
  dominanceBonus = won ? min(0.5, scoreDiff × 0.05) : 0
  return clamp(0, 100, base × modeMultiplier + comboBonus + criticalBonus + dominanceBonus)
```

### 5.4 Per-Mode PRQ Attribute Labels

| Mode | Attribute Label | Success Chance Base |
|------|----------------|-------------------|
| basketball_h2h / 3v3 | Court IQ | 0.40 |
| basketball_dunk | Hang Time | 0.45 |
| karate_h2h / endless | Fight IQ | 0.38 |
| baseball | Bat Speed | 0.35 |
| football | Burst Speed | 0.42 |
| soccer | Shot Accuracy | 0.40 |
| golf | Swing Precision | 0.30 |
| tennis | Rally Control | 0.38 |
| volleyball | Spike Power | 0.40 |
| gymnastics | Form Score | 0.35 |
| surfing | Wave IQ | 0.36 |
| skateboarding | Line Control | 0.36 |
| snowboarding | Edge Control | 0.36 |
| brain_brawl | Cognitive Flex | 0.42 |

---

## 6. Creator Cards & Module Library

### 6.1 Card Schema

```swift
struct CreatorCard {
  let id: String
  let creatorName: String
  let title: String
  let description: String
  let costShards: Int
  let iconName: String
  let accentColor: Color
  let metricsBoost: PerformanceMetrics   // PRQ, vertical, neural drive, efficiency, readiness
  let movementSignature: MovementSignature {
    style: MovementStyle                 // explosive | vertical | fluid | neural | standard
    jumpApex: Double                     // 1.0–1.5× multiplier
    hangTimeFactor: Double               // 1.0–1.8× multiplier
    firstStepBurst: Double               // 1.0–1.5× multiplier
    limbEmission: Double                 // 0–1.0 particle intensity
    trailColor: Color
  }
}
```

### 6.2 Current Catalog (4 Cards)

| Card ID | Creator | Cost (Shards) | PRQ Boost | Vertical Boost | Neural Drive | Movement Style | Animation Speed |
|---------|---------|---------------|-----------|----------------|--------------|----------------|-----------------|
| `coach_v_elite` | Coach V | 500 | +15 | +20 | +10 | explosive | 0.8× |
| `bonds_bounce` | Bonds Bounce | 750 | +12 | +25 | +8 | vertical | 1.0× |
| `flight_lab` | Flight Lab | 600 | +10 | +18 | +15 | fluid | 1.2× |
| `neural_max` | Neural Max | 400 | +8 | +12 | +25 | neural | 0.7× |

### 6.3 Purchase Flow

```
User selects card in CreatorCardsView (frontend)
  → PayPal SDK creates order (backend POST /api/cards/purchase)
  → User approves on PayPal
  → Backend captures payment (paypalrestsdk)
  → MongoDB creator_cards collection updated
  → User's ownedCardIds array updated
  → metricsBoost applied to active profile
  → MovementSignature affects in-game physics
```

### 6.4 Avatar Skin Configuration

Cards influence avatar appearance via `AvatarSkinConfig.fromScan()`:
| PRQ Range | Skin Tone | Outfit Style | Aura Color |
|-----------|-----------|-------------|------------|
| ≥ 80 | elitePurple | elite | (0.6, 0.2, 1.0) |
| 65–79 | cyan | flight | (0, 0.95, 0.9) |
| 50–64 | blue | developing | (0, 0.83, 1.0) |
| < 50 | green | standard | (0.2, 1.0, 0.4) |

---

## 7. Shard Ledger Economy

### 7.1 Transaction Types

```swift
enum ShardTransaction: String, Codable {
    case workoutComplete, gameWin, gameDraw, gameLoss,
         comboBonus, criticalHit, outfitPurchase, blueprintPurchase,
         critiqueRequest, critiqueEarning, dailyBonus, streakBonus, achievementUnlock
}
```

### 7.2 Reward Formulas

**Game Results:**
| Outcome | Base Shards | Bonus |
|---------|-------------|-------|
| Win | 50 | combo × 5 (if combo > 3) + criticals × 10 |
| Draw | 25 | combo × 5 (if combo > 3) + criticals × 10 |
| Loss | 15 | combo × 5 (if combo > 3) + criticals × 10 |

**Workouts:** exercises × base (Foundation: 10, Flight: 15, Elite: 25)

### 7.3 Coach Escrow System

```swift
struct CoachEconomy {
  var totalEarned: Int          // lifetime cleared
  var pendingEarnings: Int      // in escrow
  var clearedEarnings: Int      // released, claimable
  var escrowEntries: [EscrowEntry]
  var critiquesCompleted: Int
  var rating: Double            // weighted average
}

// Flow: critique submitted → EscrowEntry(status: .held)
//       → athlete rates → EscrowEntry(status: .released)
//       → coach claims → clearedEarnings → totalEarned
```

### 7.4 Shop Catalog

| Category | Item | Cost (Shards) |
|----------|------|---------------|
| Outfits | Neon Flux | 500 |
| Outfits | Shadow Elite | 750 |
| Outfits | Chrome V | 1,000 |
| Outfits | Gold Standard | 2,000 |
| Blueprints | Vertical Lab | 300 |
| Blueprints | Speed Matrix | 300 |
| Blueprints | Neural Recovery | 200 |
| Coaching | Form Critique | 150 |
| Coaching | Program Review | 400 |

---

## 8. Backend Data Contracts

### 8.1 MongoDB Collections

| Collection | Purpose | Key Fields |
|------------|---------|------------|
| `users` | User profiles | user_id, email, prq_score, level, xp, streak, coins, avatar_config |
| `user_sessions` | Auth sessions | session_token, user_id, expires_at (ISO, 7-day TTL) |
| `game_sessions` | Game results | user_id, mode_id, score, duration, created_at |
| `prq_metrics` | PRQ history | user_id, metrics (8 weighted dimensions), timestamp |
| `health_metrics` | HealthKit syncs | user_id, hr, rhr, hrv, sleep, kcal, timestamp |
| `education_progress` | Track progress | user_id, track_id, completed_lessons[], quiz_scores{} |
| `bio_digital_progress` | Anatomy modules | user_id, completed_modules[] |
| `creator_cards` | Card ownership | user_id, card_id, purchased_at |
| `orders` | PayPal orders | user_id, order_id, card_id, status, amount |
| `challenges` | PvP challenges | challenger_id, challenged_id, mode_id, status |
| `streaks` | Daily streaks | user_id, current_streak, last_checkin |
| `activity_feed` | Social feed | user_id, type (follow/workout/game/scan), detail, score |
| `coach_sessions` | Coaching requests | user_id, coach_id, type, status |
| `critiques` | Movement analyses | user_id, coach_id, video_id, feedback, rating |
| `videos` | Uploaded clips | user_id, url, mode_id, timestamp |
| `workouts` | Workout logs | user_id, exercises, difficulty, completed_at |
| `tournaments` | Tournament state | tournament_id, participants[], bracket, status |
| `enrollments` | Education enrollment | user_id, track_id, enrolled_at |
| `brain_brawl_launches` | BB launch tracking | user_id, launched_at (needs TTL) |

### 8.2 Firebase Data Connect (PostgreSQL / Cloud SQL)

```graphql
type User @table {
  uid: String! @default(expr: "auth.uid")
  username: String
  email: String
  profilePictureUrl: String
  avatarUrl: String
  firebaseUid: String @unique
}

type Post @table {
  content: String!
  author: User!
  gameModeId: String
  trainingScore: Float
  clipUrl: String
  feedSource: String
  createdAt: Date! @default(expr: "request.time")
  updatedAt: Date! @default(expr: "request.time")
}

type Comment @table {
  content: String!
  post: Post!
  author: User!
  createdAt: Date! @default(expr: "request.time")
}

type PostLike @table {
  post: Post!
  user: User!
}
```

All operations require `@auth(level: USER)`. Mutations bind `firebaseUid_expr` for automatic Auth UID.

### 8.3 Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/system_scans/{scanId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && request.auth.uid == userId;
      // No update or delete — append-only
    }
    match /users/{userId}/avatar_performance/{docId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 8.4 Education Tracks

| Track ID | Lessons | Pass Threshold | XP/Lesson | Certificate |
|----------|---------|---------------|-----------|-------------|
| `common_core` | 6 | 75% | 50 | None (P2 backlog) |
| `stem` | 6 | 75% | 50 | None (P2 backlog) |
| `kinesiology` | 8 + final | 75% / 80% | 50 + 1000 | FEL-AK-{id} |
| `brain_brawl` | 4 (briefings) | 75% | 50 | None |

**Kinesiology Certificate — 4 Gates:**
1. All 8 coursework lessons passed (≥75%)
2. All 4 Bio-Digital anatomy modules mastered (skeletal_basics, muscular_chains, kinetic_chain_pillars, neural_priming)
3. PRQ score ≥ 80
4. Final assessment passed (≥80% on 10 questions)
5. → Issues `FEL-AK-{id}` + 1000 XP (idempotent)

---

## 9. StoreKit / App Store Compliance

### 9.1 Distribution Channel

**APPROVED:** App Store Connect / TestFlight ONLY

**EXPLICITLY PROHIBITED:**
- ❌ AltStore / SideStore
- ❌ OTA manifest feeds (`itms-services://`)
- ❌ Direct IPA install URLs
- ❌ Sideload install pages
- ❌ `manifest.plist` distribution

### 9.2 Required Info.plist Keys

| Key | Value | Purpose |
|-----|-------|---------|
| `CFBundleIdentifier` | `com.finalevolutionlab.sovereign` | App Store record match |
| `CFBundleURLTypes` | `finalevolution://` | Deep link scheme |
| `NSHealthShareUsageDescription` | (present) | HealthKit read permission |
| `NSHealthUpdateUsageDescription` | (present) | HealthKit write permission |
| `UE_PROJECT_NAME` | `FinalEvolutionLab` | Case-sensitive UE descriptor match |

### 9.3 App Store Connect Requirements

- [ ] Export compliance declarations completed
- [ ] Privacy nutrition labels configured
- [ ] HealthKit capability declared
- [ ] Camera usage description (if BioFuel scanner uses camera)
- [ ] Encryption declarations
- [ ] Age rating configured

### 9.4 Superapp Release Metadata Contract

```json
{
  "app_name": "Final Evolution Lab",
  "platform": "ios",
  "distribution_channel": "app_store_connect_testflight",
  "bundle_id": "com.finalevolutionlab.sovereign",
  "apple_app_id": "",
  "build_number": "",
  "version": "",
  "testflight_public_link": "",
  "app_store_connect_build_url": "",
  "release_notes": "",
  "created_at": ""
}
```

Generated via `./scripts/write_superapp_release_metadata.sh` → `artifacts/superapp/final-evolution-lab-ios-release.json`

---

## 10. Cooked Payload Requirements

### 10.1 MapsToCook (11 Maps in DefaultGame.ini)

```ini
[/Script/UnrealEd.ProjectPackagingSettings]
bCookAll=True
+MapsToCook=(FilePath="/Game/FEL/Maps/BaseballPark")
+MapsToCook=(FilePath="/Game/FEL/Maps/Dojo")
+MapsToCook=(FilePath="/Game/FEL/Maps/Gridiron")
+MapsToCook=(FilePath="/Game/FEL/Maps/Links")
+MapsToCook=(FilePath="/Game/FEL/Maps/Luma_Venice_Shop")
+MapsToCook=(FilePath="/Game/FEL/Maps/NeuroArena")
+MapsToCook=(FilePath="/Game/FEL/Maps/SandCourt")
+MapsToCook=(FilePath="/Game/FEL/Maps/SoccerStadium")
+MapsToCook=(FilePath="/Game/FEL/Maps/TennisCourt")
+MapsToCook=(FilePath="/Game/FEL/Maps/TrainingFloor")
+MapsToCook=(FilePath="/Game/FEL/Maps/VeniceBeach")
```

### 10.2 Maps NOT in MapsToCook (Staging — Will Crash if Enabled)

| Map | Mode | Status | Resolution |
|-----|------|--------|------------|
| Skate_Park | skateboarding | staging | Add when promoting to production |
| Mountain_Slope | snowboarding | staging | Add when promoting to production |
| Sovereign_Shop | market_browse | staging | Add when promoting to production |
| Venice_Beach_Surf | surfing | production | ⚠️ May share VeniceBeach token — verify |

### 10.3 Build Targets

| Target | Script | Platform | Output | Key Flags |
|--------|--------|----------|--------|-----------|
| iOS Shipping | `fel_ue5_ios_shipping_package.sh` | iOS | .app + .ipa in Binaries/IOS | --full-cook --shipping --export-ipa |
| Linux E3DS | `fel_ue5_eagle3d_linux_package.sh` | Linux | FEL_UE5_E3DS_Linux_Package.zip | -cook -allmaps -build -stage -pak -archive |
| Win64 Cook | `fel_ue5_win64_cook_only.sh` | Win64 | artifacts/Cooked_Win64 | -cook -stage -archive -skipbuild -allmaps |

### 10.4 Descriptor Safety

The iOS .app bundle MUST contain `cookeddata/` or `.pak` files. Missing cooked content causes "Failed to open descriptor file" on device launch.

**Mitigation chain:**
1. `fel_ue5_ios_shipping_package.sh` promotes fully staged .app from internal staging into Binaries/IOS before Xcode archive
2. Descriptor-safe IPA repacking happens BEFORE `--export-ipa` so signed .ipa is not overwritten
3. `infra/fix_ios_descriptor_path.sh` diagnostic verifies cookeddata/.pak presence
4. Non-iCloud project path required (xattr stripping prevents codesign failures)

### 10.5 Pixel Streaming 2 Configuration

```ini
# DefaultEngine.ini
[PixelStreaming]
Encoder=NVENC
EncoderCodec=H264
TargetBitrate=20000000

[/Script/PixelStreaming.PixelStreamingSettings]
WebRTCMaxFps=60
WebRTCMinBitrate=10000000
WebRTCMaxBitrate=30000000
AllowPixelStreamingInput=true
DefaultResolutionX=1920
DefaultResolutionY=1080

[/Script/PixelStreamingServers.PixelStreamingServers]
bUseInternalSignalling=False  # E3DS manages signalling externally
```

---

## 11. Build/Deploy Checklist

### 11.1 Pre-Build

- [ ] `git checkout anti-gravity-fel && git status` — clean working tree
- [ ] `./infra/fel_prebuild_ci_check.sh --strict` — 6-point identifier alignment:
  1. .uproject filename = FinalEvolutionLab
  2. Target.cs class name matches
  3. DefaultGame.ini BundleIdentifier = com.finalevolutionlab.sovereign
  4. Info.plist UE_PROJECT_NAME = FinalEvolutionLab (case-sensitive)
  5. Directory paths match
  6. [Emergent] config section present
- [ ] Verify `backend/FEL_ModeManager.production.json` has ≥17 modes
- [ ] `./prepare_fel_full_ship.sh` — merge shipping defaults into DefaultGame.ini
- [ ] `./prepare_fel_emergent.sh` — merge Emergent bridge config

### 11.2 iOS Build

- [ ] Verify non-iCloud project path (suggest ~/Developer/)
- [ ] `export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"`
- [ ] `export IOS_DEVELOPMENT_TEAM="ABCDE12345"`
- [ ] `./fel_ue5_ios_shipping_package.sh --verify-only`
- [ ] `./fel_ue5_ios_shipping_package.sh --full-cook --shipping --export-ipa`
- [ ] Verify .app contains cookeddata/ or .pak
- [ ] Verify CFBundleIdentifier, HealthKit keys, URL scheme

### 11.3 Upload & Distribution

- [ ] Upload via Xcode Organizer or Transporter to App Store Connect
- [ ] Answer export compliance, privacy prompts
- [ ] Enable TestFlight
- [ ] `./scripts/write_superapp_release_metadata.sh` → artifacts/superapp/

### 11.4 E3DS Deployment

- [ ] `./fel_ue5_eagle3d_linux_package.sh`
- [ ] Set env vars: E3DS_API_KEY, E3DS_ACCOUNT_ID, FEL_BUILD_URL
- [ ] `./infra/deploy_e3ds.sh` — Pulumi stack provisions app, config, stream URL
- [ ] Verify backend/.env updated with E3DS_STREAM_URL, E3DS_IFRAME_URL, E3DS_APP_ID

### 11.5 Smoke Test

- [ ] Install from TestFlight on real device
- [ ] Launch app — no descriptor error, no grey screen
- [ ] Open WKWebView dashboard overlay
- [ ] Trigger `finalevolution://` deep link
- [ ] Exercise HealthKit permission path
- [ ] Verify system scan sync to Firestore
- [ ] Complete a game session — verify XP + Shard awards
- [ ] Verify E3DS Pixel Streaming connects

---

## 12. Per-Mode Acceptance Tests

### 12.1 Universal Test Matrix (All Production Modes)

For **each** of the 14 production modes, verify:

| # | Test | Pass Criteria |
|---|------|--------------|
| 1 | Deep link launch | `finalevolution://launch?map={token}&mode={id}` opens correct UE map |
| 2 | MapLoaded event | WebSocket `MapLoaded` fires within 10s of deep link |
| 3 | Session receipt | `POST /api/games/session` accepts {mode_id, score, duration} |
| 4 | XP award | XP = max(10, score/5) credited to user |
| 5 | Shard reward | Correct shards awarded (50 win / 25 draw / 15 loss + bonuses) |
| 6 | PRQ delta | PRQ.modeReward() applied with correct mode weight |
| 7 | Activity feed | Entry created with type=game, detail includes mode_id + score |
| 8 | Browser fallback | PlayableGame renders when deep link unavailable (30s timer, combos) |
| 9 | E3DS travel | Pixel Streaming travel command resolves to correct map |
| 10 | Multiplayer sync | (realtime modes only) WebSocket room join/ready/score sync works |

### 12.2 Mode-Specific Tests

| Mode | Additional Test |
|------|----------------|
| basketball_h2h | Charge input → shot release timing affects accuracy |
| basketball_dunk | Dunk contest scoring: style + height + hang time |
| basketball_3v3 | 3-player team formation, help defense logic |
| karate_h2h | Point sparring: strike detection + combo chains |
| karate_endless | Wave progression: difficulty scaling per wave |
| baseball | Swipe input → bat angle + timing = distance |
| football | Kick return: dodge mechanics + sudden death |
| soccer | Penalty shootout: swipe direction + power |
| golf | Swing arc: swipeGolf input → distance + accuracy |
| tennis | Rally ace: serve + volley mechanics |
| volleyball | Drag-to-aim spike: angle + power |
| surfing | Line & balance: rhythmTap timing |
| who_scene_it | Scene recognition quiz: timer + accuracy |
| mario_party_fever | Mini-game rotation: party mode round transitions |

### 12.3 Staging Mode Gates (Before Promotion)

For each staging mode, before promotion to production:
- [ ] Map added to MapsToCook in DefaultGame.ini
- [ ] Mode added to Swift GameModeId enum with correct rawValue
- [ ] Mode added to ue_mode_maps.json
- [ ] Venue entry added/updated in FEL_VenueRegistry.production.json
- [ ] PRQ.modeWeight() and related functions updated
- [ ] FEL_ModeManager.production.json status changed to "production"
- [ ] CI mode count threshold updated if needed
- [ ] Full acceptance test matrix passes

---

## 13. Risks and Non-Negotiable Gates

### 13.1 Critical (P0) — Ship Blockers

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Registry misalignment** | Deep link failures, E3DS routing errors, CI false positives | Single alignment pass across all 5 registries before any build |
| **Descriptor safety** | App crashes on launch ("Failed to open descriptor file") | Script promotes staged .app; verify cookeddata/.pak post-build |
| **Identifier mismatch** | Build fails or app rejected by App Store | 6-point CI check (`fel_prebuild_ci_check.sh --strict`) |

### 13.2 High (P1) — Quality Gates

| Risk | Impact | Mitigation |
|------|--------|------------|
| **MapsToCook gaps** | Staging modes crash if accidentally enabled | Feature-flag staging modes server-side; only add maps when promoting |
| **iCloud project path** | Codesign failures during iOS build | Scripts warn; developer must use ~/Developer path |
| **E3DS Pulumi silent failure** | Deployment succeeds but no stream URL | Validate ue_mode_maps.json before pulumi up; check outputs |
| **Session token timezone** | Premature/late expiry from ISO string parsing | Always compare with UTC; consider epoch-ms migration |

### 13.3 Medium (P2) — Tech Debt

| Risk | Impact | Mitigation |
|------|--------|------------|
| **No XP cap per session** | Exploitable high scores inflate levels | Add server-side cap (e.g., 500 XP/session) |
| **PayPal sandbox hardcoded** | No real purchases in production | Environment variable swap; add CI check for prod creds |
| **server.py monolith (2400 LOC)** | Hard to maintain/debug | Break into routers/ (auth, games, marketplace, sovereign, etc.) |
| **No compound index on education_progress** | Certificate idempotency race condition | Add (user_id, track_id) unique compound index |
| **brain_brawl_launches no TTL** | Collection grows unbounded | Add MongoDB TTL index |

### 13.4 Non-Negotiable Gates (Must Pass Before Any Release)

1. ✅ `fel_prebuild_ci_check.sh --strict` passes (6-point alignment)
2. ✅ Mode registry validates ≥17 modes in CI
3. ✅ .app bundle contains cookeddata/ or .pak (descriptor-safe)
4. ✅ No AltStore/SideStore/OTA/sideload references in codebase
5. ✅ CFBundleIdentifier = com.finalevolutionlab.sovereign
6. ✅ HealthKit usage strings present in Info.plist
7. ✅ `finalevolution://` URL scheme registered
8. ✅ Emergent [Emergent] section present in DefaultGame.ini
9. ✅ All 14 production modes launch successfully via deep link
10. ✅ Session receipts post correctly for all production modes

---

## 14. UE C++ Subsystem Reference

| Subsystem | Type | File | Purpose |
|-----------|------|------|---------|
| `UFELEmergentBridgeSubsystem` | GameInstanceSubsystem | FELEmergentBridgeSubsystem.h/.cpp | WebSocket bridge: match scores, focus keepalive, sovereign sync, hub discovery (subnet scan) |
| `UFELEmergentDeepLinkSubsystem` | GameInstanceSubsystem | FELEmergentDeepLinkSubsystem.h/.cpp | `finalevolution://` deep link parsing, map travel, EmergentPlayMap INI resolution |
| `UFELOverlaySubsystem` | GameInstanceSubsystem | FELOverlaySubsystem.h/.cpp | WKWebView overlay lifecycle, JSON bidirectional messaging, map-loaded handshake |
| `UFELPerformanceManagerSubsystem` | GameInstanceSubsystem | FELPerformanceManagerSubsystem.h/.cpp | iOS thermal monitoring (30s poll), device tiering, dynamic resolution scaling |
| `UFELFocusKeepaliveTickComponent` | ActorComponent | FELFocusKeepaliveTickComponent.h/.cpp | Pixel Streaming 2 focus keepalive for iframe bridging |
| `FELIOSWebOverlay` | Namespace (ObjC++) | FELIOSWebOverlay.h/.mm | iOS WKWebView creation, JS eval, FELBridge message handlers |

### Module Dependencies (FinalEvolutionLab.Build.cs)

```csharp
PublicDependencyModuleNames: Core, CoreUObject, Engine
PrivateDependencyModuleNames: Json, RHI, RenderCore, WebSockets, Sockets
iOS-only: WebKit, MetalRHI
```

---

## 15. Design System Reference

| Property | Value |
|----------|-------|
| Theme | Dark Clinical |
| Background | #050505 (default), #0F0F13 (paper), #16161A (card) |
| Primary | #00E5FF (cyan) |
| Accent Alert | #FF3366 |
| Accent Success | #00FF9D |
| Heading Font | Barlow Condensed |
| Body Font | IBM Plex Sans |
| Mono Font | JetBrains Mono |

---

*Generated from `anti-gravity-fel` branch — Commit: 9519541*
*Date: 2026-05-22*
