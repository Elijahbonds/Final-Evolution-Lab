# NEXUS Game Mode — Inspiration Audit & Enhancement Spec

**Date:** 2026-07-14  
**Scope:** All 19 registered arena modes in `app/gameplay/`  
**Authority:** `docs/NEXUS_MODES_CAPABILITY.md` · `seeles_work/designs/fel_per_game_mode_blueprint_design.md` · mode headers (`app/gameplay/include/nexus/gameplay/`)  
**Purpose:** Compare every game mode against its real-world inspiration(s), identify parity gaps, and define concrete mechanic additions to bring FEL closer to world-class feel.

---

## 1. Inspiration Master Table

| Mode ID | Cluster | Inspiration Source(s) | Current Depth | Parity Gap (honest) |
|---------|---------|----------------------|---------------|---------------------|
| `basketball_h2h` | flagship | NBA Jam / Venice pickup | Throw-catch timing + HotStreak | No drive lane, no defense AI pressure |
| `basketball_dunk` | flagship | NBA Slam Dunk Contest (TNT broadcast) | QTE dunk → style score → 21pts | No judge panel visible, no signature clip library wired to score |
| `basketball_3v3` | outcome | Streetball / AND1 Mixtape culture | OutcomeSportMode pulse | 6-player logic stubs; no AI teammate passing |
| `karate_h2h` | outcome | Street Fighter II / Mortal Kombat II | HP pulse scoring | No hit-stun, no block-break, no super meter |
| `karate_endless` | flagship | COD Zombies × Naruto Storm arena | Wave spawner + Naruto lock-on + chakra/jutsu | Jutsu special wired but no combo visual chain; no perks stacking between waves |
| `baseball` | outcome | Wii Sports Baseball / MLB Home Run Derby | Pulse → HR count | No batting eye (no pitch speed variance), no fielder catch on miss |
| `football` | outcome | Madden Mobile / NFL Blitz kick return | TD pulse scoring | No route running, no stiff-arm QTE, no crowd noise pulse |
| `soccer` | flagship (upgraded) | FIFA Penalty Shootout / Rocket League 3v3 | Full 3D 3v3 + ghost AI defenders | No keeper dive animation, no power curve on shots |
| `golf` | outcome | Wii Sports Golf / PGA Tour Mobile | Pulse → pin distance | No wind gust mechanic, no lie/hazard system |
| `tennis` | outcome | Wii Sports Tennis / Top Spin | Sets compare via ace pulse | No rally continuation, no spin read mechanic |
| `volleyball` | outcome | Beach Volleyball Mobile / Windjammers | Rally-to-25 pulse | No dig/set/spike 3-touch sequence |
| `surfing` | action | Kelly Slater Pro Surfer / WSL Mobile | Carve+aerial+wipeout loop | No wave multiplier select, no barrel bonus |
| `skateboarding` | action | Tony Hawk's Pro Skater 1+2 | Named tricks + manual + 2-min run | Special tricks unlocked but no level/combo multiplier screen |
| `snowboarding` | action | SSX Tricky / 1080° Avalanche / Shaun White | Tricky meter + uber trick + gate system + ghost | Ghost only tracks best score, not ghost replay line |
| `gymnastics` | action | Olympic Games Tokyo / Beat Saber rhythm | D-score + E-score + apparatus rotation + fall deductions | No music sync, no crowd reaction to combo |
| `brain_brawl` | neuro | HQ Trivia / Jeopardy! / QuizUp | Difficulty tiers + category select + stadium reveal pause | No lifeline system, no audience poll, no streak-broken comeback mechanic |
| `who_scene_it` | neuro | Scene It? / FilmQuiz | Buzz-in + scene recognition | No media screen sync to question, no leaderboard reveal |
| `court_carnival` | flagship | Mario Party / WarioWare / Jackbox Party Pack | Star system + item cards + chaos event + 12-space board | No ATW star purchase animation, no carnival pad visual |
| `story_mode` | adventure | Kingdom Hearts 1 / Sonic Adventure 2 | 20-space board + zone bosses + rail/flight traversal | No cutscene system, no NPC dialogue, no world map |

---

## 2. Per-Mode Deep Dive: Compare & Contrast

### 2.1 Basketball Cluster

#### `basketball_h2h` / `venice_pickup_mode` — NBA Jam × Venice pickup culture

