# Gameplay & Visual Polish Plan

Roadmap for closing the gap between current build and a high-quality finished product. Aligns with **PROJECT_FLOWS.md**, **GAMEPLAY_STATUS.md**, and **GAMEPLAY_PRODUCTION.md**.

---

## What’s Left (from GAMEPLAY_STATUS)

| Area | Status | Priority |
|------|--------|----------|
| Arena Dunk = generic tap | **Done:** Solo Dunk → interstitial “Open Lab” → Lab 3D court | — |
| Sport-specific input | Baseball/Golf/Soccer etc. all tap-to-commit | Lower – differentiator for later |
| 3v3 / contest depth | No defense/possession; rounds independent | Lower |
| Tutorial / onboarding | **Done:** Arena + Brain Brawl first-time overlays | — |
| Round/result clarity | “Waiting for OPP…” and result “who won why” | **High** |
| Accessibility | VoiceOver on commit, waiting, buttons | **High** |
| Feel & DDA | **Done:** Per-mode haptic; optional PRQ/opponent tuning | — |
| Offline / errors | **Done:** Disconnect alert + Exit game + Keep playing solo | — |
| Sound | **Done:** System sounds for commit + victory/defeat | — |

---

## Implemented in This Pass

1. **First-time Arena tutorial** – Overlay on first Arena play: “Press ✕ or tap to commit. Outcome from PRQ.” Dismissible; preference stored so it doesn’t show again.
2. **Commit feedback polish** – Stronger visual on PERFECT/GOOD/MISS (scale-in, brief glow).
3. **Accessibility** – VoiceOver labels/hints for commit button, commit feedback text, and “Waiting for opponent…”.
4. **Result screen round breakdown** – Optional “Round 1: P1 1 – P2 0” style list when round-by-round data is provided (Arena generic play).
5. **GameplaySoundService** – Central stub for commit (perfect/good/miss), round end, victory. No-op by default; ready for AVFoundation or system sounds.

---

## Pass 2 (Implemented)

6. **Brain Brawl first-time overlay** – `FirstTimeBrainBrawlOverlay`: “Answer first to win the question. Five questions — highest score wins.” Dismissible; key `fel_brain_brawl_tutorial_seen`.
7. **Multipeer disconnect handling** – In `GenericArenaPlayView`, when local play and peer disconnects (`multipeer?.isConnected` → false), show alert “Connection lost. Your opponent disconnected.” with “Exit game” to call `onExit()`.

---

## Pass 3 (Implemented)

8. **System sounds** – `GameplaySoundService` now plays `AudioServicesPlaySystemSound` for commit (perfect/good/miss) and victory/defeat so there is audible feedback without custom assets.
9. **Per-mode haptic** – Arena commit “perfect” uses `.heavy` for Dunk/Karate/Gymnastics, `.light` for Golf/Tennis/Volleyball, `.medium` for the rest.
10. **Keep playing solo** – On “Connection lost”, added “Keep playing solo” so the rest of the game continues vs CPU; “Exit game” unchanged.

---

## Pass 4 (Implemented)

11. **Arena Dunk → Lab** – When user picks Dunk Contest in Arena (solo), after Get Ready they see an interstitial: “The 3D dunk court lives in Lab. Open Lab to sprint, launch, and stick the landing.” Buttons: **OPEN LAB** (switches to Lab tab and opens the dunk full-screen flow) and **Back to Arena**. Uses `LabViewModel.openDunkOnNextLabAppearance`; LabView opens dunk on appear or when flag is set.

---

## Suggested Next (Not Implemented Here)

- **Custom SFX**: Replace system sounds with custom assets and call from `GameplaySoundService` if desired.
- **Offline/retry**: Retry reconnection in addition to “Keep playing solo” / “Exit game.”

---

## Mode vs. Inspirations (analyze → plan → build → assess)

See **MODE_INSPIRATIONS_AND_PLAN.md** for per-mode comparison to 2K, NBA/NFL/FIFA Street, Big Brain Academy, Storm × Matrix, Wii Sports/Resort, NBA Live 07. **Built this cycle:** inspiration tags per mode (`GameModeId.inspirationTag`) on Get Ready and Arena mode rows.

---

## File Reference

| Change | File(s) |
|--------|--------|
| Tutorial overlay | `ArenaView.swift` (GenericArenaPlayView), `FirstTimeArenaTutorialOverlay.swift` (new) |
| Commit animation + a11y | `ArenaView.swift` (GenericArenaPlayView) |
| Round breakdown | `GameScreensView.swift` (ResultScreen), `ArenaView.swift` (onGameEnd signature + roundScores) |
| Sound service | `Services/GameplaySoundService.swift` (new), `ArenaView.swift`, optional `LabView` / `GameScreensView` |
| Brain Brawl tutorial | `FirstTimeBrainBrawlOverlay.swift` (new), `BrainBrawlPlayView.swift` |
| Multipeer disconnect | `ArenaView.swift` (GenericArenaPlayView: alert on `isConnected` false + Keep playing solo) |
| System sounds | `GameplaySoundService.swift` (AudioToolbox), `GameScreensView` (victory/defeat) |
| Per-mode haptic | `ArenaView.swift` (commitHapticStyleForPerfect by GameModeId) |
| Arena Dunk → Lab | `LabViewModel.openDunkOnNextLabAppearance`, `ArenaView` (ArenaDunkInterstitialView, onOpenLab), `LabView` (onChange/onAppear) |
| Inspiration tags | `GameMode.swift` (GameModeId.inspirationTag), `GameScreensView` (GetReadyScreen), `ArenaView` (mode row, Get Ready), `LabView` (dunk Get Ready); MODE_INSPIRATIONS_AND_PLAN.md |
