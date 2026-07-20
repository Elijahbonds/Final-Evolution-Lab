# FEL KNOWN ERRORS — the regression ledger

Every error this project has ever shipped, its root cause, the batch that
fixed it, and the check that proves it hasn't come back. **Every future batch
must run the REGRESSION SWEEP at the bottom before promote.** Copy this file
into every batch handed to Abacus.

| # | Symptom (as seen live) | Root cause | Fixed in | Never-repeat check |
|---|---|---|---|---|
| E1 | "Wrong sceneFilename parameter" — no character loads | `LoadAssetContainerAsync('', '/models/x.glb')` (empty rootUrl + leading slash) and missing glTF loader side-effect import | M29/M30 | Console has zero `sceneFilename` errors; `@babylonjs/loaders/glTF` import present in CharacterLibrary |
| E2 | Every mode: `[FEL-ANIM] MISSING CLIP` — nothing animates | `instantiateModelsToScene` suffixes AnimationGroup names (`guard`→`guard_c58`), breaking alias lookups | M30 | Zero `MISSING CLIP` console lines across a full mode sweep |
| E3 | Every mode errors out seconds after start ("black screen detected" loop) | RenderWatchdog v1 sampled the mid-pipeline framebuffer (false positive) and armed outside the playing phase | M34 | Watchdog samples final composited screenshot, arms ONLY in `playing`, needs 2 consecutive black samples |
| E4 | True black screens with no recovery UI | No error boundary around the 3D canvas | M31 | GlobalErrorBoundary mounts every mode route; smoke test green |
| E5 | Characters sunk to their waists in the floor | Imported GLB clips key `Hips.position` in clip-local space below our floor | M35 | importSanitizer strips imported position tracks + GroundLock clamps every frame; record 60s of karate — zero sunk frames |
| E6 | T-pose after any one-shot animation ends | Finished non-looping AnimationGroup drops weights → bind pose | M35 | `neverBindPose()` wraps every animator; zero T-pose frames in sweep video |
| E7 | Two control decks on screen at once, neither works | Legacy in-canvas buttons AND new deck both mounted; neither wired to InputBus | M35 | DOM census: exactly ONE stick + ONE action cluster; every verb visibly acts |
| E8 | Dunk sequence stalls forever mid-attempt | No timeout on cinematic phases; a failed clip/await hangs the mode | M35 | Watchdog budgets on every phase; deliberately ignore SLAM → auto-resolves as miss |
| E9 | Hero/action out of frame (karate stares at floor, football runner invisible, camera at feet) | Camera targeted feet/look-ahead at y=0 with no pitch cap or subject-height offset | **M37** | FrameGuard: hero projected on-screen ≥95% of a 60s run in every mode; `[FEL-FRAME]` errors are zero |
| E10 | Board sports render NOTHING (flat clear-color screen, HUD ticking) | Ride modes never build world geometry / camera opens facing empty space | **M38** | SpawnGuard: `[FEL-SPAWN]` asserts ≥ N world meshes + hero visible before phase=playing; screenshot of each ride mode shows terrain |
| E11 | Precision sports (tennis/golf/baseball/soccer) have no characters at all | Modes drive a ball but never spawn the athlete or furniture | **M40** | SpawnGuard hero assert; screenshots show athlete + net/flag/plate/keeper |
| E12 | 404 on every mode page: `/img/venues/*.jpg` | Venue thumbnail images never shipped | **M37** | Network tab: zero 404s on mode routes (procedural thumbnails) |
| E13 | Buttons/keys "don't work" even when one deck renders | Touch deck not wired to InputBus; keyboard map undocumented/divergent | M35/M37 | Single KeyboardMap + TouchOverlay both emit the same FelInput; sweep proves every verb acts |
| E14 | Secrets nearly committed (Firebase plist, API keys) | Config files in repo tree | early | `.gitignore` covers them; secret scan green on every batch; env vars only |
| E15 | Real-money features shippable without gates | — | M33/M36 | Cash entry requires geo+18+ +limits; USD rails separate from shards; free contests unaffected |

## REGRESSION SWEEP (run before every promote)
1. Console sweep of all mode routes: zero `MISSING CLIP`, zero `sceneFilename`,
   zero `[FEL-FRAME]`, zero `[FEL-SPAWN]`, zero unexpected 404s.
2. DOM census on two modes: exactly one control deck.
3. 60s recorded run of karate + dunk + one ride mode + one precision mode:
   characters on the floor plane, no T-pose, hero framed, world visible.
4. Smoke test (M31) green across every mode id.
5. Secret scanner green.

Diagnostics stay loud in production (`[FEL-ANIM]`, `[FEL-WATCHDOG]`,
`[FEL-FRAME]`, `[FEL-SPAWN]`, `[FEL-DUNK]`) — they are how each live audit
finds the next bug in minutes. Never strip them.
