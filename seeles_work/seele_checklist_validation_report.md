# Seele's First-5-Venue UE Checklist — Validation Report

**Date:** 2026-05-22  
**Branch:** `anti-gravity-fel` (commit 9519541)  
**Master Blueprint:** `/home/ubuntu/designs/fel_master_architecture_blueprint_design.md`  
**Repository:** `/home/ubuntu/github_repos/Final-Evolution-Lab/`

---

## Executive Summary

| # | Check | Result | Details |
|---|-------|--------|---------|
| 1 | Mode ID Registry Match | ⚠️ **WARNING** | 3 registries diverge — 19 (ModeManager) vs 17 (Swift) vs 16 (ue_mode_maps) |
| 2 | Venue to Cooked Path Mapping | ❌ **FAIL** | 3 staging maps missing from MapsToCook; surfing map path ambiguous |
| 3 | Session Event Contracts | ⚠️ **WARNING** | 2 production modes (`who_scene_it`, `mario_party_fever`) lack standard session receipt flow |
| 4 | Production / Staging Status | ❌ **FAIL** | Blueprint says 14 Prod / 5 Staging, but ModeManager JSON has `who_scene_it` + `mario_party_fever` as "production" without matching infrastructure |
| 5 | Preview Mode Classification | ⚠️ **WARNING** | No explicit staging gate mechanism found — only JSON `status` field |
| 6 | Known Gaps Verification | ✅ **PASS** | `who_scene_it`, `court_carnival` (not in repo — blueprint references as known gap), `market_browse` confirmed incomplete |
| 7 | iOS Cooked Payload Completeness | ⚠️ **WARNING** | 11 maps listed but path format diverges between blueprint and actual DefaultGame.ini |
| 8 | Smoke Test Criteria | ⚠️ **WARNING** | Blueprint defines comprehensive matrix; repo has only ad-hoc checklist in SHIPPING.md |

**Overall Verdict:** ❌ **NOT READY** — 2 failures and 5 warnings require resolution before the first-5-venue scope can ship.

---

## Preliminary Finding: No Explicit "Seele's First-5-Venue" Checklist Found

**Search performed across:**
- All `.md` files (30 found)
- `UnrealIntegration/Source/FinalEvolutionLab/` (C++ headers and source)
- `Config/` directory
- `docs/` directory
- `infra/` documentation
- All comments and README files
- grep for: `seele`, `first.5.venue`, `venue.checklist`, `UE.validation`, `smoke.test`, `acceptance`

**Result:** No document titled or referencing "Seele's first-5-venue checklist" exists in the repository. The closest artifacts are:
1. `docs/UE57_External_Project_Checklist.md` — general UE 5.7 integration checklist (not venue-scoped)
2. `Config/FEL_IOS_CAPABILITIES_CHECKLIST.txt` — iOS capability checklist (platform, not venue)
3. `infra/SHIPPING.md` — shipping and smoke test notes (procedure, not venue acceptance)

**Implication:** The first-5-venue checklist must be **constructed** from the blueprint's venue registry and validated against the repository's actual state. This report serves as that constructed validation.

---

## Inferred First-5-Venue Scope

Based on the blueprint's venue registry (§3.3) and the 11 MapsToCook entries, the **first 5 venues** (by production priority and map availability) are:

| # | Venue | Map Token | Modes Hosted | Status |
|---|-------|-----------|-------------|--------|
| 1 | **Venice Beach Court** | VeniceBeach | basketball_h2h, basketball_dunk, basketball_3v3 | Production |
| 2 | **Zen Dojo** | Dojo | karate_h2h, karate_endless | Production |
| 3 | **Baseball Park** | BaseballPark | baseball | Production |
| 4 | **Gridiron Stadium** | Gridiron | football | Production |
| 5 | **Soccer Stadium** | SoccerStadium | soccer | Production |

These 5 venues cover **8 production modes** and all have maps in MapsToCook.

---

## Check 1: Mode ID Registry Match — ⚠️ WARNING

### Source Registry Comparison

