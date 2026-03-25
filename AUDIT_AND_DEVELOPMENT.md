# Audit & Front-to-Back Development Summary

## Audit Highlights

- **Entry:** Onboarding (sport, age, goal) → profile saved via SaveSystem.
- **Tabs:** Lab, Train, Status, Profile. Arena/game-selection removed; only freestyle dunk remains as gameplay.
- **Lab:** Scan, biomechanics, court (RealityKit dunk), neural drive, metrics, Quick Start, recent activity. Full-screen dunk covers tab bar during play.
- **Train:** 3-track + equipment, recovery gate, workout days; completion saved on "Finish Workout."
- **Gameplay:** Freestyle dunk only; was not persisting results or granting shards.
- **Persistence:** Profile, sessions, game results, training progress, coach/critique all in UserDefaults via SaveSystem.

## Additions & Revisions Implemented

### 1. Persist freestyle dunk and grant shards
- After each scored round, a `GameSessionResult` is created (gameModeId: `"freestyle_dunk"`, score, shards 8 + score/8, capped 5–35).
- `SaveSystem.saveGameResult` and profile shards update; `viewModel.gameResults` is appended for immediate UI.
- Full-screen overlay shows **"+N SHARDS"** with the judge scores before auto-dismiss.

### 2. Lab Quick Start → Train
- Tapping a track in Lab’s Quick Start sets `viewModel.preselectedTrack` (TrainingTrack) and `selectedTab = .training`.
- ContentView passes `Binding<AppTab> selectedTab` into LabView so Lab can switch tabs.
- TrainingHubView applies `preselectedTrack` in `onAppear` and `onChange`, calls `vm.switchTrack(to:)`, then clears it.

### 3. Settings on Train tab
- Train tab toolbar now includes the same settings button as Lab and Profile for consistent access.

### 4. RealityKit dunker from profile
- `RealityKitDunkView` takes `avatarConfig: AvatarSkinConfig` (default `.default`).
- Dunker tint uses `avatarConfig.auraColorR/G/B`; height/scale uses `avatarConfig.heightScale`.
- Lab court and full-screen dunk both pass `viewModel.profile.effectiveAvatarConfig`.

### 5. Round result (score + shards) before dismiss
- `freestyleShardsEarned` state set in `executeFreestyleScoring`; passed into `DunkFullScreenView`.
- **Updated:** After scoring, full-screen `ResultScreen` is shown (scores, shards, PRQ); user taps "Claim rewards & exit" to dismiss. No auto-dismiss.

## Files Touched

- `ContentView.swift` — selectedTab binding for Lab; settings on Train.
- `LabView.swift` — selectedTab binding; Quick Start sets preselectedTrack + selectedTab; dunk persistence + shards; freestyleShardsEarned; DunkFullScreenView shards binding + avatarConfig.
- `LabViewModel.swift` — preselectedTrack.
- `TrainingHubView.swift` — apply preselectedTrack on appear/change.
- `RealityKitDunkView.swift` — avatarConfig, makeDunker(tint:heightScale:).
- `SaveSystem` / `GameSession` — already supported save; now used by dunk flow.

## Optional Next Steps (from audit)

- **SocialView** is now reachable from Profile → COMMUNITY button (sheet).
- Done: `ResultScreen` (is used after each scored dunk (Claim rewards & exit). Was: consider “game over” screen after dunk.
- Unify curriculum (LabViewModel tracks) vs TrainingProgramData if both are still needed for different flows.

## Second audit pass (done)

- **Toolbar:** Status and Profile tabs now have settings + shards like Lab/Train.
- **Onboarding:** Back button on steps 1 and 2.
- **Dashboard:** Empty state card when no sessions and no game results.
- **SocialView:** Profile has COMMUNITY button → SocialView sheet (rankings/Arena).
- **Docs:** AUDIT_BIOMECHANICAL_ECOSYSTEM, GAMEPLAY_IMPROVEMENTS_PLAN, app-synopsis updated to RealityKit/DunkFullScreenView; removed deleted view refs.

## Third audit pass (done)

- **Accessibility:** Added `accessibilityLabel` and `accessibilityHint` to key UI: ContentView (Settings button, Evolution shards badge), Lab (Start approach button, full-screen dunk Close button), Profile (Community button), WorkoutDayView (Finish workout button), OnboardingView (Back, Continue / Start Evolution). Improves VoiceOver and accessibility without changing behavior.
- **Docs:** This section added.

## Game mode fixes (graphics, screens, mechanics, solo/offline)

- **Screens:** Tapping "Start approach" now shows **GetReadyScreen** (3-2-1-GO, "Dunk Contest · Sprint → Launch → Finisher") in full screen; on "GO" the full-screen **DunkFullScreenView** appears. After a scored dunk, **ResultScreen** is shown (title "SOLO DUNK", judge total, shards, PRQ) with "Claim rewards & exit"; no more 3.5s auto-dismiss.
- **RealityKit visuals:** Court floor uses warmer wood tone and a center line; backboard has a white rectangle (paint); rim is orange-red with a simple net (segment ring); dunker has arm segments for silhouette; key + fill lighting; rim flash is a ring at the hoop lasting ~350 ms.
- **Mechanics:** Gameplay unchanged (sprint → gather → launch → airborne finishers → landing); persistence and shards unchanged; flow is Get Ready → Play → ResultScreen → Claim & exit.
- **Solo/offline:** Only freestyle dunk is playable; all play is offline/solo. ResultScreen title "SOLO DUNK"; court label "Venice Beach Court · Solo". `GameSessionResult` already uses `isMultiplayer: false`.

## Production readiness (gameplay, flow, mechanics, controls)

- **Game flow:** Get Ready (3-2-1-GO) → full-screen play → ResultScreen → Back to Lab. Timer cancelled on both Close and Claim so no lingering tasks.
- **Face buttons:** Launch phase = tap to jump (one action). Airborne = face buttons map to finishers only (processArcadeInput); landing phase = tap to stick the landing and score. Prevents accidental instant-score on first tap in air.
- **Double-scoring guard:** executeFreestyleScoring returns immediately if freestyleJudgeScores != nil.
- **Controls:** Left stick hold (y > 0.28) = sprint, release (y < 0.18) = launch with hysteresis. Haptic: launch (medium/light by green zone), landing (heavy), score (success/warning by total).
- **Assets:** Court, dunker, hoop, and VFX are procedural RealityKit meshes (no external assets required). Optional: add sound effects for rim, crowd, and UI via AVFoundation or system sounds; replace procedural dunker with a skinned model + animations when moving to Unreal.

## Audit pass (fixes applied)

- **Settings sync:** ContentView now uses `@AppStorage("simpleMode")` so the Simple Mode toggle in Settings updates the app immediately on dismiss; redundant `onChange` in SettingsSheet removed.
- **Persistence:** SaveSystem caps stored game results at 100 (trim on save and on load) to avoid unbounded UserDefaults growth.
- **Accessibility:** Sheet close buttons for Community (VaultView) and Share to Feed (DashboardView) now have `accessibilityLabel("Close")` and a hint.

## Audit pass 2 (fixes applied)

- **Accessibility:** PRQ overlay PRQ badge now has a combined label ("PRQ [score], [tier] tier"). Settings Done and Recovery Lab Done buttons have `accessibilityHint`. Dashboard empty-state card has a combined accessibility label so VoiceOver reads it as one announcement. Edit Profile Save button has an accessibility hint.
