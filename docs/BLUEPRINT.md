# Final Evolution Lab — Build Blueprint

**For:** Claude Code (Mac Mini) · Abacus AI · Claude Code (cloud)
**Companion:** `docs/AGENT-ACCESS-AND-PROTOCOL.md` — read that first; it says who
may write where.
**Context:** `docs/FEL-VISION.md` is the product vision and stays authoritative
on *what* FEL is. This document is *how it gets built*, and it is the one
document all three agents work from.
**Date:** 2026-07-26

---

## §0 — How to read this

Every claim carries an evidence level. Do not silently promote one:

| Tag | Means |
|---|---|
| **VERIFIED** | I ran it. Command and output are in the repo history. |
| **INFERRED** | Reasoned from code I read. Not executed against the live app. |
| **ASSUMED** | Could not check. Stated so it can be falsified. |

**The standing caveat, once, for everything below:** the live Babylon app is
not in this repo. Where I cite `ModeHarness.ts` or `InputBus.ts`, I am citing
the last version this repo shipped to Abacus (M26/M29). The live app may have
drifted. **Every fix in §1 must be confirmed against the real file before it
is applied** — and the first agent to get repo access to the app source should
do exactly that.

---

## §1 — The five defects, root-caused

### §1.1 "You need to refresh the page for the games to load each time"

**Severity: P0.** It breaks the console illusion the entire product rests on.

**Root cause — INFERRED, high confidence.** `runMode()` in
`core/ModeHarness.ts` is `async` and awaits `def.load(ctx)` — venue build,
character GLB fetch, clip registration, easily 2–5 seconds — **before**
returning its teardown function:

```ts
export async function runMode(def, opts): Promise<() => void> {
  const engine = new Engine(opts.canvas, true, {...});   // context allocated HERE
  ...
  await def.load(ctx);                                    // 2–5 seconds
  ...
  return () => { ...engine.dispose(); };                  // disposer arrives LAST
}
```

If the React effect unmounts during that await — a route change, a back
button, React 18 StrictMode's deliberate double-invoke in dev — **the caller
never receives the disposer.** The engine, its render loop, and its WebGL
context leak. Nothing cleans them up.

Browsers hard-cap live WebGL contexts (Chrome ~16, Safari ~8). Once the cap is
hit the browser silently kills the oldest context or refuses a new one, and
`new Engine(canvas)` produces a black canvas with no exception. **A full page
reload is the only thing that frees them** — which is precisely the reported
symptom, including "each time," because the count only ever grows within a
session.

Three secondary leaks in the same function, all INFERRED from the same file:

1. `startCountdown()`'s `setInterval` is never cleared on teardown. Dispose
   mid-countdown and it keeps calling `setPhase` on a disposed scene.
2. `engine.stopRenderLoop()` is never called before `engine.dispose()`.
3. `input.start()` binds four `window` listeners; they're released only on the
   same disposer that may never arrive.

**Fix.**

- Make `runMode` return its handle **synchronously**. Allocate the engine, set
  up teardown, *then* kick off `load()` as a tracked promise. The caller can
  always dispose.
- Take a cancellation token. If disposed during load, abandon the result and
  tear down rather than mounting into a dead scene.
- On dispose, in order: `engine.stopRenderLoop()` → clear every timer →
  `scene.dispose()` → `engine.dispose()` → drop the canvas reference.
- Guard against double-mount: keep a module-level `WeakMap<HTMLCanvasElement,
  Handle>`; if a canvas already has an engine, dispose it first.
- Expose `window.__FEL_ENGINES__` (a count) so this is observable.

**The decisive test — run this before writing any code.** It converts a
hypothesis into a fact in about a minute:

```js
// paste in the console on the live app, then navigate between 8 modes
// WITHOUT reloading
performance.getEntriesByType('resource');            // ignore
let n = 0;
const orig = HTMLCanvasElement.prototype.getContext;
HTMLCanvasElement.prototype.getContext = function (...a) {
  if (String(a[0]).startsWith('webgl')) console.log('[CTX]', ++n);
  return orig.apply(this, a);
};
```

