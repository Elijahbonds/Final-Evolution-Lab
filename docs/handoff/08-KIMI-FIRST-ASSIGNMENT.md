# 08 — KIMI FIRST ASSIGNMENT · Batch K1

**Paste this (with docs 00–06 attached) as Kimi's opening prompt.**

---

You are Kimi, the file-generation engineer for Final Evolution (see `04-KIMI-BRIEF.md`
for your role, conventions, and deliverable format — it is binding).

## Batch K1 scope — "Feel Core + Console Shell in Dunk"
Implement, as complete drop-in files:

1. **A1 — AnimationDriver** (m13-01 §A, contract 06 §6): input → state → clip system
   with priorities, interrupt rules, one-slot input buffer, ≤100 ms latency, fallback
   clip + warning on missing clips, dev state-overlay.
2. **A2 — Orientation system** (m13-01 §B): `characterYaw = f(velocity, target)`,
   engagement targets, 540°/s slew, forward-axis normalization helper.
3. **B1 — Input bus + ControllerOverlay** (03 §2.1–2.3, 2.5): `FelInput` event bus;
   touch overlay with dual sticks, d-pad, verb-labeled ABXY, bumpers, analog triggers,
   SELECT/START; portrait DS layout + landscape Switch layout; keyboard adapter;
   Gamepad API adapter with auto-hide; haptics adapter.
4. **B1-slice — wire it all into DUNK CONTEST only** (m13-04 as the mode spec):
   dunk controls config (06 §4: stick drive · R2 hold charge · A SLAM · B style ·
   X signature · screen tap/swipe), ball-in-hand pipeline, three distinct style
   clips requested through the AnimationDriver, camera preset per m13-03's dunk rules,
   READY gate + 3-2-1.
5. **Configs, ready for rollout:** `controls.json` files for karate, football, and
   skate per 03 §2.4 (not wired — next batches).
6. **Tests:** inputBus mapping, trigger analog from hold-duration, AnimationDriver
   interrupt/buffer logic, dunk slam timing window, orientation slew.

## Out of scope for K1
Console home rail, boot/eject ritual, bezel (B4–B6); other modes' wiring; any meta/
economy surface; any backend change.

## Deliverable
`kimi-batches/K1-feel-core-shell-dunk/` exactly per `04-KIMI-BRIEF.md` §3 —
MANIFEST.md (scope, file list, assumptions, wiring notes, acceptance mapping, open
questions) + `files/` + `tests/`. Whole files only. TypeScript/React/three.js-class
conventions per §2.

## Acceptance you are mapping against
- m13-01 A+B acceptance (all bullets), 03 §3 shell acceptance as it applies to Dunk,
  m13-04 ball/style/READY items, m13-08 "Global" + "Dunk" checklist rows.
- Verifiable in 30 seconds each — say HOW in the manifest.