| Registry Source | Modes Declared | File |
|----------------|---------------|------|
| Master Blueprint (§2) | 19 (14 prod + 5 staging) | `fel_master_architecture_blueprint_design.md` |
| `FEL_ModeManager.production.json` | 19 entries (but `total_modes: 17`) | `backend/FEL_ModeManager.production.json` |
| Swift `GameModeId` enum | 16 cases | `FinalEvolutionLab/Models/GameMode.swift` |
| `ue_mode_maps.json` | 16 mappings | `backend/ue_mode_maps.json` |
| `FEL_VenueRegistry.production.json` | 12 entries (11 real + 1 placeholder) | `UnrealStarter/.../FEL_VenueRegistry.production.json` |
| `EmergentPlayMap` INI section | 18 entries (includes `karate` alias) | `infra/ue5_config/DefaultGame.ini` |

### First-5-Venue Mode IDs — Line-by-Line

| mode_id | Blueprint | ModeManager JSON | Swift Enum | ue_mode_maps | VenueRegistry | EmergentPlayMap |
|---------|-----------|-----------------|------------|-------------|---------------|-----------------|
| `basketball_h2h` | ✅ | ✅ | ✅ `basketballHeadToHead` | ✅ | ✅ | ✅ |
| `basketball_dunk` | ✅ | ✅ | ✅ `basketballDunkContest` | ✅ | ✅ | ✅ |
| `basketball_3v3` | ✅ | ✅ | ✅ `basketball3v3` | ✅ | ✅ | ✅ |
| `karate_h2h` | ✅ | ✅ | ✅ `karate` (rawValue=`karate_h2h`) | ✅ | ⚠️ Listed as `karate` | ✅ |
| `karate_endless` | ✅ | ✅ | ✅ `karateEndless` | ✅ | ❌ Missing | ✅ |
| `baseball` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `football` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `soccer` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Discrepancies in First-5-Venue Scope

| Issue | Severity | Detail |
|-------|----------|--------|
| `karate_endless` missing from VenueRegistry | **Medium** | VenueRegistry lists only `karate` (maps to `karate_h2h`); `karate_endless` shares the Dojo venue but has no VenueRegistry entry |
| `karate` vs `karate_h2h` naming | **Low** | VenueRegistry uses `karate`, Swift uses `karate` with rawValue `karate_h2h`, EmergentPlayMap has both `karate_h2h` and `karate` alias — functional but inconsistent |
| ModeManager `total_modes: 17` vs 19 entries | **High** | Metadata header is stale — declares 17 but contains 19 mode entries |

### Global Mode ID Gaps (Beyond First-5-Venue)

| mode_id | Missing From |
|---------|-------------|
| `who_scene_it` | Swift enum, ue_mode_maps.json, VenueRegistry, EmergentPlayMap (not in INI) |
| `mario_party_fever` | Swift enum, ue_mode_maps.json, VenueRegistry, EmergentPlayMap (not in INI) |
| `market_browse` | Swift enum, VenueRegistry |

---

## Check 2: Venue to Cooked Path Mapping — ❌ FAIL

### MapsToCook Path Comparison

The blueprint (§10.1) documents paths as `/Game/FEL/Maps/{token}`, but the **actual** `DefaultGame.ini` uses `/Game/FEL/Venues/{token}/{token}`:

