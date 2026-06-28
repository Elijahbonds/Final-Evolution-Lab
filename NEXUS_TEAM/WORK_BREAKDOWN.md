# NEXUS_TEAM — Work Breakdown Structure
**Final Evolution Lab (FEL)**  
Branch: `claude/nexus-engine-setup-2qgkik`  
Last Updated: 2026-06-28

This document defines specific tasks, acceptance criteria, and file ownership for each of the 10 specialist agents. Each specialist owns their file scope exclusively — no cross-scope edits.

---

## Specialist 1 — Game Physics & Mechanics Engineer

**File Scope:**
- `FinalEvolutionLab/Models/GoldenEraEngine.swift`
- `FinalEvolutionLab/Models/MatrixPhysicsEngine.swift`
- `FinalEvolutionLab/Models/ArcadePhysics.swift`
- `FinalEvolutionLab/Models/DefensivePhysics.swift`

### Task 1.1 — Frame-Rate Independent Timing (MatrixPhysicsEngine.swift)
**What:** Add delta-time calculation using `CACurrentMediaTime()` so all physics updates are frame-rate independent regardless of device performance.
**How:** Track `lastUpdateTime: CFTimeInterval` property; compute `deltaTime = CACurrentMediaTime() - lastUpdateTime` each physics tick; multiply all velocity/position updates by `deltaTime`.
**Acceptance Criteria:**
- `MatrixPhysicsEngine` has `var lastUpdateTime: CFTimeInterval = 0` property
- Physics update method computes and uses `deltaTime`
- All position/velocity changes multiplied by `deltaTime` (not hardcoded per-frame)
- No `print()` statements — use `OSLog` if logging needed

### Task 1.2 — ComboChain System (GoldenEraEngine.swift)
**What:** Add a consecutive-trick combo multiplier system: each trick within 3 seconds of the last multiplies score by 1.1x per chain link, up to 5x max. A miss or 3-second timeout resets the chain.
**How:** Add `ComboChain` struct with `chainLength: Int`, `multiplier: Double` (computed), `lastTrickTime: CFTimeInterval`. Add `recordTrick(score:)` method and `resetChain()` method.
**Acceptance Criteria:**
- `ComboChain` struct exists with `chainLength`, `multiplier`, `lastTrickTime`
- `multiplier` computed as `min(pow(1.1, Double(chainLength)), 5.0)`
- `recordTrick` increments chain if within 3 seconds, resets if not
- Maximum multiplier capped at 5.0x
- Chain resets on miss (explicit `resetChain()` call)

### Task 1.3 — Physics Constants Namespace (ArcadePhysics.swift)
**What:** Extract all magic numbers into a `PhysicsConstants` enum (caseless, namespaced) so they are named and discoverable.
**How:** Add `enum PhysicsConstants` with `static let` constants for gravity, friction, bounceCoefficient, dragCoefficient, maxVelocity, etc. Replace all literal numbers in the physics code with named constants.
**Acceptance Criteria:**
- `enum PhysicsConstants` (no cases, used as namespace) with at least 6 `static let` constants
- Constants cover: gravity, friction, bounceCoefficient, maxVelocity, and at least 2 others present in the file
- No unexplained magic numbers remain in physics calculations
- All constants are typed (e.g., `static let gravity: Double = 9.81`)

### Task 1.4 — HelpDefenseBreakdown (DefensivePhysics.swift)
**What:** Add `HelpDefenseBreakdown` struct to model per-defender coverage analysis with letter grades.
**How:** Add `HelpDefenseBreakdown` struct with `defenderCoverageScores: [String: Double]` (player ID → 0-100 score), `helpRotationGrade: DefenseGrade` enum (A/B/C/D/F), and `averageCoverageScore: Double` computed property.
**Acceptance Criteria:**
- `DefenseGrade` enum with cases: a, b, c, d, f (or A, B, C, D, F)
- `HelpDefenseBreakdown` struct with `defenderCoverageScores`, `helpRotationGrade`, `averageCoverageScore`
- `averageCoverageScore` computed as average of all values in `defenderCoverageScores`
- `helpRotationGrade` computed from `averageCoverageScore` (A: 90+, B: 80-89, C: 70-79, D: 60-69, F: <60)

**Commit:** `feat(physics): delta-time, combo chains, physics constants, defense breakdown`

---

## Specialist 2 — Avatar & Biometrics Engineer