If the counter climbs past ~8 and the game goes black around there, this
section is correct and the fix is exactly as described. If the counter stays
at 1–2, the cause is elsewhere and the next suspect is the Next.js route
component remounting without re-running the effect — check for a stale
`useEffect` dependency array or a `key` that doesn't change per mode.

**Acceptance:** navigate 20 modes in a row without reloading; the 20th boots
as fast as the first, context count never exceeds 2, no `WebGL context lost`.

---

### §1.2 "The movement systems are broken. I should feel in control."

**Severity: P0.** This is the one that decides whether FEL feels like a
console game or a tech demo, and it is not one bug — it's nine, stacked.

All of the following are **VERIFIED by reading**
`docs/abacus-batches/m26-babylon-batch2-framework/files/core/InputBus.ts` and
`m48-basketball-simulator/files/core/PlayerSlot.ts` — i.e. the code as shipped.
Confirm against the live files before applying.

**a) The player is always sprinting. There is no walk.**

```ts
// PlayerSlot.ts — LocalInputSource.poll()
sprint: Math.hypot(this.moveX, this.moveY) > 0.85,
```

Keyboard WASD emits `x, y ∈ {-1, 0, 1}`. A single key held gives magnitude
**1.0**, which is `> 0.85`. So on keyboard, **sprint is on 100% of the time
the player is moving at all.** There is no walking speed, no way to make a
small adjustment, no touch. That single line explains most of "I don't feel in
control."

**b) Diagonals are 41% faster.** No normalization. W+D gives `hypot(1,1) =
1.414`. Every diagonal is a speed boost — the oldest bug in third-person
movement.

**c) The stick is digital and unsmoothed.** Input goes 0 → max → 0 in one
frame. Real character control ramps. Without acceleration and deceleration the
character reads as weightless and twitchy, never *responsive*.

**d) Keys stick on blur.** `held` is a `Set` that is only ever cleared by a
matching `keyup`. Alt-tab, switch apps, or open a notification while holding
W and that `keyup` never arrives — **the character runs forever.** On mobile
this fires constantly.

**e) No `preventDefault`.** Arrow keys and space scroll the page under the
canvas while you play.

**f) Space is overloaded.** On release it emits a trigger-zero *and* a button
A press. Charge-release and jump are the same event; no mode can distinguish
"I finished charging" from "I tapped jump."

**g) The gamepad deadzone is a cliff.** `Math.abs(v) < 0.15 ? 0 : v` — at
0.149 you get 0, at 0.151 you get 0.151. The correct form rescales the
remaining range so output is continuous from zero.

**h) The gamepad floods the bus.** Four stick/trigger events every
`requestAnimationFrame` regardless of whether anything changed — 240 events/sec
into every listener.

**i) Movement is probably not camera-relative.** ASSUMED — I can't see the
per-mode movement code. But if input `x/y` maps to world axes rather than the
camera's basis, then "forward" changes meaning every time the camera swings.
In a third-person game this is *the* single largest contributor to feeling out
of control. **Check this first; it may outrank everything above.**

**Fix — a real motion model.** Not a patch; the layer that was never written.
`core/MotionModel.ts`, pure and testable, sitting between `Intent` and the
character:

| Parameter | Value | Why |
|---|---|---|
| Radial deadzone | 0.12, **rescaled** `(‖v‖−dz)/(1−dz)` | continuous from zero |
| Magnitude clamp | `if ‖v‖ > 1: v /= ‖v‖` | kills the diagonal boost |
| Keyboard accel ramp | 0 → 1 over **120 ms** | digital keys become analog |
| Decel ramp | 1 → 0 over **90 ms** | shorter than accel: stopping must feel crisp |
| Sprint | explicit — Shift / L3 / a real analog stick past 0.9 | **never** derived from digital keys |
| Turn rate cap | 540°/s grounded, 180°/s airborne | rotation reads as weight, not snapping |
| Coyote time | 100 ms | jump forgiveness after leaving ground |
| Input buffer | 130 ms | a press just before landing still fires |
| Input→visible response | **≤ 66 ms (4 frames)** | the hard budget; measure it |
| Basis | camera yaw, projected to ground | forward is always screen-forward |