| Venue | Blueprint Path | Actual DefaultGame.ini Path | Match? |
|-------|---------------|---------------------------|--------|
| BaseballPark | `/Game/FEL/Maps/BaseballPark` | `/Game/FEL/Venues/BaseballPark/BaseballPark` | ❌ Different prefix |
| Dojo | `/Game/FEL/Maps/Dojo` | `/Game/FEL/Venues/Dojo/Dojo` | ❌ Different prefix |
| Gridiron | `/Game/FEL/Maps/Gridiron` | `/Game/FEL/Venues/Gridiron/Gridiron` | ❌ Different prefix |
| Links | `/Game/FEL/Maps/Links` | `/Game/FEL/Venues/Links/Links` | ❌ Different prefix |
| Luma_Venice_Shop | `/Game/FEL/Maps/Luma_Venice_Shop` | `/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop` | ❌ Different prefix |
| NeuroArena | `/Game/FEL/Maps/NeuroArena` | `/Game/FEL/Venues/NeuroArena/NeuroArena` | ❌ Different prefix |
| SandCourt | `/Game/FEL/Maps/SandCourt` | `/Game/FEL/Venues/SandCourt/SandCourt` | ❌ Different prefix |
| SoccerStadium | `/Game/FEL/Maps/SoccerStadium` | `/Game/FEL/Venues/SoccerStadium/SoccerStadium` | ❌ Different prefix |
| TennisCourt | `/Game/FEL/Maps/TennisCourt` | `/Game/FEL/Venues/TennisCourt/TennisCourt` | ❌ Different prefix |
| TrainingFloor | `/Game/FEL/Maps/TrainingFloor` | `/Game/FEL/Venues/TrainingFloor/TrainingFloor` | ❌ Different prefix |
| VeniceBeach | `/Game/FEL/Maps/VeniceBeach` | `/Game/FEL/Venues/VeniceBeach/VeniceBeach` | ❌ Different prefix |

**Critical Finding:** The blueprint documents the path prefix as `/Game/FEL/Maps/` but the actual INI file uses `/Game/FEL/Venues/{Name}/{Name}`. The `EmergentPlayMap` section in the same INI also uses the `/Venues/` prefix. **The blueprint must be corrected to match the actual paths.**

### First-5-Venue Map Coverage

| Venue | In MapsToCook? | EmergentPlayMap entries? | ue_mode_maps.json? |
|-------|---------------|------------------------|-------------------|
| Venice Beach Court | ✅ (`VeniceBeach`) | ✅ (3 basketball modes) | ✅ (`Venice_Beach_Court`) |
| Zen Dojo | ✅ (`Dojo`) | ✅ (karate_h2h, karate_endless, karate alias) | ✅ (`Zen_Dojo`) |
| Baseball Park | ✅ (`BaseballPark`) | ✅ | ✅ (`Baseball_Park`) |
| Gridiron Stadium | ✅ (`Gridiron`) | ✅ | ✅ (`Gridiron_Stadium`) |
| Soccer Stadium | ✅ (`SoccerStadium`) | ✅ | ✅ (`Soccer_Stadium`) |

**First-5-venue coverage: PASS** — All 5 venues have entries in MapsToCook, EmergentPlayMap, and ue_mode_maps.json.

### Map Token Naming Inconsistency

| Layer | Venice Beach | Zen Dojo | Baseball |
|-------|-------------|----------|----------|
| Blueprint Venue Registry | `Venice_Beach_Court` | `Zen_Dojo` | `Baseball_Park` |
| ue_mode_maps.json | `Venice_Beach_Court` | `Zen_Dojo` | `Baseball_Park` |
| MapsToCook | `VeniceBeach` | `Dojo` | `BaseballPark` |
| EmergentPlayMap | `VeniceBeach/VeniceBeach` | `Dojo/Dojo` | `BaseballPark/BaseballPark` |
| VenueRegistry JSON | `venice_beach_court` | `dojo_arena` | `stadium_diamond` |

**Multiple naming conventions in play across layers.** While the deep link subsystem resolves tokens, this fragmentation risks routing errors.

### Staging Maps NOT in MapsToCook (Confirmed)

| Map | Mode | In MapsToCook | EmergentPlayMap Fallback |
|-----|------|--------------|------------------------|
| Skate_Park | skateboarding | ❌ | ⚠️ Routes to `VeniceBeach` (fallback, not correct map) |
| Mountain_Slope | snowboarding | ❌ | ⚠️ Routes to `VeniceBeach` (fallback, not correct map) |
| Sovereign_Shop | market_browse | ❌ | ✅ Routes to `Luma_Venice_Shop` |
| Venice_Beach_Surf | surfing | ❌ (separate entry) | ⚠️ Routes to `VeniceBeach` (shared?) |

**Note:** `skateboarding` and `snowboarding` have EmergentPlayMap entries pointing to `VeniceBeach/VeniceBeach`, **NOT** their dedicated maps (`Skate_Park`, `Mountain_Slope`). This is a misrouting problem — the EmergentPlayMap should either not list them (staging) or point to the correct map.