**File Scope:**
- `FinalEvolutionLab/Models/AvatarStateMachine.swift`
- `FinalEvolutionLab/Models/BiomechanicsAudit.swift`
- `FinalEvolutionLab/Models/PerformanceMetrics.swift`

### Task 2.1 — PRQTier Enum (AvatarStateMachine.swift)
**What:** Add `PRQTier` enum mapping PRQ score ranges to named tiers, each with a movement speed multiplier.
**Tiers:** Elite (≥90, 1.25x), Primed (75-89, 1.1x), Ready (60-74, 1.0x), Recovering (40-59, 0.85x), Depleted (<40, 0.65x)
**How:** Add `enum PRQTier` with computed `speedMultiplier: Double` and `label: String`. Add `var tier: PRQTier` computed property on the avatar state machine (or user profile reference).
**Acceptance Criteria:**
- `PRQTier` enum with all 5 cases
- `speedMultiplier` computed property with exact values (0.65, 0.85, 1.0, 1.1, 1.25)
- `tier(for prq: Double) -> PRQTier` static method or computed from PRQ value
- PRQ 90 → Elite, 89 → Primed, 75 → Primed, 74 → Ready, 40 → Recovering, 39 → Depleted

### Task 2.2 — MovementEfficiencyScore (BiomechanicsAudit.swift)
**What:** Add `MovementEfficiencyScore` struct with 6 biomechanical sub-scores (0-100 each) and an overall efficiency score.
**How:** Add struct with `kneeTracking`, `hipAlignment`, `coreEngagement`, `shoulderPosition`, `ankleStability`, `headPosition` properties (all `Double`, 0-100). Add `overallEfficiency: Double` computed as average of all 6.
**Acceptance Criteria:**
- `MovementEfficiencyScore` struct with all 6 named properties
- Each property is `Double` type with valid range 0-100 (enforced via `min(max(value, 0), 100)` or documented)
- `overallEfficiency` computed as `(kneeTracking + hipAlignment + coreEngagement + shoulderPosition + ankleStability + headPosition) / 6.0`

### Task 2.3 — PerformanceTrend (PerformanceMetrics.swift)
**What:** Add `PerformanceTrend` type computing trend direction (improving/stable/declining) over last 7 sessions per metric, plus weekly PRQ peak and low.
**How:** Add `TrendDirection` enum (improving, stable, declining). Add `PerformanceTrend` struct with `direction: TrendDirection`, `metric: String`, `changePercent: Double`. Add `weeklyPeakPRQ: Double` and `weeklyLowPRQ: Double` to the performance metrics model.
**Acceptance Criteria:**
- `TrendDirection` enum with `improving`, `stable`, `declining` cases
- `PerformanceTrend` struct with `direction`, `metric`, `changePercent`
- `weeklyPeakPRQ` and `weeklyLowPRQ` properties or computed vars
- Trend computed from last 7 session values (stub if session array not present)

**Commit:** `feat(avatar): PRQ tiers, movement efficiency scoring, performance trends`

---

## Specialist 3 — Economy & Marketplace Engineer

**File Scope:**
- `FinalEvolutionLab/Models/ShardEconomy.swift`
- `FinalEvolutionLab/Models/VaultResources.swift`
- `FinalEvolutionLab/Models/CreatorCard.swift`

### Task 3.1 — ShardEarningRule + ShardLedger (ShardEconomy.swift)
**What:** Define all shard-earning events with their rewards; create a transaction ledger.
**Earning Events & Rewards:**
- matchWin: 50 shards, matchTie: 25, dailyStreak: 20, prqMilestone: 100, achievementUnlock: 30, creatorCardPurchase: 10
**How:** Add `ShardEarningRule` enum with associated shard reward. Add `ShardTransaction` struct (id, event: ShardEarningRule, amount: Int, timestamp: Date). Add `ShardLedger` struct with `transactions: [ShardTransaction]` and `balance: Int` computed property.
**Acceptance Criteria:**
- `ShardEarningRule` enum with all 6 cases and `shardReward: Int` computed
- `ShardTransaction` struct with `id: UUID`, `event: ShardEarningRule`, `amount: Int`, `timestamp: Date`
- `ShardLedger` struct with `transactions` array and `balance` computed as sum of all transaction amounts
- `addTransaction(_ tx: ShardTransaction)` mutating method on `ShardLedger`