Plus, in `InputBus` v2: clear `held` on `blur` and `visibilitychange`;
`preventDefault` on arrows/space/tab when the canvas has focus; separate
`trigger` release from `button A`; emit stick events only on change.

**How to know it worked** — these are measurable, not vibes:

1. Hold W for 2s in every 3-D mode: the character walks, then runs only with
   Shift. **VERIFIED by video, not by reading code.**
2. Hold W+D: same speed as W alone (±2%).
3. Hold W, `alt-tab`, return: the character has stopped.
4. Swing the camera 180° while holding W: the character now runs toward the new
   screen-forward.
5. Instrument input→first-pixel-change; median ≤ 66 ms on a mid-tier phone.

**This is the single highest-leverage work item in the entire product.** It
touches all 19 3-D modes at once, and no amount of art or mocap compensates for
controls that don't respond.

---

### §1.3 T-pose and animation

**Status:** pipeline shipped in **M80**; cause of the residual T-pose is now
measurable rather than guessed.

**VERIFIED live:** `restPose solved`, `restPose applied to skeleton`,
`authored clips registered`, `groundSnap` all fire; no `MISSING CLIP`, no
`SKINNING STALL`. The animation system works.

**VERIFIED:** `assets/` holds 13 Luma environment FBXs and **zero character or
animation assets**. There is no Meshy animation and no DeepMotion mocap
anywhere in the project. `HERO_URL = '/models/elijah-hero.glb'` is one file
carrying ~9 clips; everything else is hand-typed quaternion angles.

**Correction to an earlier claim of mine:** I attributed the T-pose to
`idle_stand` keying the arms 8–10° off bind. That was true of M24 and **M64
already fixed it** (`solveArmsDown`), confirmed by the live console. The
remaining cause is unknown and I will not guess a third time.

**What to do:** run any mode with `?probe=1`. `anim/PoseProbe.ts` measures the
shoulder→hand angle from straight down (0° = arms at sides, 90° = T-pose) and,
on a sustained T-pose, names which of three causes it is:

| Probe says | Cause | Fix |
|---|---|---|
| nothing playing | the mode never started a clip | mode logic — check `neverBindPose()` |
| playing, 0 bones bound | clip resolved nothing | prefixed bone names → `tools/clip_check.mjs` |
| playing, bones bound | the clip *is* driving the rig | its keys sit too close to bind — needs real data |

Full pipeline in §2.

---

### §1.4 Mobile canvas is 27% of the viewport

**VERIFIED by measurement** at 390×844 portrait: canvas **372×232 CSS px** —
27% of viewport height. Backing buffer matches CSS exactly, and the parent box
is 374×234, so the canvas already fills its parent. **The container chain is
the bug**, which means `engine.resize()` will not help — a fact worth stating
because it's the obvious first thing to try and it wastes a cycle.