---

## Check 3: Session Event Contracts — ⚠️ WARNING

### Backend Session Receipt (POST /api/games/session)

The backend `server.py` line 501-508 implements a **generic** session receipt handler:
```python
@api_router.post("/games/session")
async def create_game_session(data, user):
    s = {"id": ..., "user_id": ..., "mode_id": data.get("mode_id"),
         "score": data.get("score",0), "duration_seconds": data.get("duration_seconds",0), ...}
    await db.game_sessions.insert_one(s)
    xp = max(10, s["score"]//5)
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": xp}})
    await db.activity_feed.insert_one({...})
```

### First-5-Venue Session Contract Validation

| mode_id | Session Receipt | XP Award | Activity Feed | Shard Award | PRQ Delta |
|---------|----------------|----------|--------------|-------------|-----------|
| `basketball_h2h` | ✅ Generic handler | ✅ `max(10, score/5)` | ✅ | ❌ Not in backend | ❌ Not in backend |
| `basketball_dunk` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |
| `basketball_3v3` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |
| `karate_h2h` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |
| `karate_endless` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |
| `baseball` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |
| `football` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |
| `soccer` | ✅ Generic handler | ✅ | ✅ | ❌ Not in backend | ❌ Not in backend |

**Missing from backend:**
- **Shard economy transactions** — The blueprint (§7) defines win/draw/loss shard rewards but the backend `create_game_session` endpoint does NOT award shards
- **PRQ delta** — The blueprint (§5.3) defines `PRQ.modeReward()` but the backend does NOT compute or apply PRQ deltas
- **Score validation** — No server-side cap on XP (blueprint §13.3 flags this as P2 tech debt)

### Modes Without Standard Session Flow

| mode_id | Issue |
|---------|-------|
| `who_scene_it` | Has dedicated endpoints (`/games/who-scene-it`) but **no session receipt integration** — quiz results don't post to `/games/session` |
| `mario_party_fever` | Has dedicated endpoints (`/games/mario-party`) with custom `party_sessions` collection — **no standard session receipt** |

---

## Check 4: Production / Staging Status — ❌ FAIL

### Blueprint vs Repository Status Comparison