### Task 3.2 — VaultSlot + VaultState (VaultResources.swift)
**What:** Model individual vault slots with type, cost, cooldown, and lock state.
**Slot Types:** bronze (100 shards, 1.1x, 1h), silver (300 shards, 1.5x, 4h), gold (750 shards, 2.0x, 12h), platinum (2000 shards, 3.0x, 24h)
**How:** Add `VaultSlotType` enum (bronze/silver/gold/platinum) with `unlockCost`, `rewardMultiplier`, `cooldownHours`. Add `VaultSlotState` enum (locked/available/onCooldown). Add `VaultSlot` struct with `type`, `state`, `unlockedAt: Date?`, `cooldownEndsAt: Date?`.
**Acceptance Criteria:**
- `VaultSlotType` enum with all 4 cases and correct `unlockCost`, `rewardMultiplier`, `cooldownHours`
- `VaultSlotState` enum with `locked`, `available`, `onCooldown` cases
- `VaultSlot` struct with all required properties
- `currentState(at date: Date) -> VaultSlotState` computed method

### Task 3.3 — CardRarity + CardBundle + CreatorCardMetrics (CreatorCard.swift)
**What:** Add rarity system with drop rates, bundle purchasing, and engagement metrics.
**Rarities:** common (10% drop, 100 shards), rare (2% drop, 500 shards), epic (pack-only, 2000 shards), legendary (tournament-only, non-purchasable)
**How:** Add `CardRarity` enum with `dropRate: Double` and `shardCost: Int?`. Add `CardBundle` struct with `cards: [CreatorCard]` (3-5 cards) and `bundleDiscount: Double` (0.0-1.0). Add `CreatorCardMetrics` struct with `views: Int`, `gameUses: Int`, `fanInteractions: Int`.
**Acceptance Criteria:**
- `CardRarity` enum with all 4 cases and correct `dropRate` and `shardCost?` (legendary = nil)
- `CardBundle` struct with `id: UUID`, `cards: [CreatorCard]`, `bundlePrice: Int` (computed with discount), `bundleDiscount: Double`
- `CreatorCardMetrics` struct with `views`, `gameUses`, `fanInteractions` all as `Int`
- `CreatorCard` model has `rarity: CardRarity` and `metrics: CreatorCardMetrics` properties added

**Commit:** `feat(economy): shard ledger, vault slots, card rarity + bundles`

---

## Specialist 4 — Academy & Education Engineer

**File Scope:**
- `FinalEvolutionLab/Models/CurriculumTrack.swift`
- `FinalEvolutionLab/Models/MovementEducationData.swift`
- `FinalEvolutionLab/Models/DrawingInTutorialModels.swift`

### Task 4.1 — Lesson Content Models (CurriculumTrack.swift)
**What:** Add difficulty ratings, quiz structures, and rich lesson content to the curriculum model.
**How:** Add `LessonDifficulty` enum (beginner/intermediate/advanced/expert). Add `QuizQuestion` struct (questionText: String, options: [String] (4 items), correctAnswerIndex: Int, explanation: String). Add `LessonContent` struct (videoURLPlaceholder: String, keyPoints: [String] (3-5 items), estimatedMinutes: Int).
**Acceptance Criteria:**
- `LessonDifficulty` enum with all 4 cases
- `QuizQuestion` struct with `questionText`, `options: [String]` (enforced count 4), `correctAnswerIndex: Int`, `explanation: String`
- `LessonContent` struct with `videoURLPlaceholder`, `keyPoints: [String]`, `estimatedMinutes: Int`
- Lesson model has `difficulty: LessonDifficulty`, `content: LessonContent?`, `questions: [QuizQuestion]` added

### Task 4.2 — Bio-Digital Anatomy Modules (MovementEducationData.swift)
**What:** Add 4 complete `BioDigitalModule` structs matching the kinesiology cert gate requirements.
**Modules:** skeletal_basics, muscular_chains, kinetic_chain_pillars, neural_priming
**How:** Add `BioDigitalModule` struct with `id: String`, `title: String`, `learningObjectives: [String]` (exactly 5), `masteryThreshold: Double` (0.80 for all), `isCompleted: Bool`. Add all 4 as static instances in a `BioDigitalModuleLibrary` enum or struct.
**Acceptance Criteria:**
- `BioDigitalModule` struct with `id`, `title`, `learningObjectives: [String]`, `masteryThreshold: Double`, `isCompleted: Bool`
- All 4 module IDs present: `skeletal_basics`, `muscular_chains`, `kinetic_chain_pillars`, `neural_priming`
- Each module has exactly 5 learning objectives (real, specific anatomical content)
- `masteryThreshold` = 0.80 for all 4 modules
- `BioDigitalModuleLibrary` with static access to all 4