**Fix:** the game surface must own the viewport. `100dvh` (not `100vh` — iOS
Safari's toolbar makes `vh` wrong), the parent chain given explicit height or
`flex: 1 1 auto; min-height: 0`, and HUD elements overlaid absolutely rather
than stacked in flow. Then `adaptToDeviceRatio` with a DPR cap of 2 so a 3×
phone doesn't render 9× the pixels.

**Acceptance:** canvas ≥ 85% of viewport height on iPhone portrait, no page
scroll, no letterbox, 60 fps held.

---

### §1.5 Camera collapse in three modes

**VERIFIED from live logs:** hero→camera horizontal distance — `karate-vs`
**0.75 m**, `baseball` **0.89 m**, `golf` 3.2 m but pitched steeply overhead.
`MIN_SAFE_DISTANCE` is 1.8 m. Two of these put the camera inside the player.

M69 shipped `core/CameraStandoff.ts` to fix exactly this and **it was never
integrated** — `groundSnap` from the same batch clearly was, so the batch
landed partially. First action: check whether `CameraStandoff` exists in the
live source at all.

It's intermittent — it depends on where the player moves, so a passive smoke
run misses it. Test by driving the player into venue walls repeatedly.

---

## §2 — The animation and mocap pipeline

Shipped in **M80**. The chain, and who does what:

| # | Step | Owner | Status |
|---|---|---|---|
| 1 | Export from Meshy / DeepMotion | **Elijah** | manual |
| 2 | `tools/clip_check.mjs <file>` — will it bind? | anyone | ✅ shipped, 21 tests |
| 3 | Conform: `bash tools/conform_clips.sh in/ assets/ready/anim/` | **Mini only** | ✅ shipped, needs Blender |
| 4 | Rename to the clip id in `anim/clipManifest.ts` | Mini | contract |
| 5 | Serve `assets/ready/anim/` at `/assets/ready/anim` | **Abacus** | to wire |
| 6 | `loadClipPack()` at character setup | **Abacus** | to wire |

**Step 3 is on the Mini and nowhere else.** No Blender in the cloud container,
none in Abacus. `tools/fel_conform.py` has existed since M65 and has never
been run. Until the Mini runs it once, the product has no mocap.

**Why skipping step 3 destroys everything silently:** FEL resolves bones by
**unprefixed** name (`Hips`). Meshy/Mixamo/DeepMotion export `mixamorig:Hips`.
A prefixed clip targets bones that don't exist — no error, no 404, it animates
nothing and leaves the character in bind pose, which on this rig is arms-out.
**It looks exactly like a T-pose and exactly like "the animation didn't
fire."**

**Recording order.** `priorityOrder()` in the manifest: `idle_stand`, `run`,
`walk`, the strafes — before any dunk. They play in *every* mode. One good run
cycle changes the whole product; one good dunk changes one screen.

**Hard rule, already enforced in code:** the game must play perfectly with
`assets/ready/anim/` empty. A missing clip degrades to procedural, never
breaks a mode. A 404 mid-match is not recoverable.

---

## §3 — PRQ integration: the missing half

PRQ (Performance Readiness Quotient, 0–100, default 75) is the number the whole
product is built around.

**VERIFIED — what exists:**
- `FinalEvolutionLab/Utilities/PRQScoring.swift` — canonical scoring: match
  reward (win 2.0 / tie 0.5 / loss 0), per-mode weights (football 1.5, karate
  1.4, 3v3 1.3, 1v1 1.2, golf 0.9…), combo/critical/dominance bonuses, and
  `rankingSessionPRQ` which deliberately stops losses from inflating rank.
- `backend/.../games.py` — `_compute_prq_delta`, `PRQ_MODE_WEIGHTS`, shard
  rewards (50/25/15), `XP_CAP_PER_SESSION = 500`.
- `PRQDrivenDDA` in Swift — PRQ drives AI aggression floor/ceiling, reaction
  speed, QTE window scale, combo chance.
- Web side: `core/sessionResult.ts` POSTs a result to `/api/sessions/result`.

**The gap — INFERRED, and it's an architectural one, not a bug:**

> **The web app writes PRQ but never reads it.**

Every Babylon mode reports *out* (`SessionResult` → PRQ delta). Nothing reads
PRQ *in* before a match starts. So the number that is supposed to be the
player's athletic identity has no effect on a single frame of gameplay in the
shipping product. `PRQDrivenDDA` — the piece that makes PRQ *mean* something —
exists only in the Swift app that isn't the product any more.

**Fix — port DDA to the web and make PRQ an input:**

1. `GET /api/prq/metrics` at mode boot; cache it in `ModeContext`.
2. Port `PRQDrivenDDA` to `core/DDA.ts` (pure, testable — it's ~40 lines of
   arithmetic and deserves ~30 tests). Same constants as Swift so the two
   platforms can never disagree.
3. Every mode's difficulty reads from it: AI aggression, reaction delay, QTE
   and timing-window scale, opponent max points.
4. **Show it.** A PRQ meter in the HUD that visibly moves during a session.
   PRQ that only appears on a results screen is a stat; PRQ that changes how
   the opponent plays is a mechanic.
5. Unify the weight tables. Swift and Python already disagree —
   `skateboarding` is 1.05 in Swift and 1.0 in Python, `brain_brawl` 1.1 vs
   0.8. **One JSON file, both read it.**

**The accessibility bridge, and it's important:** DDA's timing-window scaling
is the same machinery as an accessibility difficulty setting. Build it once,
expose it twice — as adaptive difficulty and as a player-facing assist slider.
See §5.

---

## §4 — Multiplayer

**VERIFIED — the hard part is already done.** `core/PlayerSlot.ts` has every
body on the court driven by a `ControlSource` producing a uniform `Intent`.
Game logic never reads the input bus directly. Adding a human is
"implement `NetworkInputSource`," not "rewrite the game." That decision was
right and it saved the project a rewrite.

**What's missing:** a transport, and a decision about authority.

**Recommendation — ship in this order. Do not skip to the last one.**

**Phase A · Asynchronous ghost (do this first).**
Record the winner's `Intent` stream plus a seed; replay it as an opponent.
- No servers, no netcode, no lag compensation, no matchmaking.
- Works today with `ControlSource` untouched — a ghost *is* a control source.
- Already in the vision: Cash Dunk Arena is specified around recorded ghosts
  and deterministic replayable judging.
- Delivers 80% of "I played against someone" for ~5% of the cost, and the
  recording format is the same one real netcode will need.

**Phase B · Turn-based / rally realtime.** Golf, baseball, tennis, volleyball,
brain_brawl, who_scene_it. One player acts at a time or exchanges are discrete
— a simple authoritative server with 200 ms of latency is *fine*. WebSocket,
server owns state, client shows optimistic feedback.

**Phase C · Continuous realtime.** 1v1, 3v3, karate-vs. This is the hard one
and it is a genuine engineering project: deterministic lockstep with rollback,
or server-authoritative with client prediction and reconciliation. Prerequisite
is a **deterministic fixed-timestep simulation** — currently the update loop is
`engine.getDeltaTime()`, i.e. variable and non-deterministic, so *nothing* is
reproducible. Fix that first; it also makes ghosts exact and bugs replayable.

**Standing constraint, unchanged:** no netcode written against backend
infrastructure this repo cannot see. Phase A needs none, which is another
reason it's first.

---

## §5 — Accessibility

**VERIFIED: essentially nonexistent.** One line about contrast in
`docs/DISTRIBUTION_PAGE.md`. No reduced-motion handling, no remapping, no
colorblind palettes, no captions, in a product whose entire premise is
*athletic identity for everyone*.

Target: **WCAG 2.2 AA** for all 2-D surfaces, and the game-specific bar below
for the 3-D modes (WCAG doesn't cover gameplay; these are the established
industry patterns).

| Area | Requirement | Notes |
|---|---|---|
| **Motion** | Honour `prefers-reduced-motion` | Cut camera shake, screen-flash, particle bursts. Dunk replay cam is a vestibular trigger — must be skippable. |
| **Remapping** | Every action rebindable; nothing hard-codes a key | `InputBus`'s `KEYMAP` is already a table — this is close to free. |
| **Hold → toggle** | Every hold-to-charge has a tap-to-toggle alternative | Charge mechanics are in dunk, golf, baseball, football. Holding is a motor-ability barrier. |
| **Timing** | Player-facing assist slider widening every timing window | Reuse §3's DDA `qteWindowScale`. Build once, expose twice. |
| **Colour** | Never colour alone | Success/fail must also differ in shape, icon, or position. Deuteranopia is ~6% of men. |
| **Contrast** | 4.5:1 body, 3:1 large/UI | HUD over a bright venue is the hard case — needs a scrim. |
| **Captions** | Every gameplay-relevant sound has a visual | Whistles, buzzers, crowd cues, rhythm prompts. Dance and Music are unplayable deaf without this. |
| **Screen reader** | Menus, hub, results, store fully navigable | Gameplay canvas is exempt; getting *to* and *from* a game is not. |
| **One-handed** | Every mode playable with one hand | Touch overlay already puts the stick and buttons on opposite sides — needs a mirrored/compact layout. |
| **Text** | Respects OS text size to 200%; no text baked into textures | Affects HUD authoring. |
| **Photosensitivity** | No >3 flashes/sec, no large red flashes | Karate hit-flash and Court Carnival need auditing. |

**Do this before the modes get polished, not after.** Retrofitting captions and
remapping across 25 modes costs several times what building them into the
harness once does. The right home for most of it is `ModeHarness` + `InputBus`
— one place, 25 modes.

---

## §6 — The 25 modes: full vision

**Ground rule, non-negotiable.** Genre benchmarks below name commercial games
**only to identify a mechanic class**. Take nothing else: no assets, no code,
no character names, no visual motifs, no franchise references. Every venue is
procedural, every character original. Who Scene It and Karate Agent Waves are
100% original content by construction.

**"Better than the benchmark" has one meaning in FEL, and it isn't fidelity —**
a browser build will not out-render a console studio. It's this: **the
benchmark's loop, plus a real athletic identity that persists across every
mode.** The dunk contest that knows your actual vertical. The rally whose AI
gets faster because your readiness is high today. No commercial title can do
that, because none of them has your PRQ.

### 6.1 Status

**VERIFIED 2026-07-26 by route probe:** 19 live · 6 unrouted · 0 unbuilt.
Every mode named anywhere in this project now has a module. Unrouted:
`dance`, `art`, `acting`, `irl`, `brain_brawl`, `who_scene_it` — six strings in
a route whitelist, per `core/modeRoutes.ts` (M79).

### 6.2 Per-mode

Columns: **Benchmark** = mechanic class · **The differentiator** = the one
thing that must exist for this mode to be worth shipping · **PRQ** = how the
number enters gameplay, not just the receipt · **MP** = §4 phase.

#### Basketball

| Mode | Benchmark | The differentiator | PRQ | MP | Biggest gap |
|---|---|---|---|---|---|
| `dunk` | Dunk-contest minigames | Your **scanned vertical** sets reachable dunk tier. A 38" vertical unlocks animations a 24" cannot. This is the flagship — it is the product thesis in one screen. | vertical → tier gate; PRQ → judge strictness | A ghost | Procedural dunk clips read stiff. **Top mocap priority.** |
| `onevone` | Street 1v1 | Read-and-react defense: fake, drive, contest — not a timing bar | DDA aggression + reaction delay | C | Movement (§1.2) |
| `threevthree` | Half-court 3v3 | Teammate AI with real off-ball movement; a pass that arrives where you'll be | DDA + teammate competence | C | AI is the whole mode; needs its own pass |
| `dunkduel` | Head-to-head trick trading | Escalation: you must beat the last dunk, not just land one | judge strictness | A | Needs the shared dunk library first |
| `carnival` | Party minigame collection | 4–6 micro-events sharing one court and one scoring bar | window scale | B | Event variety |

#### Combat

| Mode | Benchmark | The differentiator | PRQ | MP | Biggest gap |
|---|---|---|---|---|---|
| `karate` | Arena survival waves | Waves that teach: each introduces one tell, then combines them | wave pacing + enemy count | — | Genuinely close to good |
| `karate-vs` | 3-D arena fighter | Neutral game — spacing and whiff punish, not combo memorisation | DDA aggression + block window | C | **Camera 0.75 m (§1.5)** |
| `mixedcombat` | Mixed-style versus | Style switching mid-match with real trade-offs | reaction delay | C | Needs distinct move properties per style |

#### Field & precision

| Mode | Benchmark | The differentiator | PRQ | MP | Biggest gap |
|---|---|---|---|---|---|
| `football` | Kick-return arcade | Juke/spin with commitment frames — a real risk decision, not a dodge button | DDA defender pursuit | B | Highest PRQ weight (1.5); deserves the most depth |
| `soccer` | Penalty shootout | Keeper reads your *tendencies* across sessions | keeper reaction | B | Needs per-player tendency memory |
| `baseball` | Home-run derby | Pitch recognition — the skill is identifying, not timing | window scale | B | **Camera 0.89 m (§1.5)** |
| `tennis` | Rally exchange | Rally as a physical duel: shot placement builds pressure | rally speed ramp | B | `RallyCore` shipped (37 tests); needs feel |
| `volleyball` | Rally exchange | Bump-set-spike as a 3-beat rhythm, not one swing | rally speed | B | Same core, needs its own identity |
| `golf` | Closest-to-pin | Wind, lie and nerve — a putt that matters | window scale | B | Camera pitched overhead (§1.5) |
| `gymnastics` | Rhythm/timing routine | Routine composition — you choose the elements, difficulty scales reward | window scale | B | **Only mode with a photographic backdrop.** Every other venue is procedural. Move it onto the M73 venue system or relax the constraint deliberately — not by exception. |

#### Board sports

| Mode | Benchmark | The differentiator | PRQ | MP | Biggest gap |
|---|---|---|---|---|---|
| `skateboard` | Trick-line combo skating | Line-building: a combo that survives across the whole park | balance decay rate | A | Trick vocabulary is thin |
| `snowboard` | Downhill slalom | Carve physics — speed from a good line, not a button | balance decay | A | Needs a real carve model |
| `surf` | Wave riding | The wave is the level and it's never the same twice | wave difficulty | A | Wave generation is the mode |

#### Creative & cognitive

| Mode | Benchmark | The differentiator | PRQ | MP | Biggest gap |
|---|---|---|---|---|---|
| `music` | Loop-based studio | Music you make **becomes** other modes' soundtrack | — | — | React mode; needs the export→equip loop |
| `dance` | Rhythm dance | Choreography drives the same skeleton the sports modes use — one avatar, every mode | timing windows | B | **Unrouted.** `DanceCore` shipped, 32 tests |
| `art` | Creative canvas | Art applied as a real venue skin — your court, in your game | — | — | **Unrouted.** `applyArtCard` v2 fixed the mesh-name bug |
| `acting` | Performance/delivery | Scored on timing, energy and range from the mic | — | — | **Unrouted.** `ActingCore` shipped |
| `brain_brawl` | Fast-recall quiz | Cognitive load *under* physical fatigue — the MRI thesis | window scale | B | **Unrouted.** `QuizCore` shipped (36 tests). 48 questions sit unported in `BrainBrawlQuestionBank.swift` |
| `who_scene_it` | Scene-recall quiz | 100% original scenes — no franchise material, by design | window scale | B | **Unrouted.** Same core |
| `irl` | Camera-based judging | Phone camera judges a real jump; the number enters the same PRQ | **the source of PRQ** | A | **Unrouted.** `IRLCore` shipped (40 tests). Highest-risk, highest-differentiation mode in the product. |

### 6.3 The pattern in that table

Six modes are finished code sitting behind six missing route strings. That is
the cheapest quality win available anywhere in this project — measured in
strings, not sprints. **Do it first** (`core/modeRoutes.ts`, M79).

And every "biggest gap" for the 19 live modes is one of: **movement (§1.2)**,
**animation data (§2)**, or **camera (§1.5)**. Three fixes, nineteen modes.
That is where the leverage is — not in per-mode polish.

---

## §7 — What "world class" means, measurably

A mode is done when **all** of these hold. No partial credit, no "mostly."

| # | Bar | How it's checked |
|---|---|---|
| 1 | Input→visible response **≤ 66 ms** median on a mid-tier phone | instrumented, not eyeballed |
| 2 | **60 fps** held for a 3-minute session; no frame > 50 ms | `engine.getFps()` log |
| 3 | Boots to playable in **≤ 3 s** on 4G, cold | Lighthouse throttled |
| 4 | Canvas ≥ **85%** of viewport height on iPhone portrait | §1.4 |
| 5 | **No T-pose** at any point | `?probe=1` clean for a full session |
| 6 | Playable **one-handed**, remappable, reduced-motion honoured | §5 |
| 7 | Every gameplay sound has a **visual equivalent** | §5 |
| 8 | Reports a `SessionResult` **and** reads PRQ before start | §3 |
| 9 | Survives **20 route changes** without a reload | §1.1 |
| 10 | Fun for 60 seconds with **no tutorial** | you play it; nobody else can score this |
| 11 | Zero external assets — procedural venue, original content | the standing constraint |
| 12 | Core logic covered by **executable tests** | `node --experimental-strip-types` |

Bar 10 is the one no agent can verify. That's your job and it's the one that
actually decides.

---

## §8 — Build order

Sequenced by leverage — what unblocks the most, earliest. Not by mode.

**Wave 0 — unblock the agents (days)**
1. Sync `nextjs_space/` into the repo (`docs/ACCESS-SETUP.md`). **Everything
   below is slower without it.**
2. Mini: install Blender, conform one clip, prove the M80 chain end to end.
3. All three agents start journals (`docs/AGENT-ACCESS-AND-PROTOCOL.md` §Rule 3).

**Wave 1 — the three fixes that touch all 19 modes (1–2 weeks)**
4. §1.1 route teardown — run the context-counter test *first*.
5. §1.2 `MotionModel` + `InputBus` v2. **Highest leverage in the product.**
6. §1.5 integrate `CameraStandoff`; re-check the whole of M69 landed.
7. §1.4 mobile canvas container chain.

**Wave 2 — make it FEL, not a game collection (2–3 weeks)**
8. §3 PRQ as an input: `core/DDA.ts`, unified weight table, HUD meter.
9. §2 mocap for `idle_stand`, `run`, `walk`, strafes — every mode at once.
10. Route the six finished modes (§6.3). Cheapest win available.
11. §5 accessibility in `ModeHarness`/`InputBus`: remapping, reduced motion,
    captions, assist slider. Before polish, not after.

**Wave 3 — depth (ongoing)**
12. §4 Phase A ghosts — needs the deterministic fixed timestep, which also
    makes every bug reproducible.
13. Per-mode differentiators from §6.2, in PRQ-weight order: football 1.5,
    karate 1.4, 3v3 1.3.
14. `dunk` mocap + vertical-gated tiers — the flagship.
15. `irl` — highest risk, highest differentiation. Nothing else in the market
    closes the loop from a real jump to a game stat.

**Wave 4 — the bar**
16. Every mode against all 12 criteria in §7. Ship nothing that fails 1–9.

---

## §9 — Open questions I could not answer

Stated so they get answered rather than assumed:

1. **Is movement camera-relative?** (§1.2i) Possibly the largest single factor
   in "I don't feel in control," and unanswerable without the app source.
2. **Did all of M69 land, or only part?** `groundSnap` works, `CameraStandoff`
   shows no evidence of running. If batches land partially, that changes how
   every future batch should be verified.
3. **What backend is actually live?** `backend/` in this repo may not be what
   Abacus serves. §3 and §4 both depend on the answer.
4. **Is there a WebSocket layer?** Determines whether §4 Phase B is a week or
   a month.
5. **Which Babylon version?** `LoadAssetContainerAsync` moved between 7 and 8;
   M80 assumes 8.
6. **Should the 48 Brain Brawl questions be ported?** 8 of them reference real
   companies and public figures. Factual trivia is legally distinct from asset
   or likeness use, but it's a brand decision, not a legal one, and it's yours.
