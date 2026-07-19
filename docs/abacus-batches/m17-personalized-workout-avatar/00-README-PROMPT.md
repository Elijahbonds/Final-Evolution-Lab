# M17 — PERSONALIZED WORKOUT + MINI-AVATAR PACKAGE

Copy this document into Abacus together with every file in `files/`.

---

## PROMPT FOR ABACUS

Implement the **Personalized Workout** product using the code files in this package.
The flow: a player purchases a personalized workout plan with shards → uploads (or
records) a video of themselves doing a movement screen or stress test (running,
jumping, dunking, playing, moving) → the system extracts their movement, builds a
**mini avatar of them**, analyzes their movement quality, generates a plan for THEIR
body, and renders **mini movies of their own avatar performing every exercise** in
the plan. Integrate these files into the existing app (Babylon.js/TypeScript client,
server API, server-authoritative wallet from the 10-phase pass). Wire, don't rewrite:
the files declare their integration points below. Prove completion with a recording
of the full journey: purchase → capture → processing → avatar reveal → animated plan.

**Architecture decision (do not change):** pose extraction runs CLIENT-SIDE with
MediaPipe Tasks Vision. The raw video never leaves the device by default — only the
extracted keypoint timeline (a few hundred KB of JSON) is uploaded. This is a privacy
feature, a bandwidth feature, and removes all server GPU cost. Optional video upload
exists strictly as opt-in for coach review.

## FILES IN THIS PACKAGE

| File | Purpose |
|---|---|
| `files/shared/contracts.ts` | Every type: scan, screen metrics, avatar spec, plan, movies, API DTOs |
| `files/shared/exerciseLibrary.ts` | Exercise database: clips, cues, progressions, deficit targeting |
| `files/client/pose/poseExtractor.ts` | MediaPipe client-side video → 33-landmark keypoint timeline |
| `files/shared/movementScreen.ts` | Keypoints → movement metrics (jump height, depth, asymmetry, valgus, cadence) |
| `files/shared/avatarBuilder.ts` | Keypoints + calibration → MiniAvatarSpec (proportions + palette) |
| `files/shared/clipRetargeter.ts` | Keypoint timeline → canonical-rig animation clip (their own movement, replayable) |
| `files/shared/planGenerator.ts` | Screen metrics → personalized 4-week plan; 12-week program upsell |
| `files/server/workoutApi.ts` | API routes: purchase (wallet), scan submit, status, plan fetch |
| `files/client/WorkoutPurchaseFlow.tsx` | Shard purchase UI (server-authoritative) |
| `files/client/ScanCaptureScreen.tsx` | Record/upload + consent + live pose overlay |
| `files/client/MiniAvatarPreview.tsx` | Babylon mini-avatar from spec (proportion-scaled canonical rig) |
| `files/client/ExerciseMoviePlayer.tsx` | Mini-movie: their avatar performs an exercise with authored camera |
| `files/client/PlanViewer.tsx` | The deliverable: animated plan, week/day/exercise with movies |

## INTEGRATION POINTS (wire these)
1. **Rig:** `MiniAvatarPreview`/`ExerciseMoviePlayer` load the canonical Mixamo-named
   rig from the 10-phase pass (Phase 1.1 `BoneMap`) and scale bones per
   `MiniAvatarSpec.proportions`. Exercise clips come from the shared clip library —
   reuse the CinematicMove engine (Phase 2) for camera tracks.
2. **Wallet:** `workoutApi.ts` calls the server-authoritative `EconomyService`
   (10-phase Phase 6). Products: `workout_4w` (shards) and `program_12w` (shards,
   upsell). NO client-side balance mutation.
3. **System Scan:** on completed analysis, POST metrics into the existing scan
   pillars (mirrors `backend/routers/system_scan.py` — `prq_metrics` 8 axes,
   `vertical_jump_log` for jump results) so the FEL OS profile updates.
4. **Routes:** mount client screens at `/workout` (purchase → capture → processing →
   plan). Surface entry on the home screen and in Coach tab (redesign ask).
5. **Deps:** `@mediapipe/tasks-vision` (client). No other new dependencies.

## PIPELINE (as implemented by these files)
capture/upload → `poseExtractor` (client) → keypoint timeline → submit →
`movementScreen` analyze → `avatarBuilder` spec → `planGenerator` plan →
client renders: avatar reveal → `ExerciseMoviePlayer` mini-movies (their avatar,
authored exercise clips, their OWN scan replay side-by-side via `clipRetargeter`).

## COMPLIANCE — BLOCKING REQUIREMENTS
- **Consent:** explicit consent screen before camera/upload (included in
  `ScanCaptureScreen`); processing summary states that video stays on-device unless
  opt-in. Delete-my-scan control in Profile deletes keypoints, avatar spec, and any
  opted-in video server-side.
- **Minors:** age gate ≥13 with guardian-consent copy for <18.
- **Health disclaimer:** plan screens carry "training guidance, not medical advice;
  consult a professional for injuries" (already in `PlanViewer`).
- **EU AI Act (from Aug 2, 2026):** the avatar movies are AI-generated depictions of
  the user — the included "AI-generated" badge on movies must ship.
- **Content integrity:** exercise cues in `exerciseLibrary.ts` are conventional
  coaching cues. Blueprint-derived numeric physiology claims are marked NEEDS-VERIFY
  and must not surface as fact.

## ACCEPTANCE
1. Full journey recording: shard purchase (server ledger entry visible) → consent →
   capture with live skeleton overlay → processing states → avatar reveal (visibly
   proportioned from the user, not the default avatar) → plan with ≥12 exercises
   across 4 weeks, EVERY exercise playing a mini-movie of the user's avatar → "your
   scan vs target form" side-by-side for at least the screen movement.
2. Network log proving raw video was NOT uploaded in the default path.
3. 12-week upsell purchasable and delivering the extended program.
4. Scan results visible in System Scan profile (metrics + vertical jump).
5. Delete-my-scan wipes server data (show the ledger/collection before/after).
