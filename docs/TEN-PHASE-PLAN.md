# The 10-phase pass to a world-class FEL

**Companion to** `docs/BLUEPRINT.md` (what's broken and why) and
`docs/AGENT-ACCESS-AND-PROTOCOL.md` (who writes where).
**Started** 2026-07-27.

---

## The efficiency problem, stated before the plan

I scanned the repo before writing this. The numbers matter:

| | |
|---|---|
| Batch code authored | **49,400 lines** across 84 batches |
| Mode files | 98 |
| Core modules | 42 |
| Lines I have ever seen execute in the real app | **0** |

Authoring is not the bottleneck. **Integration verification is.** Every batch
ships with "not type-checked against the live source" on it, and we already
know that failure is not theoretical:

- M69 shipped `groundSnap` and `CameraStandoff` together. `groundSnap` runs in
  production. `CameraStandoff` shows no evidence of ever having run. **Nobody
  knew for six batches.**
- `applyArtCard` looked for a mesh name no venue builds — for months.
- M74 shipped duplicate tennis and volleyball modes that already existed.
- M77 reported six live routes as broken.

Ten more phases of authoring at that rate produces 100,000 unverified lines
instead of 50,000. **So the plan is built around closing that loop, not around
writing more code faster.**

Three levers, in order of value:

1. **Sync the app source** (`docs/ACCESS-SETUP.md`). Converts every future
   phase from inferred to type-checked. Still the single highest-value action
   available and it is not mine to take.
2. **One adapter instead of five wirings.** Phases 2–6 each touch many modes.
   If every mode has to be wired to `SimLoop` + `MotionModel` + `DDA` + `a11y`
   + `captions` by hand, that is five chances to get it wrong times twenty-five
   modes. `ModeKit` (Phase 1) makes it one.
3. **Audit the deployed app, not the batch.** A tool that asks the *live* build
   which subsystems are actually running. That is the only thing that would
   have caught `CameraStandoff`.

---

## The phases

Phases 2–6 are the mode work. They are cheap only if Phase 1 lands first,
which is why Phase 1 is not "start on basketball".

| # | Phase | Covers | Gate to pass |
|---|---|---|---|
| **1** | **Integration kit** | `ModeKit`, live integration audit, migration order | A mode adopts all five subsystems in <20 lines; the audit reports what is actually running in production |
| 2 | Basketball | dunk, onevone, threevthree, dunkduel, carnival | Flagship: vertical-gated dunk tiers; read-and-react defence |
| 3 | Combat | karate, karate-vs, mixedcombat | Neutral game — spacing and whiff punish, not combo memorisation |
| 4 | Field & precision | football, soccer, baseball, tennis, volleyball, golf, gymnastics | Football (PRQ 1.5) gets the most depth; pitch *recognition* in baseball |
| 5 | Board | skateboard, snowboard, surf | Line-building; a real carve model; the wave as the level |
| 6 | Creative & cognitive | music, dance, art, acting, brain_brawl, who_scene_it, irl | Route the six; the music→soundtrack loop; IRL camera judging |
| 7 | Ecosystem | economy, Creator Cards, season pass, progression, receipts | One flat marketplace, one hop of royalties, tested |
| 8 | Multiplayer & arena | Phase B transport, Phase C rollback, Cash Arena integrity | Server re-simulates a recorded match and agrees with its hash |
| 9 | Presentation | audio, lighting, VFX, game feel, HUD | 60 fps held; every cue captioned; reduced-motion honoured |
| 10 | Certification | all 25 modes against the 12-point bar | `docs/BLUEPRINT.md` §7, 1–9 mandatory |

**Foundation already shipped** (M80–M83, not counted as phases): external
animation, movement/engine lifecycle/PRQ-as-input, accessibility, determinism
and ghosts. Phases 2–6 assume all four are integrated.

---

## What "better than its inspirator" means here

Fixed meaning, applied to every mode in phases 2–6. A browser build will not
out-render a console studio, and pretending otherwise is how a project spends a
year losing that fight.

> **The benchmark's loop, plus an athletic identity that persists across every
> mode.** The dunk contest that knows your actual vertical. The rally whose
> opponent is faster because your readiness is high today. No commercial title
> can do that, because none of them has your PRQ.

Genre benchmarks identify a *mechanic class* only. Never assets, code,
character names, or visual motifs. Every venue procedural, every character
original.

---

## Phase gate

No phase is complete until:

1. Its tests pass by execution.
2. `node tools/verify_batch.mjs` is clean.
3. `node tools/integration_audit.mjs` confirms the *previous* phase is actually
   running in the deployed app.

Rule 3 is the one that matters. It is what stops phase 7 being built on a
phase 4 that never landed — which is exactly what happened to
`CameraStandoff`, and what will happen again by default.