### Task 4.3 — Tutorial Phases + DrawingStroke (DrawingInTutorialModels.swift)
**What:** Add tutorial phase tracking and biomechanically-scored drawing strokes.
**How:** Add `TutorialPhase` enum (intro/demonstration/practice/assessment). Add `DrawingStroke` struct with `id: UUID`, `timestamp: Date`, `qualityScore: Double` (0-100), `biomechanicalCorrectnessPercent: Double` (0-100).
**Acceptance Criteria:**
- `TutorialPhase` enum with all 4 cases
- `DrawingStroke` struct with `id`, `timestamp`, `qualityScore`, `biomechanicalCorrectnessPercent`
- Tutorial model has `currentPhase: TutorialPhase` property
- `DrawingSession` or similar grouping with `strokes: [DrawingStroke]` and `averageQuality: Double` computed

**Commit:** `feat(academy): lesson content models, bio-digital modules, tutorial phases`

---

## Specialist 5 — Arena Registry Specialist

**File Scope:**
- `backend/FEL_ModeManager.production.json`
- `backend/FEL_VenueRegistry.production.json`
- `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json`
- `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json`
- `backend/ue_mode_maps.json`

### Task 5.1 — Audit All 19 Modes Across 5 Registries
**What:** Read every file, cross-reference all 19 mode IDs, identify missing fields and missing modes.
**19 Mode IDs:** basketball_h2h, basketball_dunk, basketball_3v3, karate_h2h, karate_endless, baseball, football, soccer, golf, tennis, volleyball, surfing, skateboarding, snowboarding, gymnastics, brain_brawl, who_scene_it, court_carnival, market_browse

### Task 5.2 — FEL_ModeManager Required Fields (per mode entry)
Each mode entry must have ALL of: `map`, `gamemode_class`, `binary`, `status` (production/staging/preview/non-game-module), `max_players`, `min_players`, `session_timeout_seconds`, `prq_weight`

### Task 5.3 — ArenaSettings Required Fields (per mode entry)
Each mode entry must have ALL of: `unrealOpenLevelPackage`, `modeDisplayName`, `unrealBasketballSlice`, `scoreTarget`, `timeLimit`, `inputScheme`, `physicsPreset`

### Task 5.4 — FEL_VenueRegistry Required Fields (per mode entry)
Each entry must have ALL of: `id`, `analyticsMode`, `venueKey`, `displayVenue`, `spawnPoint` (object with x/y/z), `ambientSFX`

### Task 5.5 — Cross-Registry Consistency
- Mode IDs must be identical across all 5 files
- Venue paths must match format `/Game/FEL/Venues/{VenueName}/{VenueName}`
- `market_browse` has no economy fields (no PRQ weight, no session receipt)
- Staging/preview modes have `prq_weight: 0` or economy disabled flag
- Validate JSON after EVERY edit: `python3 -c "import json; json.load(open('FILE'))"` must pass

**Acceptance Criteria:**
- All 19 modes present in all 5 registries
- All required fields present for every mode in each registry
- `python3 -m json.tool` passes for all 5 files
- No mode ID inconsistencies across files

**Commit:** `feat(registry): complete all 19 mode configs across 5 registry files`

---

## Specialist 6 — Multiplayer & Match Engineer

**File Scope:**
- `FinalEvolutionLab/Models/Matchmaking.swift`
- `FinalEvolutionLab/Models/HelpDefense3v3.swift`
- `FinalEvolutionLab/Models/VersusMatchOutcome.swift`
- `FinalEvolutionLab/Services/MultipeerService.swift`

### Task 6.1 — MatchmakingConfig + MatchmakingPool (Matchmaking.swift)
**What:** Define per-mode player count configurations and skill-bracket matching.
**Player Counts:** karate_h2h=1v1, basketball_h2h=1v1, tennis=2v2, volleyball=2v2, basketball_3v3=3v3, golf/baseball/gymnastics/surfing/skateboarding/snowboarding=solo
**How:** Add `MatchmakingConfig` struct with `modeId: String`, `playersPerTeam: Int`, `teamsCount: Int`. Add `MatchmakingPool` struct with `config: MatchmakingConfig`, `queueTimeEstimate: TimeInterval`, `prqBracketRange: ClosedRange<Double>` (always ±15 PRQ).
**Acceptance Criteria:**
- `MatchmakingConfig` with all mode player counts defined as static library
- `MatchmakingPool` with `queueTimeEstimate` and `prqBracketRange` (width 30: ±15)
- `prqBracketRange` computed as `(basePRQ - 15)...(basePRQ + 15)`
- `static func config(for modeId: String) -> MatchmakingConfig?` lookup method

