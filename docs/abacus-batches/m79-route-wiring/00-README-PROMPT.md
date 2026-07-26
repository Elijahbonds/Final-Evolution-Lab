# M79 — route wiring + a playtest of all 19 live modes

Depends on M77 (`modeRegistry`) and M78 (the four new modes).

---

## FIRST, PLAINLY: I CANNOT WIRE THE ROUTES

The routes live in the Abacus-hosted Next.js app and this repo has no copy of
it. What I can do is make wiring a **drop** instead of a writing job, and
playtest everything that is already live. Both are in here.

---

## THE PLAYTEST — all 19 live modes, driven through their start gates

| | Result |
|---|---|
| Reached `playing` | **17 / 17 3-D modes** |
| 2-D modes working (no `#fel-ready` by design) | **2** — gymnastics, music |
| `SKINNING STALL` | **0** |
| `MISSING CLIP` | **0** |
| `groundSnap` firing | **every mode** |

**M69 is fully integrated and working across the entire app.** `groundSnap`
logs on every spawn in every mode — the sunk-character bug is gone
product-wide, not just where I first found it.

### Two real findings

**1. Camera collapse in three modes — `[FEL-FRAME]` hero off-screen**

Measured from the live logs:

| Mode | Hero → camera horizontal distance |
|---|---|
| `karate-vs` | **0.75 m** |
| `baseball` | **0.89 m** |
| `golf` | 3.2 m, but pitched steeply overhead |

`MIN_SAFE_DISTANCE` is 1.8 m. Two of these are less than half of it — the
camera is effectively standing inside the player.

This is exactly what **M69's `CameraStandoff.ts`** fixes, and it is evidently
not integrated: `groundSnap` from the same batch clearly is. Worth checking
whether the whole of M69 landed or only part of it.

It is **intermittent** — it depends on where the player moves, so a single
smoke run can miss it. A run that passes does not clear these three.

**2. Gymnastics is fine; my tool was wrong**

The playtest reported gymnastics as never starting: no `#fel-ready`, no spawn.
It starts perfectly. Two of my own blind spots stacked:

- Its start button says **"SALUTE THE JUDGES"**, not "TAP TO START". My
  detector matched the label, so it never clicked.
- It is a **2-D timing minigame** — photo backdrop, stick figure, LEFT/RIGHT
  rhythm prompts. It has no Babylon scene, spawns no characters, and publishes
  no `#fel-ready`, all correctly.

So a healthy mode was reported broken twice over. That is the third time this
tool has produced a false negative by assuming every mode looks like the modes
I happened to test first — after the auth wall (M68) and the start gate (M69).

## `tools/smoke.mjs` v4 — stop guessing what a mode looks like

- **The start gate is no longer matched by label.** It clicks the largest
  non-navigation button on the page, because a start gate is by construction
  the most prominent control on a screen whose only job is to be clicked. It
  reports which label it clicked, so a wrong click is visible rather than
  silent.
- **2-D modes are judged on their own terms.** No `#fel-ready` plus a rendered
  surface is reported as a 2-D mode, not a failure.

Verified against both blind spots:

```
        (2-D mode: no #fel-ready by design; clicked "SALUTE THE JUDGES")
[SMOKE] PASS /play/gymnastics
```

## `core/modeRoutes.ts` — the wiring artifact

A lazy loader per pending route, keyed by the same string the registry uses.

**Lazy, not a static map**: every mode pulls in Babylon, a venue, a core and a
content pack. A static map means `/play/music` downloads the karate wave AI and
the rally engine. On a 25-mode app that is the difference between a first load
people wait through and one they don't.

It also records **how each mode mounts** — `harness` (a `ModeDefinition`) vs
`react` (owns its own surface, like Music and Art). Handing a React component
to `ModeHarness` calls `load(ctx)` on something that has no such method, so
this is not a subtle distinction.

If `/play/[mode]` is a dynamic route with a whitelist — very likely, since
unknown modes 404 rather than error — **the entire job is adding six strings to
that whitelist** and mounting by `kind`.

## FILES

| File | Goes where |
|---|---|
| `files/core/modeRoutes.ts` | game source `core/` |
| `files/tools/smoke.mjs` | repo `tools/` — **REPLACES M69's** |

## WIRING

1. Add the six routes: `dance`, `art`, `acting`, `irl`, `brain_brawl`,
   `who_scene_it` — mounting by `kind` from `modeRoutes.ts`.
2. Re-check that **all** of M69 is integrated, specifically
   `core/CameraStandoff.ts` and its call in `CameraDirector.follow()`.
3. `node tools/route_audit.mjs` → expect **25 live · 0 unrouted · 0 unbuilt**.

## ACCEPTANCE

1. `node tools/route_audit.mjs` → 25 live, no drift.
2. `node tools/smoke.mjs --modes <all 25>` → all PASS; 2-D modes annotated
   rather than failed.
3. `karate-vs`, `baseball`, `golf`: drive the player to the venue edges
   repeatedly — **no `[FEL-FRAME]` hero off-screen**. This is the one that
   needs deliberate movement; it will not show up in a passive run.

## ALSO WORTH DECIDING

**Gymnastics uses a photographic backdrop.** Every other venue is procedural —
that is a deliberate constraint (nothing to download, nothing to 404) and it is
what the M59/M61/M73 art direction is built on. Gymnastics is visibly a
different game from the rest of the product. Either it should move onto the
M73 venue system (a `gymnastics` venue already exists and renders), or the
constraint should be relaxed on purpose rather than by exception.
