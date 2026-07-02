# Unreal Engine Game Mode Smoke Testing Checklist

Use this checklist to perform manual verification of cooked iOS packages or local Unreal Engine targets. Test each game mode via deep-link launching.

## Smoke Testing Procedure

Launch each mode using the Safari address bar, an terminal command, or a deep-link dispatcher:

```bash
# macOS Terminal Command (if target is running on device or simulator)
xcrun simctl openurl booted "finalevolution://launch?mode=<mode_id>"
```

For each mode, verify the following acceptance gates:
- [ ] **Map Load**: Map opens in-process. No black screen or descriptor errors.
- [ ] **Mode Activation**: Correct game mode rules, displays, and limits activate.
- [ ] **Clean Exit**: Sessions can be exited without crashing the application.
- [ ] **Receipt Path**: One valid session receipt is emitted on completion.
- [ ] **Anti-Cheat Validation**: No rewards (shards, cards, PRQ) are granted from unverified local state.

---

## 1. Production Modes

### Venice Beach Court
- [ ] **Basketball Head-to-Head (`basketball_h2h`)**
  - Launch: `finalevolution://launch?mode=basketball_h2h`
  - Verify: targetScore = 3, timeLimit = 0.
- [ ] **Basketball Dunk Contest (`basketball_dunk`)**
  - Launch: `finalevolution://launch?mode=basketball_dunk`
  - Verify: targetScore = 21, timeLimit = 0, featured mode assets active.
- [ ] **Basketball 3v3 (`basketball_3v3`)**
  - Launch: `finalevolution://launch?mode=basketball_3v3`
  - Verify: targetScore = 11, timeLimit = 0, 3v3 layout renders.
- [ ] **Court Carnival (`court_carnival`)**
  - Launch: `finalevolution://launch?mode=court_carnival`
  - Verify: Board preview layout, VeniceBeach background, timeLimit = 600.

### Zen Dojo
- [ ] **KarateSparring (`karate_h2h`)**
  - Launch: `finalevolution://launch?mode=karate_h2h`
  - Verify: targetScore = 5, timeLimit = 150.
- [ ] **Karate Endless (`karate_endless`)**
  - Launch: `finalevolution://launch?mode=karate_endless`
  - Verify: Endless wave scaling, targetScore = 999.
- [ ] **Karate Legacy Alias (`karate`)**
  - Launch: `finalevolution://launch?mode=karate`
  - Verify: Routes seamlessly to Karate Sparring / Dojo.

### Neuro Arena
- [ ] **Who Scene It (`who_scene_it`)**
  - Launch: `finalevolution://launch?mode=who_scene_it`
  - Verify: Question card layout with biomechanical skeleton canvas overlays.

### Field & Court Venues
- [ ] **Baseball (`baseball`)**
  - Launch: `finalevolution://launch?mode=baseball`
  - Verify: Baseball Park maps, batting/pitching overlays.
- [ ] **Football (`football`)**
  - Launch: `finalevolution://launch?mode=football`
  - Verify: Gridiron Stadium kick-return flow.
- [ ] **Soccer (`soccer`)**
  - Launch: `finalevolution://launch?mode=soccer`
  - Verify: Soccer Stadium penalty/goal rules.
- [ ] **Golf (`golf`)**
  - Launch: `finalevolution://launch?mode=golf`
  - Verify: Links Course precision shot.
- [ ] **Tennis (`tennis`)**
  - Launch: `finalevolution://launch?mode=tennis`
  - Verify: Tennis Court rally UI.
- [ ] **Volleyball (`volleyball`)**
  - Launch: `finalevolution://launch?mode=volleyball`
  - Verify: Sand Court volleyball flow.
- [ ] **Surfing (`surfing`)**
  - Launch: `finalevolution://launch?mode=surfing`
  - Verify: Venice Beach Surf map, board line tracking.

---

## 2. Staging / Preview Modes (Do not promote to production without device smoke)

- [ ] **Skateboarding (`skateboarding`)**
  - Launch: `finalevolution://launch?mode=skateboarding`
  - Verify: Venice Beach/Skate Park maps, trick mechanics.
- [ ] **Snowboarding (`snowboarding`)**
  - Launch: `finalevolution://launch?mode=snowboarding`
  - Verify: Training Floor / Mountain Slope venues, line mechanics.
- [ ] **Gymnastics (`gymnastics`)**
  - Launch: `finalevolution://launch?mode=gymnastics`
  - Verify: Training Floor routine judging/scoring.
- [ ] **Brain Brawl (`brain_brawl`)**
  - Launch: `finalevolution://launch?mode=brain_brawl`
  - Verify: Neuro Arena, non-scoring, brain brawl quiz mechanics.
- [ ] **Module Library (`market_browse`)**
  - Launch: `finalevolution://launch?mode=market_browse`
  - Verify: Luma Venice Shop maps, non-scoring module browser UI, App Store-safe branding.