### Task 6.2 — RotationScheme + DefensiveSet (HelpDefense3v3.swift)
**What:** Model defensive rotation schemes and coverage zones for 3v3 basketball.
**How:** Add `RotationScheme` enum (packLine/helpAndRecover/switching/matchup). Add `CoverageZone` struct (x: Double, y: Double, width: Double, height: Double) — CGRect equivalent. Add `Defender` struct with `playerId: String`, `coverageZone: CoverageZone`. Add `DefensiveSet` with `scheme: RotationScheme`, `defenders: [Defender]` (exactly 3).
**Acceptance Criteria:**
- `RotationScheme` enum with 4 cases
- `CoverageZone` struct (pure Swift, no UIKit import) with x, y, width, height
- `Defender` struct with `playerId` and `coverageZone`
- `DefensiveSet` with `scheme` and `defenders: [Defender]` (count enforced or documented as 3)

### Task 6.3 — XPReward + ShardReward + MatchReport (VersusMatchOutcome.swift)
**What:** Add economy reward computation and detailed post-match reporting.
**How:** Add `xpEarned: Int` and `shardsEarned: Int` computed properties based on win/loss/tie + PRQ delta + streak. Add `MatchReport` struct with `roundScores: [(Int, Int)]`, `trickHighlights: [String]`, `efficiencyRating: Double` (0-100).
**Acceptance Criteria:**
- `xpEarned` computed: win=100, tie=50, loss=25, + streakBonus (10 per streak day, max 50), + PRQ delta bonus (PRQ delta * 5)
- `shardsEarned` computed: win=50, tie=25, loss=15 (matches economy system in server.py)
- `MatchReport` struct with `roundScores`, `trickHighlights`, `efficiencyRating`
- `VersusMatchOutcome` has `report: MatchReport?` property

**Commit:** `feat(multiplayer): matchmaking config, 3v3 defense schemes, XP/shard rewards`

---

## Specialist 7 — Training & Movement Engineer

**File Scope:**
- `FinalEvolutionLab/Models/TrainingProgram.swift`
- `FinalEvolutionLab/Models/TrainingProgramData.swift`
- `FinalEvolutionLab/Models/MovementSnackEngine.swift`
- `FinalEvolutionLab/ViewModels/TrainingViewModel.swift`

### Task 7.1 — PeriodizationBlock + Calendar (TrainingProgram.swift)
**What:** Add classic sports science periodization to training program structure.
**Blocks:** accumulation (PRQ 40-74, high volume), intensification (PRQ 60-84, moderate volume + intensity), realization (PRQ 75+, peak performance), deload (any PRQ, recovery week)
**How:** Add `PeriodizationBlock` enum with `recommendedPRQRange: ClosedRange<Double>` and `volumeGuideline: String`. Add `TrainingPhaseCalendar` struct mapping `week: Int → block: PeriodizationBlock` for a 4-week cycle.
**Acceptance Criteria:**
- `PeriodizationBlock` enum with all 4 cases
- Each case has `recommendedPRQRange` and `volumeGuideline: String`
- `TrainingPhaseCalendar` struct with `phaseMap: [Int: PeriodizationBlock]` (weeks 1-4)
- Default 4-week cycle: week1=accumulation, week2=intensification, week3=realization, week4=deload

### Task 7.2 — Training Program Library (TrainingProgramData.swift)
**What:** Ensure at least 6 complete training programs with 4 weeks of sessions.
**Required Programs:** beginner_basketball, intermediate_basketball, advanced_basketball, beginner_karate, intermediate_karate, advanced_karate
**How:** Each program needs: `id`, `name`, `level: TrainingLevel`, `sport: String`, `weeks: [TrainingWeek]` (4 weeks), each week with `sessions: [TrainingSession]` (3-5 sessions), each session with `exercises: [Exercise]` and `setsRepsRest: [(sets: Int, reps: Int, restSeconds: Int)]`.
**Acceptance Criteria:**
- At least 6 programs present in the data file
- Each program has exactly 4 `TrainingWeek` entries
- Each week has at least 3 sessions
- Each session has at least 4 exercises with sets/reps/rest defined

