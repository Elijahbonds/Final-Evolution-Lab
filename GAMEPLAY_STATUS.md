# Gameplay: What’s Built, What’s Left, What to Improve

## Current architecture

- **Arena** = venue list → pick mode → **Get Ready** → **Play** → **Result**. Two play paths:
  - **Brain Brawl**: full quiz (BrainBrawlPlayView), 5 questions vs AI, first correct wins the question.
  - **All other modes** (Head to Head, Dunk Contest, 3v3, Karate, Baseball, Soccer, etc.): **GenericArenaPlayView** — **tap to commit, no timing bar**; outcome from PRQ (quality 0.62–0.90). Creator vision: PROJECT_FLOWS.
- **Lab** = freestyle **Dunk Contest** with **RealityKit** 3D court (sprint → gather → fly → tricks, DunkContestEngine + RealityKitDunkView). No other Lab “games” yet.
- **Local Play**: Multipeer lobby (Host/Join); same GenericArenaPlayView with P1/P2 turn sync.

---

## What’s built

| Area | Status |
|------|--------|
| Arena flow | Get Ready → Play → Result; exit; shards + PRQ on result |
| Generic play | Tap/Cross to commit (no timing bar); quality 0.62–0.90 from PRQ only → score, round alerts, perfect/good/miss feedback |
| Brain Brawl | 5 questions, curriculum-based, AI opponent, first correct wins question, shards on win |
| Dunk (Lab only) | RealityKit court, DunkContestState (sprint, launch, tricks, landing), judge scores, freestyle |
| Controller | Physical controller (Cross/A) to commit; PS2 overlay when no controller |
| Local play | Lobby, host/join, multipeer send round score, waiting state |
| DDA / PRQ | PRQ-driven difficulty and scoring weight per mode (GameMode, PRQScoring, DynamicDifficulty) |
| Result screen | Winner, P1/P2 score, round-by-round breakdown (Arena), shards, PRQ gain, attribute label |
| Per-mode presentation | Commit-phase hint per mode; contest phase (1v1/3v3); block phase (Karate); pitch phase (Baseball); mode-specific round alerts (GameMode) |

---

## What’s left to build (gameplay)

1. **Arena Dunk Contest (dedicated)**  
   Right now “Dunk Contest” in Arena uses the same generic timing round as Head to Head. To match the pitch (“Sprint → Gather → Fly, face buttons for finishers”):
   - Either **route** Arena Dunk to a multi-phase flow (sprint charge → gather timing → fly → land timing) reusing DunkContestEngine logic but in a simplified UI,  
   - Or **embed** RealityKitDunkView in Arena for Dunk Contest so Arena has the real dunk game, not just “DUNK!” timing.

2. **Sport-specific input/gameplay**  
   Baseball, Golf, Soccer, etc. all use the same charge + release. To differentiate:
   - **Baseball**: swipe or power + timing (swipe angle/speed).  
   - **Golf**: swipe (direction + power), e.g. swipeGolf.  
   - **Soccer**: penalty kick (aim + power).  
   - **Tennis/Volleyball**: rally timing or tap sequence.  
   Input schemes exist in `GameModeId.inputScheme`; the UI still uses the single tap-to-commit for all.

3. **3v3 / Head to Head “contest”**  
   Contest phase done: after commit, P2 or CPU can contest; contested shots get 0.82× quality. Full 3v3 scene/possession still future.

4. **Tutorial / onboarding for play**  
   No in-game tutorial for “press ✕ to commit” (Arena) or Brain Brawl rules. A short first-time overlay or tips would help.

5. **More Brain Brawl content**  
   Question bank is curriculum-based; can add more questions per track and difficulty.

6. **RealityKit in Arena**  
   Option to use the same RealityKit dunk court when playing Dunk Contest from Arena (so one shared “real” dunk experience in both Lab and Arena).

---

## What to improve (gameplay)

- **Feel**: Tune PRQ→quality mapping and feedback (haptics, animation) per mode so each sport feels slightly different.
- **Clarity**: Round label and “Waiting for OPP…” state clearer in local play; ensure result screen clearly shows who won and why (e.g. “Round 3: you 92, OPP 78”).
- **Accessibility**: Ensure commit button and feedback have VoiceOver labels and that Brain Brawl choices are fully accessible.
- **DDA**: Use PRQ and session performance to adjust outcome quality or opponent “skill” so matches stay close and satisfying.
- **Offline / errors**: If multipeer or network fails, show a clear message and allow continuing solo (e.g. vs CPU) or retry.

---

## Unreal (Arena lab) QA

Physics basketball prototype and mode rules are audited separately from this Swift app: **`UnrealStarter/BasketballGame/QA_GAMEPLAY_AUDIT.md`** (session export, hoop scoring, Swift `gameModeId` parity notes).

---

## Summary

- **Built**: Arena shell (Get Ready → Play → Result), generic **tap-to-commit** play for all non–Brain Brawl modes (outcome from PRQ, no timing bar), Brain Brawl quiz, Lab RealityKit dunk, controller + overlay, local play sync, PRQ/DDA, result screen.  
- **Left to build**: Arena-specific Dunk flow (or RealityKit in Arena), sport-specific inputs (swipe, penalty, rally), 3v3/contest depth, tutorial, more Brain Brawl questions.  
- **Improve**: Per-mode feel, clarity of round/result and “waiting” state, accessibility, DDA tuning, offline/error handling.