**What NBA Jam did well (inspiration):**
- "On Fire" streak mechanic — 3 consecutive makes = fire effect, reduced goal radius, immunity to defense
- Exaggerated arcade physics: impossible hang time, turbo button
- Two-player co-op same team

**What FEL has now:**
- HotStreak (3 consecutive makes → `kOnFireMultiplier = 1.5×`) ✅
- Differentiated shot events: Shoot / Drive / Alley-Oop / Bank Shot ✅
- Throw-catch physics with FRC composite scaling impulse ✅

**Gaps vs. inspiration:**
- No drive-lane dash burst (Turbo button equivalent)
- No defense poke-steal action (NBA Jam had steal on button mash)
- Alley-oop requires two players but only 1 body_id supported today
- No on-screen flame visual trigger (On Fire → HUD event only)

**Enhancements to add:**
1. `onDriveLane(float turboBoost)` — brief sprint burst before shot, increases catch radius chance
2. `onStealAttempt(bool success)` — opponent's impulse reduced by 30% on success; adds `steal` HUD event
3. Multi-body tracking: expose `body_id` map for home/away ball entities (prep for Alley-Oop 2P)
4. `isOnFire` field in `stateJson()` and HUD relay — drives SwiftUI flame overlay

---

#### `basketball_dunk` — NBA Slam Dunk Contest (TNT broadcast + 2K MyCareer)

**What the Dunk Contest does well (inspiration):**
- Five judges each hold a 10-card → aggregate score; player sees running total
- Signature dunk library: specific named dunks with brand recognition (Jordan from free throw, Vince Carter 360 windmill)
- Crowd noise and camera angle sync to apex moment
- Ghost AI shows your personal best replay

**What FEL has now:**
- `DunkStyle` enum with 8 entries including `k360Scoop`, `kOffBackboardWindmill` (2.2× pts) ✅
- QTE apex window with 5 grade levels ✅
- `GhostDifficulty` enum (Easy/Normal/Hard) ✅
- Charge → Launch → Airborne → Scored phase machine ✅

**Gaps vs. inspiration:**
- Judge panel not exposed in `stateJson()` — score appears as raw int, not 5-judge split
- `kFreeDribble` phase has no free court movement sim (PRQ-gated path)
- No crowd noise proxy in HUD envelope
- Ghost does not emit a replay line (needs waypoint recording)

**Enhancements to add:**
1. `JudgePanel` struct: 5 float scores (8.0–10.0 each, averaged) → expose in `stateJson()` as `judge_scores[5]`
2. Free-dribble courtside marker: add `onCourtMove(Vec3 pos)` → records approach angle, affects `launchDistanceMeters` scoring bonus
3. `crowdHype` float (0–1) in HUD envelope, driven by QTE grade + consecutive dunks
4. Personal-best waypoint ghost: `m_ghostWaypoints` vector storing last-run `(pos, phase)` pairs

---

#### `basketball_3v3` — Streetball / AND1

**Gaps:** OutcomeSportMode pulse only; needs teammate pass AI stub.

**Enhancements to add:**
1. Promote to dedicated `Streetball3v3Mode` class with pass→shoot event chain
2. Add `passBall(int toTeammate)` command that buffs next shot timing by 20%

---

### 2.2 Karate Cluster

#### `karate_endless` — Naruto Storm × COD Zombies Survival

**What Naruto Storm does well (inspiration):**
- Lock-on system: camera snaps between player and nearest enemy
- Chakra meter: fills on successful hits, depletes on jutsu special
- Jutsu specials: cinematic, area-of-effect, multi-hit
- Sub-bar (awakening): transforms character at threshold

**What COD Zombies does well (inspiration):**
- Wave escalation: enemy count + speed increases per round
- Intermission economy: spend points on wall buys between rounds
- Exfil option: voluntary early exit retains banked score

**What FEL has now:**
- `Camera3D` Naruto-style orbit camera with lock-on snap ✅
- `m_chakraMeter` fills on hit, depletes on jutsu ✅
- `KarateWavePhase::kJutsu` cinematic pause ✅
- Wave escalation via `WaveSpawner` ✅
- Shrine perks at intermission (speed/power/guard) ✅
- Exfil after wave ≥ 10 ✅
- 1–4 local co-op slots ✅