### Task 7.3 — MovementSnack Library (MovementSnackEngine.swift)
**What:** Build a catalog of 12 named short-duration movement snacks across categories.
**Categories:** activation, mobility, strength, power, recovery
**Required Snacks (at least 12):** Hip Flexor Flow (mobility, 3 min), Glute Bridge Series (activation, 4 min), Band Pull-Apart Circuit (strength, 5 min), Box Jump Primer (power, 3 min), Thoracic Rotation (mobility, 4 min), Ankle Stability Complex (activation, 3 min), Mini-Band Walk (strength, 4 min), Explosive Step-Up (power, 5 min), Foam Roll Sequence (recovery, 5 min), Breathing Reset (recovery, 3 min), Lateral Band Walks (activation, 3 min), Plank Flow (strength, 4 min)
**How:** Add `SnackCategory` enum. Add `MovementSnack` struct with `name`, `durationMinutes: Int`, `category: SnackCategory`, `equipment: SnackEquipment` enum (none/band/box), `instructions: [String]` (3-5 strings). Add `MovementSnackLibrary` with `static let all: [MovementSnack]` array of 12+.
**Acceptance Criteria:**
- `SnackCategory` enum with all 5 cases
- `SnackEquipment` enum with none/band/box
- `MovementSnack` struct with all required properties
- `MovementSnackLibrary.all` contains at least 12 snacks
- Each snack has 3-5 instruction strings

### Task 7.4 — ViewModel Enhancements (TrainingViewModel.swift)
**What:** Add snack scheduling stub and periodization phase computation.
**How:** Add `func scheduleSnack(_ snack: MovementSnack, reminderMinutes: Int)` method (stub logging the schedule via OSLog). Add `var currentPeriodizationPhase: PeriodizationBlock` computed property that determines phase from `currentWeekInCycle` and user PRQ.
**Acceptance Criteria:**
- `scheduleSnack` method exists with correct signature
- Method uses OSLog (not print) for logging
- `currentPeriodizationPhase` computed property exists
- Phase determined by week-in-cycle (1=accumulation, 2=intensification, 3=realization, 4=deload)

**Commit:** `feat(training): periodization blocks, program library, movement snack catalog`

---

## Specialist 8 — QA Test Engineer

**File Scope:**
- `FinalEvolutionLabTests/GameLogicTests.swift`
- `backend/tests/test_nexus_systems.py` (CREATE NEW)
- `scripts/smoke_test_modes.py`

### Task 8.1 — Swift Tests (GameLogicTests.swift)
**What:** Add 15+ new `@Test` cases using Swift Testing framework.
**Required Coverage:**
1. ShardEarningRule.matchWin returns 50 shards
2. ShardEarningRule.dailyStreak returns 20 shards
3. ShardLedger balance computes sum correctly
4. VaultSlot.bronze unlock cost = 100 shards
5. VaultSlot.platinum cooldown = 24 hours
6. VaultSlotState transitions (locked → available → onCooldown)
7. CardRarity.common dropRate = 0.10
8. CardRarity.legendary shardCost is nil
9. CardBundle bundlePrice applies discount
10. PRQTier.elite requires score ≥ 90
11. PRQTier.depleted speedMultiplier = 0.65
12. VersusMatchOutcome win xpEarned ≥ 100
13. VersusMatchOutcome loss shardsEarned = 15
14. ComboChain multiplier after 2 tricks ≈ 1.21
15. ComboChain max multiplier capped at 5.0
16. TrainingProgram beginner_basketball has 4 weeks
17. MovementSnackLibrary has ≥ 12 snacks
**Acceptance Criteria:** 15+ `@Test` functions; each uses `#expect()` not `XCTAssert`; all pass (or are clearly stubs for types not yet defined)

### Task 8.2 — Backend Tests (backend/tests/test_nexus_systems.py — NEW)
**What:** Create new pytest file with 20+ tests for nexus systems.
**Required Test Coverage:**
1-5. Education track progression: all 4 tracks present, lesson count correct per track (6/6/8/4), XP per lesson = 50
6-9. Kinesiology cert gates: PRQ < 80 fails gate 3, all 4 bio-digital modules required, final assessment requires 80%
10-12. Brain brawl: cooldown enforcement (cannot launch twice within cooldown), deep link format correct
13-15. System scan unified endpoint: returns scan/cards/arena/academy keys, response is valid JSON
16-19. Mode registry validation: all 19 modes present in FEL_ModeManager, each has required fields, market_browse has no prq_weight > 0
20+. Economy validation: XP_CAP_PER_SESSION = 500, shard table values match (win=50, draw=25, loss=15)
**How:** Import json, os; use pytest; mock or directly test data constants; validate JSON files directly where API tests are not feasible.
**Acceptance Criteria:** File created at `backend/tests/test_nexus_systems.py`, 20+ test functions with `test_` prefix, `python3 -m pytest backend/tests/test_nexus_systems.py -v` passes with 0 failures

