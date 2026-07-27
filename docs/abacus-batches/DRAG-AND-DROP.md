# Drag-and-drop index — everything built in this session

**17 batches, 26 new core modules, 1,494 passing assertions.**
Every zip is in this folder. **Integration order is strict** — later batches
replace files from earlier ones.

Before anything else, read **`docs/GAP-AND-PASS-2.md`**. The short version:
this is a large amount of tested logic and **zero of it has been observed
running in the deployed app.** Integrating M84 into one mode is worth more than
integrating all fourteen into none.

---

## Order

| # | zip | what it is | breaking? |
|---|---|---|:-:|
| 1 | `m80-external-animation.zip` | Meshy/DeepMotion clips can finally load | no |
| 2 | `m81-feel-foundation.zip` | movement, engine lifecycle, PRQ→difficulty, canvas | **YES** |
| 3 | `m82-accessibility-and-prq.zip` | a11y, captions, colour, canonical PRQ weights | no |
| 4 | `m83-determinism-and-ghosts.zip` | fixed timestep, seeded RNG, replays, ghosts | no |
| 5 | `m84-phase1-integration-kit.zip` | **`ModeKit` — start here after M83** | no |
| 6 | `m85-phase2-basketball.zip` | vertical-gated dunks, a defender you can fake | no |
| 7 | `m86-phase3-combat.zip` | frame data, whiff punish, spacing | no |
| 8 | `m87-phase4-field-precision.zip` | evade reads, pitch recognition, rally pressure | no |
| 9 | `m88-phase5-board.zip` | trick lines, real carve physics, procedural waves | no |
| 10 | `m89-phase6-creative-cognitive.zip` | MRI that measures something; the creator loop | no |
| 11 | `m90-phase7-ecosystem.zip` | receipt integrity, season pass, progression | no |
| 12 | `m91-phase8-multiplayer.zip` | server-side verification, rollback netcode | no |
| 13 | `m92-phase9-presentation.zip` | the tell registry, adaptive quality, a11y juice gate | no |
| 14 | `m93-phase10-certification.zip` | the honest scorecard | no |
| 15 | `m94-pass2-dunk-migration.zip` | **`dunk` actually on the kit** — replaces `modes/DunkMode.ts` | **YES** |
| 16 | `m95-pass2-canvas-and-baseline.zip` | **the phone canvas fix, measured live: 33% → 80%** | no |
| 17 | `m96-pass2-grounding-and-lifecycle.zip` | **skateboard/snowboard/surf stop losing the rider** | no |

**M95 and M96 depend on nothing and can ship first.** It is the only batch here whose
effect has been observed in the deployed product — see
`docs/BASELINE-2026-07-27.md`.

---

## The one breaking change

**M81 changes `runMode()` from async to synchronous.**

```ts
// before
const stop = await runMode(def, { canvas });

// after
const handle = runMode(def, { canvas });
return () => handle.dispose();     // reachable immediately — this IS the fix
```

That ordering is the entire fix for *"you need to refresh the page to load a
game."* `runModeLegacy()` restores the old signature to stage the migration; it
warns, because it also restores the bug.

## Three changes that silently cancel their batch

Each of these is one line, and without it the batch does nothing:

1. **`PlayerSlot.LocalInputSource` must stop deriving `sprint` from stick
   magnitude.** Bind it to L1/Shift. Leaving it cancels most of M81 — the
   player keeps sprinting 100% of the time.
2. **Mode movement must pass camera yaw into `kit.move()`,** or movement stays
   world-relative and still feels wrong.
3. **Nothing currently enforces `canAct()`** (M86). If a mode lets a player
   attack during recovery, every guarantee in the combat batch evaporates.

## Also needs doing outside the zips

- **`backend/routers/games.py`** — already patched in this repo with the
  canonical PRQ weights. If your deployed backend is a different copy, apply
  the `weights` block from `config/prqWeights.json`, **including
  `market_browse: 0.0`** — the row that stops a shop minting PRQ.
- **Serve `assets/ready/anim/`** at `/assets/ready/anim` (M80). Create it even
  while empty; the game must play fine with nothing in it.
- **Route six modes:** `dance`, `art`, `acting`, `irl`, `brain_brawl`,
  `who_scene_it` (`core/modeRoutes.ts`, M79). Finished code behind six strings
  — still the cheapest win available.

---

## Verify before and after

```bash
node tools/certify.mjs             # 22/22 suites, 1353 assertions, gate clean
node tools/verify_batch.mjs --all  # 0 errors
node tools/integration_audit.mjs   # what is ACTUALLY running in the live build
```

The third one is the one that matters and it needs a session cookie
(`node tools/smoke.mjs --login`). It is the only tool here that measures the
product rather than the repo.

---

## If you integrate only one thing

**M94.** It is M84 already integrated into `dunk`, so the answer to "is the kit
the right shape" no longer costs you the experiment — it costs you a routing
change and a deleted file.

The line-count gate came back a **wash**: 427 code lines became 428. The kit
does not pay for itself in lines. It pays in what those lines now do —
deterministic ticks, a seeded rival, ghost recording, server-side verification,
PRQ-scaled judging, an accessible QTE window and two tells, none of which
existed in the 427. Adoption cost 18 lines against M84's promised ~20.

Route `dunk` to `modes/dunk/DunkMode.ts`, **delete `modes/DunkMode.ts`**, then
run `node tools/integration_audit.mjs`. That audit is the artifact everything
after this depends on.