**Gaps vs. inspiration:**
- No awakening sub-bar (Naruto Storm: Sage Mode / Nine-Tails Cloak)
- Jutsu is a single AoE hit; no multi-phase jutsu sequence
- No wall-buy economy between rounds (shrine only gives one perk, no shard spend option)
- No combo-visual chain display (Storm shows hit-count as floating numbers)
- No enemy type variety (ranged archer, armored bruiser, speed runner)

**Enhancements to add:**
1. **Awakening bar** (`m_awakeningMeter`): fills at 50% chakra overflow → `onAwakenActivate()` → 5-second power-up state (damage ×2, speed +30%)
2. **Multi-hit jutsu sequence**: `jutsuStage` counter (3 phases) — each `chakraStrike()` during kJutsu advances → final stage deals AoE burst
3. **Enemy archetypes** via `EnemyAI::kArchetype` enum: `kBrawler` (default), `kArcher` (ranged), `kArmored` (block immune to light strike), `kSpeeder` (high aggression, low HP)
4. **Combo float display**: expose `m_currentComboChain` per player slot in `stateJson()` alongside `combo_text` string ("5 HIT!", "10 HIT!", "MAX COMBO!")
5. **Shard wall-buy**: at intermission allow `onPurchasePerk(std::string_view perkId, int shardCost)` — persists to next wave (complementary to shrine)

---

#### `karate_h2h` — Street Fighter II × Mortal Kombat II

**What SF2 does well (inspiration):**
- Stun bar: repeated hits fill stun gauge → opponent briefly stunned
- Chip damage: blocked hits still deal small HP loss
- Super meter: fills on damage dealt/taken → executes super combo
- Round structure: best of 3

**What FEL has now:**
- OutcomeSportMode HP compare via pulse ✅
- `CombatAction` enum: light/heavy/block/dodge/counter ✅
- Counter mechanic in `CombatSystem::resolve()` ✅

**Gaps vs. inspiration:**
- No stun meter — block-break requires landing heavy strike directly
- No chip damage (block = zero damage)
- No super meter system
- Single round vs. best-of-3 structure

**Enhancements to add:**
1. Promote `karate_h2h` from OutcomeSportMode to dedicated `KarateH2HMode` class
2. `m_stunMeter` (0–100): fills on blocked hits (10/hit) → at 100 = 1.5s stun (opponent cannot act)
3. `chipDamageRate = 0.15F`: fraction of heavy strike damage that bleeds through on block
4. `m_superMeter` (0–100): fills on damage dealt → `onSuperCombo()` unblockable 3-hit sequence
5. Best-of-3 rounds: `m_roundsWon[2]`, first to 2 wins wins match

---

### 2.3 Action Sports Cluster

#### `skateboarding` — Tony Hawk's Pro Skater 1+2

**What THPS does well (inspiration):**
- 2-minute run with score-at-buzzer (already implemented ✅)
- Named trick library with difficulty multipliers (partially implemented ✅)
- Manual balance mechanic (implemented ✅)
- Special tricks unlocked after skill threshold (implemented ✅)
- COMBO MULTIPLIER system: trick chains multiply without touching ground
- Pro skater roster with signature tricks
- Secret tape / SKATE letters collection objectives

**Gaps vs. inspiration:**
- No SKATE letter collection (THPS core meta goal)
- No revert mechanic (landing a halfpipe trick → manual continuation)
- No grind variety (only "manual" category; no 50-50, nosegrind, bluntslide as distinct grinds from `rail_grind_system`)
- No scoring feedback screen mid-run (THPS shows last trick name + points on-screen)

**Enhancements to add:**
1. **SKATE letters**: `m_lettersCollected` bitfield (5 bits); `onCollectLetter(char letter)` → complete set = 5000pt bonus
2. **Revert mechanic**: `onRevert(float timing)` after `onNamedTrick` from halfpipe → chains into manual without combo break
3. **Grind routing via `rail_grind_system`**: wire `RailGrindSystem::snapToRail()` and `grindTrick()` into `SkateboardingMode` — currently these are standalone
4. **Mid-run last-trick display**: `m_lastTrickName` already stored → expose `last_trick_display` + `last_trick_points` in `stateJson()`
5. **Combo screen**: add `m_bestComboPoints` tracking for end-of-run summary

---

#### `snowboarding` — SSX Tricky / 1080° Avalanche / Shaun White