### Task 8.3 — Smoke Test Enhancement (scripts/smoke_test_modes.py)
**What:** Enhance existing smoke test with all-19-modes completeness check and JSON schema validation.
**How:** Add `test_all_19_modes_present()` function checking all 19 mode IDs in FEL_ModeManager; add `test_json_schema_validation()` checking required fields for each mode; add `test_arena_settings_completeness()` verifying all 19 modes in ArenaSettings have required gameplay params.
**Acceptance Criteria:**
- Existing tests still pass
- New `test_all_19_modes_present` checks all 19 IDs
- New schema validation checks `map`, `status`, `max_players`, `min_players` fields
- `python3 scripts/smoke_test_modes.py` exits with code 0

**Commit:** `test: 15+ Swift tests, 20+ backend tests, enhanced smoke test coverage`

---

## Specialist 9 — CI/DevOps Engineer

**File Scope:**
- `.github/workflows/nexus-ci.yml` (CREATE NEW)
- `scripts/verify_production_readiness.sh`
- `NEXUS_TEAM/DEPLOYMENT_GUIDE.md` (CREATE NEW in NEXUS_TEAM/)

### Task 9.1 — GitHub Actions Workflow (nexus-ci.yml)
**What:** Create CI workflow for the `claude/nexus-engine-setup-2qgkik` branch.
**Jobs Required:**
1. `validate-registries`: Check out repo, run `python3 -c "import json; json.load(open('FILE'))"` for all 5 JSON registries
2. `backend-tests`: `python3 -m pytest backend/tests/ -v --tb=short`
3. `frontend-build`: `cd frontend && npm ci && npm run build`
4. `swift-pattern-check`: `grep -r "@Observable\|@MainActor" FinalEvolutionLab/Models/ FinalEvolutionLab/ViewModels/ | wc -l` (must be > 0)
**Runner:** `ubuntu-latest` for ALL jobs (no macOS needed — UE5 builds not in CI)
**Trigger:** `push` and `pull_request` on `claude/nexus-engine-setup-2qgkik`
**Acceptance Criteria:** Valid YAML that `yamllint` accepts; all 4 jobs defined; uses `actions/checkout@v4` and `actions/setup-python@v5`

### Task 9.2 — Production Readiness Script Enhancement (scripts/verify_production_readiness.sh)
**What:** Add new checks to the existing script.
**New Checks to Add:**
- Check `NEXUS_TEAM/STATUS.md` exists: `[ -f NEXUS_TEAM/STATUS.md ] || fail "STATUS.md missing"`
- Validate all 5 JSON registry files (python3 json.load)
- Backend test count gate: `pytest --collect-only -q backend/tests/ | grep "test session starts" -A 5` (ensure ≥ 20 tests)
- All 19 modes have `status` field: `python3 -c "..."` check on FEL_ModeManager
**Acceptance Criteria:** Script is valid bash (`bash -n script.sh` passes); new checks added without removing existing ones; all new checks use exit code 1 on failure with descriptive error message

### Task 9.3 — Deployment Guide (NEXUS_TEAM/DEPLOYMENT_GUIDE.md)
**What:** Create complete step-by-step deployment reference for all environments.
**Required Sections:**
1. Local Development Setup (backend, frontend, dependencies)
2. Running Backend Tests (`cd backend && python3 -m pytest tests/ -v`)
3. Running Frontend Dev Server (`cd frontend && npm install && npm start`)
4. Validating Registry Files (all 5 files, commands)
5. Running CI Checks Locally (what nexus-ci.yml does locally)
6. macOS-Required Steps (UE5 cook, Xcode archive, Fastlane/xcrun)
7. App Store / TestFlight Submission steps
**Acceptance Criteria:** All 7 sections present; commands are copy-pasteable; macOS-only steps clearly labeled with "Requires macOS + Xcode"

**Commit:** `feat(ci): nexus-ci workflow, enhanced production readiness checks, deployment guide`

---