| mode_id | Blueprint Status | ModeManager JSON Status | Swift Enum Present? | Effective Status |
|---------|-----------------|------------------------|--------------------|--------------------|
| `basketball_h2h` | Production (#1) | `production` | ✅ | ✅ Production |
| `basketball_dunk` | Production (#2) | `production` | ✅ | ✅ Production |
| `basketball_3v3` | Production (#3) | `production` | ✅ | ✅ Production |
| `karate_h2h` | Production (#4) | `production` | ✅ | ✅ Production |
| `karate_endless` | Production (#5) | `production` | ✅ | ✅ Production |
| `baseball` | Production (#6) | `production` | ✅ | ✅ Production |
| `football` | Production (#7) | `production` | ✅ | ✅ Production |
| `soccer` | Production (#8) | `production` | ✅ | ✅ Production |
| `golf` | Production (#9) | `production` | ✅ | ✅ Production |
| `tennis` | Production (#10) | `production` | ✅ | ✅ Production |
| `volleyball` | Production (#11) | `production` | ✅ | ✅ Production |
| `surfing` | Production (#12) | `production` | ✅ | ✅ Production |
| `who_scene_it` | Production (#13) | `production` | ❌ Missing | ⚠️ **Broken** — prod in JSON but no Swift enum |
| `mario_party_fever` | Production (#14) | `production` | ❌ Missing | ⚠️ **Broken** — prod in JSON but no Swift enum |
| `skateboarding` | Staging (#15) | `staging` | ✅ | ✅ Staging |
| `snowboarding` | Staging (#16) | `staging` | ✅ | ✅ Staging |
| `gymnastics` | Staging (#17) | `staging` | ✅ | ✅ Staging |
| `brain_brawl` | Staging (#18) | `staging` | ✅ | ✅ Staging |
| `market_browse` | Staging (#19) | `staging` | ❌ Missing | ⚠️ **Broken** — staging but not in Swift |

### Status Count Discrepancy

| Source | Production Count | Staging Count | Total |
|--------|-----------------|---------------|-------|
| Blueprint header | 14 | 5 | 19 |
| Blueprint §2 notes | "12 production, 5 staging, 2 late additions" | — | 19 |
| ModeManager JSON | 14 (`status: production`) | 5 (`status: staging`) | 19 |
| ModeManager metadata | `production_modes: 12` | — | `total_modes: 17` |

**Blueprint internal inconsistency:** The Goals section says "12 production, 5 staging, 2 late additions" but §2.1 lists 14 production modes. The "2 late additions" (`who_scene_it`, `mario_party_fever`) are counted as production in the table but called out as additions.

---

## Check 5: Preview Mode Classification — ⚠️ WARNING

### Staging Gate Mechanism

| Gate Mechanism | Exists? | Location |
|----------------|---------|----------|
| ModeManager JSON `status` field | ✅ | `backend/FEL_ModeManager.production.json` |
| MapsToCook exclusion | ✅ | Staging maps not in DefaultGame.ini `+MapsToCook` |
| Swift enum exclusion | Partial | `who_scene_it`, `mario_party_fever`, `market_browse` not in enum |
| Backend feature flag | ❌ | No server-side staging gate in `server.py` |
| EmergentPlayMap INI exclusion | ❌ | `skateboarding` and `snowboarding` ARE listed in EmergentPlayMap (with wrong fallback maps) |
| ue_mode_maps.json exclusion | Partial | `who_scene_it`, `mario_party_fever`, `market_browse` missing |
| CI enforcement | Not verified | Blueprint mentions CI mode count threshold but no script found |

### Risk: Staging Modes Accidentally Accessible

- `skateboarding` and `snowboarding` are in EmergentPlayMap pointing to `VeniceBeach` — a deep link `finalevolution://launch?mode=skateboarding` would **launch the wrong map** (VeniceBeach instead of Skate_Park)
- `market_browse` is in EmergentPlayMap pointing to `Luma_Venice_Shop` which IS in MapsToCook — could accidentally launch
- **No runtime staging check** in the deep link subsystem or backend launch endpoint

---

## Check 6: Known Gaps Verification — ✅ PASS

### Gap Status

| Gap | Blueprint Status | Repository Status | Confirmed? |
|-----|-----------------|-------------------|------------|
| `who_scene_it` | Production (blueprint §2.1 #13) — but flagged incomplete in PRQ weights | ❌ Missing from Swift enum, ue_mode_maps, VenueRegistry | ✅ Gap confirmed — marked prod in JSON but infrastructure incomplete |
| `court_carnival` | Referenced in task context as known gap | ❌ **Not found anywhere in repository** — not in any registry, config, or code | ✅ Gap confirmed — does not exist yet |
| `market_browse` | Staging (blueprint §2.2 #19) | ❌ Missing from Swift enum; present in ModeManager JSON as staging | ✅ Gap confirmed — staging, infrastructure incomplete |

### Additional Gaps Found

| mode_id | Issue |
|---------|-------|
| `mario_party_fever` | Same incompleteness pattern as `who_scene_it` — prod in ModeManager but missing from Swift/ue_mode_maps/VenueRegistry |
| `gymnastics` | In Swift enum and ue_mode_maps but map NOT in MapsToCook — staging mode with partial infra |

---

## Check 7: iOS Cooked Payload Completeness — ⚠️ WARNING

### MapsToCook — 11 Maps in DefaultGame.ini (Actual)

```
1. /Game/FEL/Venues/BaseballPark/BaseballPark
2. /Game/FEL/Venues/Dojo/Dojo
3. /Game/FEL/Venues/Gridiron/Gridiron
4. /Game/FEL/Venues/Links/Links
5. /Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop
6. /Game/FEL/Venues/NeuroArena/NeuroArena
7. /Game/FEL/Venues/SandCourt/SandCourt
8. /Game/FEL/Venues/SoccerStadium/SoccerStadium
9. /Game/FEL/Venues/TennisCourt/TennisCourt
10. /Game/FEL/Venues/TrainingFloor/TrainingFloor
11. /Game/FEL/Venues/VeniceBeach/VeniceBeach
```

### Blueprint vs Actual Path Format

| Blueprint (§10.1) | Actual INI | Discrepancy |
|-------------------|-----------|-------------|
| `/Game/FEL/Maps/BaseballPark` | `/Game/FEL/Venues/BaseballPark/BaseballPark` | Prefix `/Maps/` → `/Venues/{Name}/` |

**All 11 maps have this discrepancy.** The blueprint must be updated.

### Production Mode → Map Coverage

| Production Mode | Required Map | In MapsToCook? |
|----------------|-------------|---------------|
| basketball_h2h/dunk/3v3 | VeniceBeach | ✅ |
| karate_h2h/endless | Dojo | ✅ |
| baseball | BaseballPark | ✅ |
| football | Gridiron | ✅ |
| soccer | SoccerStadium | ✅ |
| golf | Links | ✅ |
| tennis | TennisCourt | ✅ |
| volleyball | SandCourt | ✅ |
| surfing | VeniceBeach (shared) | ✅ (via VeniceBeach) |
| who_scene_it | NeuroArena | ✅ |
| mario_party_fever | VeniceBeach | ✅ |

**Note:** Surfing's dedicated map (`Venice_Beach_Surf` in blueprint) is NOT in MapsToCook as a separate entry. The EmergentPlayMap routes surfing to `VeniceBeach/VeniceBeach`. This may be intentional (shared venue) or a gap.

### Descriptor Safety Chain

| Check | Status |
|-------|--------|
| `fel_ue5_ios_shipping_package.sh` exists | ✅ (referenced in infra/SHIPPING.md) |
| `infra/fix_ios_descriptor_path.sh` diagnostic | Referenced in blueprint but not verified in repo |
| `cookeddata/` or `.pak` verification step | ✅ Documented in SHIPPING.md |
| Non-iCloud project path warning | ✅ Documented |

---

## Check 8: Smoke Test Criteria — ⚠️ WARNING

### Blueprint Acceptance Matrix (§12.1) — 10 Universal Tests per Mode

The blueprint defines a comprehensive 10-point acceptance test per production mode. **No equivalent checklist exists in the repository.**

### Repository Smoke Test Coverage

| Source | Tests Defined | Scope |
|--------|--------------|-------|
| Blueprint §12.1 | 10 universal + mode-specific | All 14 production modes |
| Blueprint §12.3 | 8-step staging promotion gate | All 5 staging modes |
| `infra/SHIPPING.md` | 8-step release day checklist | Generic (not per-mode) |
| `docs/UE57_External_Project_Checklist.md` | 2-step verification | WebSocket + iOS bridge only |
| `backend/tests/` | Python unit tests | Backend API only |

### First-5-Venue Smoke Test Requirements (Derived from Blueprint)

For each of the 8 modes across the first 5 venues:

| Test | basketball_h2h | basketball_dunk | basketball_3v3 | karate_h2h | karate_endless | baseball | football | soccer |
|------|---------------|-----------------|----------------|------------|----------------|----------|----------|--------|
| Deep link launch | Required | Required | Required | Required | Required | Required | Required | Required |
| MapLoaded event (10s) | Required | Required | Required | Required | Required | Required | Required | Required |
| Session receipt POST | Required | Required | Required | Required | Required | Required | Required | Required |
| XP award | Required | Required | Required | Required | Required | Required | Required | Required |
| Shard reward | ❌ Not implemented | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| PRQ delta | ❌ Not implemented | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Activity feed | Required | Required | Required | Required | Required | Required | Required | Required |
| Browser fallback | Required | Required | Required | Required | Required | Required | Required | Required |
| E3DS travel | Required | Required | Required | Required | Required | Required | Required | Required |
| Multiplayer sync | Required (realtime) | Required | Required | Required | Required | N/A (turnBased) | N/A | Required |

---

## Action Items

### P0 — Must Fix Before Ship

| # | Action | Owner | Files Affected |
|---|--------|-------|---------------|
| 1 | **Fix ModeManager metadata** — Update `total_modes: 17` → `19` and `production_modes: 12` → `14` | Backend | `backend/FEL_ModeManager.production.json` |
| 2 | **Add missing Swift enum cases** — Add `whoSceneIt`, `marioPartyFever`, `marketBrowse` to `GameModeId` | iOS | `FinalEvolutionLab/Models/GameMode.swift` |
| 3 | **Add missing ue_mode_maps entries** — Add `who_scene_it`, `mario_party_fever`, `market_browse` | Backend | `backend/ue_mode_maps.json` |
| 4 | **Fix EmergentPlayMap staging fallbacks** — Remove or correct `skateboarding` and `snowboarding` entries that falsely route to VeniceBeach | Infra | `infra/ue5_config/DefaultGame.ini` |
| 5 | **Update blueprint MapsToCook paths** — Change `/Game/FEL/Maps/` to `/Game/FEL/Venues/{Name}/` to match actual INI | Docs | Blueprint design doc |

### P1 — Required for Quality

| # | Action | Owner | Files Affected |
|---|--------|-------|---------------|
| 6 | **Add `karate_endless` to VenueRegistry** | Config | `FEL_VenueRegistry.production.json` |
| 7 | **Implement backend shard rewards** in `create_game_session` | Backend | `backend/server.py` |
| 8 | **Implement backend PRQ delta** in `create_game_session` | Backend | `backend/server.py` |
| 9 | **Add staging gate runtime check** — Prevent deep link launch of staging modes | UE/Backend | Deep link subsystem or backend launch endpoint |
| 10 | **Create per-venue smoke test script** — Automated acceptance tests for first-5-venue scope | QA | New: `scripts/smoke_test_first5.sh` or equivalent |
| 11 | **Integrate `who_scene_it` and `mario_party_fever` session receipts** with standard `/games/session` endpoint | Backend | `backend/server.py` |

### P2 — Tech Debt

| # | Action | Owner |
|---|--------|-------|
| 12 | Standardize venue naming convention across all registries |  All |
| 13 | Clarify surfing map (dedicated Venice_Beach_Surf vs shared VeniceBeach) | UE |
| 14 | Add XP cap per session (blueprint §13.3) | Backend |
| 15 | Resolve blueprint internal inconsistency: "12 production" in Goals vs 14 in registry | Docs |
| 16 | Add `court_carnival` placeholder to mode registry if planned | Product |

---

## Confirmed Gaps That Should Remain Flagged

| Gap | Reason | Expected Resolution |
|-----|--------|-------------------|
| `who_scene_it` | Production-classified but infrastructure incomplete (no Swift enum, no ue_mode_maps entry, no VenueRegistry entry, no standard session receipt) | Complete infrastructure before enabling in iOS app |
| `court_carnival` | Not present in any repository artifact — appears to be a planned future mode | Add to registry when development begins |
| `market_browse` | Staging-classified, no Swift enum, 3D shop browsing mode with no scoring — fundamentally different from game modes | Complete when commerce feature ships |

---

## Recommendations

1. **Create the "Seele's First-5-Venue" checklist** as an explicit document in `docs/` — this validation report can serve as the template
2. **Run a single registry alignment pass** across all 5 sources (ModeManager JSON, Swift enum, ue_mode_maps.json, VenueRegistry, EmergentPlayMap INI) before any build attempt
3. **Add CI enforcement** — The blueprint references `fel_prebuild_ci_check.sh --strict` with 6-point alignment; extend it to validate mode count consistency across registries
4. **Implement staging runtime gates** — The current architecture relies on Swift enum exclusion as an implicit gate, which is fragile; add explicit `status` checks in the deep link subsystem
5. **Prioritize shard and PRQ integration** in the backend session handler — these are specified in the blueprint but not implemented, making the economy contract untestable

---

*Report generated: 2026-05-22*
*Validated against: `anti-gravity-fel` branch, commit 9519541*