**What SSX Tricky does well (inspiration):**
- Tricky meter (already implemented ✅)
- Uber trick cinematic (implemented ✅)
- Grab vocabulary: indy, melon, stalefish, mute, tail, nose (implemented ✅)
- Personal-best ghost (score stored ✅, waypoints not stored)
- Course gates with time pressure (gates implemented ✅)

**What 1080° Avalanche adds:**
- Avalanche chase mode: outrun the avalanche (time pressure that accelerates)

**What Shaun White adds:**
- Halfpipe segment: score on consecutive air passes

**Gaps vs. inspiration:**
- Ghost tracks score but no ghost replay line
- No avalanche chase pressure event
- No halfpipe segment variant
- No trick-name announcement (SSX displays trick name on-screen as you grab)

**Enhancements to add:**
1. **Ghost waypoint replay**: `m_ghostWaypoints` — record `{timeMs, lineScore, gatesPassed}` tuples; replay as ghost line on subsequent run
2. **Avalanche event** (optional chaos trigger): `onAvalancheStart()` — adds 30s deadline, score multiplier ×1.5 if escaped
3. **Trick announcement**: expose `m_lastGrabName` + `m_lastGrabStyle` in `stateJson()` as `trick_announcement` string
4. **Halfpipe segment**: `onHalfpipeAir(float height, float rotation)` → adds styleMeter points; consecutive halfpipe airs chain bonus

---

#### `surfing` — Kelly Slater Pro Surfer / WSL Mobile

**What Kelly Slater does well (inspiration):**
- Wave selection: player chooses when to paddle into a wave (timing = score ceiling)
- Barrel riding: score multiplier inside the tube
- Two-judge panel: each judge scores 0.1–10.0, best 2 of 4 waves count

**What FEL has now:**
- `SurfingMode` with carve / aerial / wipeout ✅
- `kWinScore = 75` accumulated ✅

**Gaps vs. inspiration:**
- No wave-select timing (wave auto-starts)
- No barrel mechanic
- No judge panel (single numeric score)

**Enhancements to add:**
1. **Wave select**: `onPaddleIn(float timing)` before `kRun` phase — timing (0–1) sets `m_waveCeiling` (max achievable score for this wave)
2. **Barrel bonus**: `onBarrelEntry()` / `onBarrelExit(float durationSeconds)` — inside barrel multiplies score ×2.0 per second held; `m_inBarrel` bool in `stateJson()`
3. **Judge panel**: `m_judgeScores[2]` (best-of-4-waves tracking) → expose in `stateJson()`
4. **Wave count**: 4-wave heat structure; `m_waveIndex` (0–3); session ends after 4 waves or wipeout limit

---

#### `gymnastics` — Olympic Games / Beat Saber rhythm

**What Olympic gymnastics scoring does well:**
- D-score (declared difficulty) + E-score (execution) (implemented ✅)
- Apparatus rotation: floor / beam / vault / bars (implemented ✅)
- Fall deduction 1.0 points (implemented ✅)

**What Beat Saber adds:**
- Music-synced hit windows
- Full-combo streak multiplier

**Gaps vs. inspiration:**
- No music sync layer (rhythm taps are purely timing-normalized, not beat-mapped)
- No artistry score component (FIG scores artistic impression separately)
- No crowd reaction trigger (audience reaction to perfect/fall)

**Enhancements to add:**
1. **Beat map layer**: `m_beatPhase` float (0–1, looping per bar at 120 BPM sim) → `rhythmTap` called within 0.05 of beat = `kBeatPerfect` bonus (+0.5 E-score)
2. **Artistry score**: `m_artistryTotal` already in header but not computed → wire: `+0.2` per consecutive `kPerfect` tap, cap 3.0
3. **Crowd reaction event**: `stateJson()` emits `crowd_reaction: "roar" | "gasp" | "silence"` based on last tap grade
4. **Apparatus difficulty modifier**: vault and bars have tighter `perfectThreshold()` than floor → expose `apparatus_difficulty_label` in state

---

### 2.4 Neuro Cluster

#### `brain_brawl` — HQ Trivia × Jeopardy! × QuizUp

**What HQ Trivia does well:**
- Lifelines: Extra Life (revive), Skip question
- Audience vote visible before answer reveal
- Final standings leaderboard reveal with drama

**What Jeopardy! adds:**
- Daily Double: bet your score before seeing the question
- Category selection per clue (implemented ✅)

**What QuizUp adds:**
- Real-time opponent — see their answer indicator before reveal