## Specialist 10 — Leaderboard & Social Engineer

**File Scope:**
- `FinalEvolutionLab/Services/GlobalLeaderboardService.swift`
- `FinalEvolutionLab/Models/LeaderboardEntry.swift`
- `FinalEvolutionLab/Services/SocialShareCoordinator.swift`
- `FinalEvolutionLab/Services/TrainingLabSocialBridge.swift`

### Task 10.1 — LeaderboardScope + Fetch (GlobalLeaderboardService.swift)
**What:** Add scope-based leaderboard fetching with Firestore query pattern.
**How:** Add `LeaderboardScope` enum (global/friends/regional/modeSpecific). Add `fetchLeaderboard(scope: LeaderboardScope, modeId: String?, limit: Int) async throws -> [LeaderboardEntry]` function stub with Firestore query structure documented in comments. Add `@Published var currentUserRank: Int?` property.
**Acceptance Criteria:**
- `LeaderboardScope` enum with 4 cases
- `fetchLeaderboard` async throws function with correct signature
- `currentUserRank: Int?` published property (use `@Published` or `@Observable` pattern matching existing file)
- Firestore collection path documented: `leaderboards/{scope}/{modeId}/entries`

### Task 10.2 — Sport + TrendArrow + BadgeSet (LeaderboardEntry.swift)
**What:** Enrich leaderboard entries with sport categorization, trend direction, and earned badges.
**How:** Add `Sport` enum with all 12 sports (basketball/karate/baseball/football/soccer/golf/tennis/volleyball/gymnastics/surfing/skateboarding/snowboarding). Add `TrendArrow` enum (up/down/stable) computed from `positionDelta: Int`. Add `Badge` enum (firstPlace/topTen/personalBest/weeklyChamp/streakLord). Add `BadgeSet` struct with `earned: [Badge]`.
**Acceptance Criteria:**
- `Sport` enum with all 12 sport cases
- `TrendArrow` computed from positionDelta: positive → up, negative → down, 0 → stable
- `Badge` enum with all 5 cases
- `BadgeSet` struct with `earned: [Badge]` and `contains(_ badge: Badge) -> Bool`
- `LeaderboardEntry` has `sport: Sport`, `trend: TrendArrow`, `badges: BadgeSet` added

### Task 10.3 — ShareableContent + Share Methods (SocialShareCoordinator.swift)
**What:** Add content type enumeration and system share sheet integration.
**How:** Add `ShareableContent` enum (matchResult/prqMilestone/leaderboardRank/certEarned/creatorCard). Add `generateShareCard(content: ShareableContent) -> UIImage` stub method (returns UIImage placeholder). Add `shareToSystem(content: ShareableContent) async` method using `UIActivityViewController` documented in comment (UIKit pattern — stub body).
**Acceptance Criteria:**
- `ShareableContent` enum with all 5 cases
- `generateShareCard` returning `UIImage` (stub: return `UIImage()`)
- `shareToSystem` async method with UIActivityViewController pattern comment
- Imports `UIKit` for UIImage/UIActivityViewController

### Task 10.4 — PostTemplate + Caption Generator (TrainingLabSocialBridge.swift)
**What:** Add templated social post generation with emoji-rich captions.
**Templates:** postWorkout, postMatch, prqUpdate, certEarned, weeklyRecap
**How:** Add `PostTemplate` enum with all 5 cases. Add `generateCaption(template: PostTemplate, profile: UserProfile) -> String` method generating specific captions (each includes athlete name, relevant metric, 2-3 emojis, hashtag).
**Sample Captions:**
- postWorkout: "Just crushed my training sesh! PRQ: {prq} 💪🔥 #FinalEvolutionLab #Athlete"
- postMatch: "Match day results are in! {sport} score: {score} 🏆⚡ #FELArena"
- prqUpdate: "PRQ milestone unlocked: {prq}! Feeling {tier} 🧠💯 #FELScan"
- certEarned: "Just earned my Applied Kinesiology Certificate! 🎓🏅 #FELAcademy"
- weeklyRecap: "Week in review: {sessions} sessions, peak PRQ {peak} 📊🔥 #FELProgress"
**Acceptance Criteria:**
- `PostTemplate` enum with all 5 cases
- `generateCaption` returns non-empty String for all 5 templates
- Each caption includes at least 2 emojis and 1 hashtag
- Profile name/PRQ/sport interpolated where applicable

**Commit:** `feat(social): leaderboard scopes, share cards, post templates, badges`