**What FEL has now:**
- `BrainBrawlTier` difficulty escalation ✅
- Category selection (5 categories) ✅
- Stadium reveal pause 1.5s ✅
- Streak bonus + multiplier ✅
- Remote opponent support ✅
- PRQ delta on match end ✅

**Gaps vs. inspiration:**
- No lifeline system
- No Daily Double mechanic
- No audience-poll display in HUD
- No Final Jeopardy all-in wager mechanic

**Enhancements to add:**
1. **Lifeline system**: `m_lifelines` enum set (`kExtraLife`, `kSkip`, `kAudiencePoll`); `onUseLifeline(LifelineType)` — each usable once per match
2. **Daily Double**: every 3rd question has `isDailyDouble` flag → player wagers `[1, m_cognitiveScore]` before seeing question
3. **Audience poll**: on `kAudiencePoll` lifeline → `stateJson()` emits `audience_distribution: {A:%, B:%, C:%, D:%}` (weighted random toward correct answer 60%)
4. **Final Brawl wager**: at question 9 → mandatory all-in wager phase; correct = doubles score, wrong = halves

---

#### `who_scene_it` — Scene It? / FilmQuiz × Jackbox Trivia Murder Party

**What Scene It? does well:**
- Video clip plays → player identifies scene, actor, quote, or franchise
- Buzz-in race: first to buzz locks in, others locked out for 3s
- DVD-style chapter select (multiple question types per round)

**What FEL has now:**
- Environment layout spec: 9 media screens + buzz-in triggers ✅ (in layout docs)
- `who_scene_it_mode.cpp` exists ✅

**Gaps vs. inspiration:**
- No media clip sync protocol (screen content not driven by question type)
- No buzz-in lockout timer for slower players
- No round-type variety (all questions same style)

**Enhancements to add:**
1. **Question type enum**: `kFilmClip`, `kActorFace`, `kQuoteRead`, `kFranchiseLogo` — each triggers different MSC_HERO screen content
2. **Buzz-in lockout**: `m_buzzedPlayerId` set on first buzz → other players locked for 3s, exposed in `stateJson()`
3. **Round variety**: 5-question set cycles through all question types at least once
4. **Accuracy streaks**: 3+ correct in a row = "Hot Seat" bonus: next question worth 2× points

---

### 2.5 Flagship Party Cluster

#### `court_carnival` — Mario Party × WarioWare × Jackbox

**What Mario Party does well:**
- Dice roll + token movement across spaces
- Stars purchasable at ATW landmark (costs coins)
- Item cards: Mushroom (roll twice), Star steal, Warp
- Mini-games every 4th round (all players compete)
- Chaos events: random reversal, board shake

**What WarioWare adds:**
- Micro-game lightning round: rapid-fire 5-second challenges

**What Jackbox adds:**
- Cross-device input (anyone's phone becomes a controller)
- Audience voting mechanic

**What FEL has now:**
- `CarnivalSpaceType` with pad triggers + dice roll ✅
- `CarnivalItemCard` system (Boost/Steal/Warp) ✅
- Star purchase at ATW spaces ✅
- `kStarsToWin = 3` ✅
- Chaos event every 4th round ✅
- `ShootingDrill` and `SpeedDribble` mini-games ✅
- 3D board with `kBoardSpaces` world positions ✅
- `throw_catch_physics` integration ✅

**Gaps vs. inspiration:**
- No WarioWare micro-game lightning round
- No audience voting in chaos events
- No visual star counter / ATW animation trigger in `stateJson()`
- No Happening Space (board-wide random event affecting all players)

**Enhancements to add:**
1. **Micro-game lightning round** (every 8th round): `onMicroGameSequence()` → 5 rapid mini-games, each 5s; winner gets 10 bonus shards
2. **Happening space type**: `CarnivalSpaceType::kHappening` → `onHappeningTrigger()` → board-wide effect (reverse token order, all players gain/lose 5 coins)
3. **Star counter in HUD**: expose `m_playerStars[4]` array in `stateJson()` alongside `m_tokenPositions`
4. **ATW star purchase animation trigger**: `stateJson()` emits `atw_purchase_triggered: true` when landing on ATW space and purchasing → drives SwiftUI star-pop animation

---

### 2.6 Story Mode — "Court Carnival: Legends of the Boardwalk"

**Design references (per header):** Kingdom Hearts 1 traversal × Sonic Adventure 2 speed × COD Zombies board economy

**What KH1 does well:**
- Lock-on targeting with action commands
- Platforming through themed worlds with zone-specific enemy behavior
- Portal loading: only active zone in memory

**What SA2 adds:**
- Momentum-based speed (Sonic stages) vs. methodical approach (Shadow stages)
- Collectables (Chao, emblems)

**What FEL has now:**
- 20-space 3D board ✅
- Zone streaming via `StageStreamManager` ✅
- Rail grind (`RailGrindSystem`), flight (`FlightSystem`), combat (`CombatSystem`) ✅
- 5 boss configs with HP/speed/aggression ✅
- `StoryPhase` machine (board → rail → flight → boss → complete) ✅
- PRQ-scaled physics via `ArcadePhysicsParams` ✅

**Gaps vs. inspiration:**
- No lock-on camera snap in story traversal (KH1 core)
- No NPC dialogue system
- No collectable system (SA2's Chao equivalent)
- No zone-to-zone warp (KH1 world map)
- Final boss has no multi-phase transition (KH1 bosses change form)

**Enhancements to add:**
1. **Lock-on toggle**: `onLockOnTarget(std::string_view enemyId)` → sets `m_lockOnTarget` in `StoryMode`; camera offset bias toward target
2. **Multi-phase final boss**: `m_finalBossPhase` (0–2); at 66% HP triggers phase 2 (speed×1.3), at 33% triggers phase 3 (aggression 1.2, adds ranged attack)
3. **Collectables**: `m_emblems[4]` array (one per zone) → found by exploring `kBonus` spaces; unlock bonus PRQ on story complete
4. **NPC hint line**: `stateJson()` emits `npc_hint: "<string>"` when player is stuck (3+ consecutive failed actions in same zone)

---

## 3. Cross-Cutting Enhancements (All Modes)

### 3.1 Biometric-Driven Difficulty (FEL Differentiator)

**Gap:** All modes accept manual input but only `throw_catch_physics` actively scales with FRC/IAP composites. Every mode should breathe with the athlete.

**Enhancement:** Expose `prq_readiness_modifier` in every mode's `stateJson()`:
- `prq > 80` (Primed): timing windows +10%, opponent pressure −15%
- `prq 60–79` (Ready): baseline
- `prq < 60` (Fatigued): timing windows −10%, opponent pressure +10%
- Wire via `m_prqEngine` reference (already in `prq_engine.h`)

### 3.2 Combo Visual Language

**Gap:** Most modes track combos internally but don't expose a display-ready string.

**Enhancement:** Universal `combo_display` field in all `stateJson()` outputs:
```json
{ "combo_display": "10 HIT!", "combo_color": "#FFD700" }
```
Color progression: white (1–4) → orange (5–9) → gold (10–14) → purple ELITE (15+)

### 3.3 Session Receipt Telemetry Extension

**Gap:** Receipts send score + duration but no per-mode signature metrics.

**Enhancement:** Add `mode_signature` block to all session receipts:
- Basketball: `{ "peak_streak": N, "on_fire_count": N }`
- Karate: `{ "max_combo": N, "jutsu_activations": N }`
- Skateboarding: `{ "best_combo_pts": N, "specials_landed": N }`
- Snowboarding: `{ "uber_tricks": N, "gates_passed": N }`
- Brain Brawl: `{ "peak_streak": N, "lifelines_used": N }`

### 3.4 Crowd/Atmosphere HUD Event

**Gap:** No ambient crowd reaction in HUD envelope today.

**Enhancement:** All modes emit `atmosphere_event` in HUD relay:
```json
{ "atmosphere_event": "roar" | "gasp" | "cheer" | "silence", "intensity": 0.0–1.0 }
```
Driven by: QTE grade, combo length, score difference threshold.

---

## 4. Gap → Enhancement Priority Queue

| Priority | Enhancement | Mode(s) | Effort | Inspiration alignment |
|----------|------------|---------|--------|-----------------------|
| P0 | `isOnFire` in VenicePickup stateJson + HUD overlay trigger | basketball_h2h | XS | NBA Jam "on fire" |
| P0 | `judge_scores[5]` in DunkContestMode stateJson | basketball_dunk | S | Slam Dunk Contest broadcast |
| P0 | PRQ readiness modifier wired to all mode timing windows | all 18 | M | FEL differentiator |
| P1 | Enemy archetype enum (Brawler/Archer/Armored/Speeder) in KarateEndless | karate_endless | M | Naruto Storm enemy variety |
| P1 | Awakening bar + onAwakenActivate() | karate_endless | M | Naruto Storm awakening |
| P1 | SKATE letter collection + revert mechanic | skateboarding | S | THPS core objectives |
| P1 | Wave select timing + barrel bonus in SurfingMode | surfing | S | Kelly Slater Pro Surfer |
| P1 | Lifeline system in BrainBrawlMode | brain_brawl | S | HQ Trivia |
| P1 | Ghost waypoint replay struct in SnowboardingMode | snowboarding | S | SSX replay ghost |
| P1 | Universal combo_display in all stateJson() | all 18 | S | QoL / visual polish |
| P2 | Stun meter + chip damage + super meter in KarateH2H (dedicated class) | karate_h2h | L | Street Fighter II |
| P2 | Multi-phase final boss in StoryMode | story_mode | M | Kingdom Hearts 1 |
| P2 | Wave select + judge panel in SurfingMode | surfing | M | WSL Mobile |
| P2 | Micro-game lightning round in CourtCarnival | court_carnival | M | WarioWare |
| P2 | Beat map layer in GymnasticsMode | gymnastics | M | Beat Saber |
| P2 | Daily Double + Final Brawl wager in BrainBrawl | brain_brawl | M | Jeopardy! |
| P2 | Passballs + dedicated Streetball3v3Mode | basketball_3v3 | L | AND1 / NBA2K streetball |
| P3 | mode_signature telemetry block in session receipts | all 18 | S | Analytics foundation |
| P3 | atmosphere_event in HUD relay | all 18 | S | Immersion |
| P3 | Question-type enum in WhoSceneIt | who_scene_it | M | Scene It? variety |
| P3 | Happening space + micro-game in CourtCarnival | court_carnival | M | Mario Party |
| P3 | Lock-on toggle in StoryMode traversal | story_mode | M | Kingdom Hearts |
| P3 | NPC hint line in StoryMode | story_mode | XS | QoL |

---

## 5. Implementation Notes

### Adding to existing mode headers

All additions follow the established pattern in the codebase:

```cpp
// In the mode header, add to public section:
auto onNewMechanic(float param) -> Result<nlohmann::json>;

// In stateJson(), add new fields:
j["new_field"] = m_newField;
```

Enums follow the GCC 13.3 workaround pattern already established:
```cpp
namespace nexus { namespace gameplay {
  enum class NewEnum : std::uint8_t;
} } // namespace nexus::gameplay
```

### Build gate

All additions must keep `ctest --test-dir build-headless` green. Add test cases in:
- `tests/unit/gameplay/gameplay_test.cpp` (flagship integration tests)
- Follow the `flagship_*_validate_only_integration` naming convention

### Ship bar (from NEXUS_MODES_CAPABILITY.md)

New mechanics satisfy **Validate PASS** when:
- Agent command + JSON response documented
- Integration test green
- No renderer dependency (headless only)

**Ship PASS** additionally requires:
- iOS device proof with SceneKit/Metal viewport
- Combo display visible in SwiftUI HUD

---

## 6. Summary: FEL vs. Inspiration — Honest Assessment

| Dimension | Inspiration bar | FEL today | FEL + enhancements |
|-----------|----------------|-----------|-------------------|
| Physics feel | Rigid-body + animation-driven | Intent queue (stubs → Jolt) | +PRQ readiness modifier |
| Progression hooks | THPS specials, SSX Tricky meter | Specials unlocked, Tricky meter ✅ | +SKATE letters, +Revert, +Ghost replay |
| Biometric integration | N/A (no inspiration game has this) | FRC/IAP drives throw-catch | **Full PRQ modifier across all modes** — FEL USP |
| Combat depth | SF2 stun/super, Naruto awakening | Wave combat + jutsu | +Stun meter, +Awakening bar, +Enemy archetypes |
| Party/social | Mario Party stars + chaos | Board + item cards + chaos ✅ | +Micro-game lightning, +Happening spaces |
| Trivia/neuro | HQ Trivia lifelines, Jeopardy Daily Double | Category select + streak ✅ | +Lifelines, +Daily Double, +Final Brawl wager |
| Visual feedback | On-screen combo text, crowd reactions | Score in receipt only | +combo_display, +atmosphere_event, +crowd_reaction |
| Session economy | Post-game stats | Shards + PRQ delta ✅ | +mode_signature telemetry block |

**FEL's unique edge over every inspiration game:** biometric-coupled gameplay mechanics (FRC/IAP → impulse, timing windows, opponent pressure). No inspiration game ties athletic readiness data to moment-to-moment gameplay outcomes. This is the product's north star and must be the primary differentiator surface in every mode's Ship PASS requirements.

---

*Next action: implementation team picks P0 items → adds to `gameplay_test.cpp` → runs `ctest --test-dir build-headless`. Ship bar items require device + Instruments proof per `NEXUS_QUALITY_BAR.md`.*

---

## 7. Registry Alignment Patches (Cross-Reference from Blueprint Audit)

These patches are required **before** any new mechanic additions go live — they fix structural mismatches between registries.

| Patch | File | Change |
|-------|------|--------|
| P-1 | `FEL_ModeManager.production.json` | Fix `total_modes` 17→19; promote `who_scene_it` + `court_carnival` to production; fix ALL `/Game/FEL/Maps/X` → `/Game/FEL/Venues/{Token}/{Token}` |
| P-2 | `GameMode.swift` (iOS) | Add `.whoSceneIt`, `.courtCarnival`, `.marketBrowse` cases with inputScheme + GameModeRegistry entries |
| P-3 | `ue_mode_maps.json` | Add `who_scene_it→Neuro_Arena`, `court_carnival→Venice_Beach_Court`, `market_browse→Vault_Shop` |
| P-4 | `DefaultGame.ini [FELPlayMap]` | Remove wrong `skateboarding→VeniceBeach`, `snowboarding→VeniceBeach`; add `who_scene_it→NeuroArena`, `court_carnival→VeniceBeach` |
| P-5 | `MapsToCook` | Add `Skate_Park` + `Mountain_Slope` when modes are promoted |
| P-6 | `ArenaSettings.json` | Split unified `karate` → `karate_h2h` + `karate_endless`; add `who_scene_it`, `court_carnival`; fix `snowboarding` venue from TrainingFloor → Mountain_Slope |
| P-7 | VenueRegistry | Add `karate_endless`, `who_scene_it`, `court_carnival`, `market_browse` entries |
| P-8 | `FELEmergentDeepLinkSubsystem.cpp` | Rename `mario_party_fever` → `court_carnival` in `GetModeToVenueMap()` |
| P-9 | `backend/server.py` | Add shard + PRQ delta to `create_game_session`; add XP cap 500/session; rename mario-party endpoints → court-carnival |

**Do Not Ship Until checklist (hard gates):**
- [ ] `nexus_validate_production_modes.sh` 18/18 PASS @ mobile
- [ ] `FEL_ModeManager.production.json` total_modes = 19, no wrong-venue staging routes  
- [ ] who_scene_it + court_carnival NOT in "production" registry until smoke test PASS
- [ ] All 12 production deep links resolve on device
- [ ] Economy: `create_game_session` awards shards + PRQ delta (currently missing)
- [ ] Brain Brawl: standard session endpoint (not `/api/brain-brawl/submit`)
- [ ] Outcome-sport modes: mode-distinct UX beyond generic pulse display

---

## 8. Completion Snapshot (Honest)

| Layer | % Complete | Blocker |
|-------|-----------|---------|
| iOS shell (19 modes routable) | ~85% | UE embed, consistent SceneKit load |
| NEXUS headless protocol (`fel.*`) | ~78% | Live iOS biometric transport |
| UE mode implementations | ~62% | 5 stub modes, cooked iOS builds |
| Asset pipeline (venue meshes) | ~50% | 12 venue stubs → run `nexus_import_assets.py --convert` |
| NEXUS GPU runtime | ~70% | iOS Metal renderer; mesh LOD |
| **Overall product** | **~65%** | Device Metal (V-013) + live receipt POST (V-012) are P0 ship gates |

**FEL's irreplaceable edge** over every listed inspiration game: biometric-coupled gameplay mechanics — FRC/IAP composites drive throw impulse, timing windows, and opponent pressure in real time. No Wii Sports, NBA 2K, Tony Hawk, or SSX game does this. This is the product north star and must be the primary differentiator surface in every mode's Ship PASS requirements.
