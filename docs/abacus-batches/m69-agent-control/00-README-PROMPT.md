# M69 — AGENT CONTROL PLANE + the four bugs a real playtest found

Two things in one batch, because the second is what made the first
necessary.

**Part A** gives AI agents a real control surface over Nexus/FEL so they can
build, play and deploy end to end.
**Part B** fixes four defects I found by finally driving the live game
properly — including one in my own smoke test that had been hiding the other
three.

---

## THE VERIFICATION LOOP — WHAT ABACUS CLAIMED vs WHAT IS TRUE

I re-ran the loop against the live build. Abacus's integration report holds
up on every point I could check independently:

| Claim | Verified how | Result |
|---|---|---|
| SkinningGuard v2 deployed | live console, karate | ✅ **4 false stalls → 1** |
| readyMarker live | `#fel-ready[data-mode][data-state]` in DOM | ✅ all 5 modes, plus per-mode markers |
| `import.meta.env` → `process.env` | app boots, no ReferenceError | ✅ correct call — that's a Vite-ism in a Next.js app |
| Deployed to both hosts | HTTP 200 on both | ✅ |
| tsc clean / 65 pages | — | ⚠️ **not independently verifiable from here** — I have no repo access to the Next.js app. Reported as their result, not mine. |
| walletCore deliberately NOT wired | — | ✅ **right call.** The app already has a Prisma-backed server-authoritative economy. A second wallet forks a core. |

Two corrections to the picture:

1. **`nexusllm.abacusai.app` is not a second product.** It serves the *same
   app and same build* as `finalevolution.abacusai.app` — identical title and
   landing markup. It is a domain alias. Worth knowing before anyone
   playtests it expecting Nexus-the-LLM-product. Sessions are host-scoped, so
   a session captured on one host will not authenticate the other.
2. **The anime/backdrop/court work is live and looks right.** The ocean-wave
   court, the M59 grade and the M61 skyline all render as intended.

---

## PART B — THE FOUR BUGS

### 1. My own smoke test was passing on a loading screen ⚠️ worst of the four

Every mode opens on a **"TAP TO START" overlay**. My smoke test pressed `j`,
waited 3.5s and screenshotted. The canvas exists *behind* the overlay, so the
check was satisfied and reported **PASS** — for a game that had never
started.

That is why karate "went green" after M68: not because the last stall was
fixed, but because the test stopped getting far enough in to see it. **A
canvas is not a running game.** The same class of error as the auth wall in
M68, one layer deeper.

`smoke.mjs` v3 now clicks the gate by accessible text, then **waits for
`#fel-ready[data-state='playing']`** and fails if it never arrives. Re-run
against the same build that had been "passing":

```
before (v2):  dunk PASS · karate PASS · onevone PASS      ← all three false
after  (v3):  dunk PASS · karate FAIL · onevone PASS      ← karate is really red
              [FEL-FRAME] hero off-screen at {X:1.52 Z:3.10} cam {X:-0.09 Y:1.47 Z:1.55}
```

### 2. Characters stand in the arms-out bind pose — E25, half-fixed

M64's solver **works**, and says so every spawn:
`[FEL-ANIM] restPose solved for 4 bone(s): LeftArm, RightArm, LeftForeArm, RightForeArm`

But it bakes the pose into the **`idle_stand` clip**. The 1v1 screenshot
shows the near character with arms down and the far one in full bind pose —
same scene, same frame. Anything not playing `idle_stand` (defenders holding
position, AI between behaviours) has un-keyed arms, and Babylon leaves an
un-keyed bone where it last was: the bind pose.

**Fix:** `restPoseApply.ts` writes the solved pose onto the **skeleton**, so
it is the resting state for every character in every state. Clips that key
the arms still override it, exactly as they should.

### 3. Characters are sunk into the court

Visible in Dunk and 1v1: cut off at the hip, no feet, no contact shadow.
`[FEL-SPAWN] dunk: OK (32 meshes, hero at {X: 0 Y: 0 Z: 8.5})` — `Y: 0` is
the tell. Spawn puts the **root** at 0 assuming the origin is at the feet; on
this rig it is at the hips. M64's ocean court made it obvious by replacing
the flat floor with a surface you can visibly be *under*.

**Fix:** `groundSnap.ts` **measures** the character's real world-space lowest
point (with `applySkeleton: true`, so a crouch isn't measured as a stand) and
moves the root by the difference. No magic constant — correct for any rig,
any scale, any pose, which matters because M65's avatar builder is about to
produce exactly that variety. Refuses corrections over 3m rather than flinging
a character out of the venue.

### 4. Karate camera collapses onto the hero

`cam` sits **0.63 units** from the hero horizontally. The `fight` preset asks
for 4.2 and `MIN_SAFE_DISTANCE` is 1.8, so both are being overridden.

**Cause — order of operations.** In `follow()`:
```ts
const finalPos = this.clampToBounds(this.resolveOcclusion(subject, desired, back));
```
`resolveOcclusion()` honours the standoff, then `clampToBounds()` runs
afterwards with no knowledge of it. Harmless in a big venue; in Shimogamo
Dojo's narrow room the bounds are barely wider than the standoff, so the
clamp squeezes the camera onto the hero. **The last guard in the chain
silently defeats the earlier one.**

**Fix:** `CameraStandoff.ts` runs *after* the clamp so nothing can undo it.
When a room is too tight to back away in, it **gains height instead of
distance** — the bounds only constrain from below, so this is always
satisfiable and never oscillates the way pushing back against the clamp
would.

There is also a **likely double-count of the height offset** inside
`resolveOcclusion()`'s return (`dir` already carries the vertical component,
then `candidate.y - subject.y` is added again). I have **not** changed it —
it is a one-line edit in a file you have already integrated and I cannot
re-verify every preset's framing from screenshots. The corrected line is in
the file's footer; ship it separately so the two remain separable.

### 4b. Two bugs in the batch gate itself

Found by running M69 through it. Both made the gate lie, in opposite
directions:

- **Nested template literals read as truncation.** The tokenizer skipped
  `${...}` inside a template literal on the assumption that its braces
  "balance either way". They do not when a template is nested:
  ``` `a ${c ? `b ${x}` : ''} d` ``` — the inner backtick looks like the
  outer literal's terminator, and everything after it is parsed inside-out.
  `nexus_agent.mjs` was reported as a truncated paste while `node --check`
  accepted it. `${` now pushes a real brace and returns to template state
  when it closes. Verified both ways: the false positive clears, and genuine
  truncation and stray closers still fail.
- **Four directories could never pass.** `m14`, `m15`, `m16` and
  `m22-…` are historical planning documents — no `files/`, nothing to drag
  anywhere — but the missing-prompt check ran *before* the is-this-even-a-batch
  check, so the gate was permanently red on something unfixable. A gate that
  is always red teaches people to ignore it. It now classifies first and
  demands a prompt only from directories that actually ship code.

```
before:  4 error(s), 78 warning(s)   ← red since M66 introduced the gate
after:   0 error(s), 82 warning(s)   ← all 56 batches
```

---

## PART A — THE AGENT CONTROL PLANE

> *"I want Nexus to be able to be controlled by AI agents in the browser to
> build and deploy end to end."*

Bug #1 above is the argument for this. An agent driving this app today has to
guess where "TAP TO START" is, mash keys, and infer from pixels whether
anything happened — which is exactly how three modes reported PASS while one
of them was broken. Pixel-driving is not a control plane.

### `window.__NEXUS_AGENT__` — `core/AgentBridge.ts`

```js
const a = window.__NEXUS_AGENT__;
a.describe()                        // machine-readable modes + actions
await a.start()                     // clears the start gate, resolves when actually playing
await a.do('sprint', { ms: 900 })
await a.do('dunk')
a.state()                           // { modeId, state, playing, score, hero, metrics, errors }
await a.waitFor(s => s.state === 'ended', 30000)
```

It **wraps the seams that already exist** rather than inventing parallel
ones — `readyMarker` (M67) for lifecycle, `PerfMonitor` (M67) for metrics,
`ControlSource` (M48/M50) for play. It only reads and forwards; if the bridge
ever disagrees with the game, the bridge is wrong.

### `core/AgentControlSource.ts` — agents as players

Implements the **existing `ControlSource` interface**, so it is a sibling of
`LocalInputSource` and `AISource`, not a test-only side door. Agent-driven
play runs through *identical game code* to human play. It also keeps the
multiplayer story intact: an agent is simply another thing that can fill a
slot, exactly as `NetworkInputSource` will be.

Edge-triggered actions (`pass`, `steal`, `strike`) fire **exactly once**
regardless of how long they're held — a 300ms `pass` cannot become 18 passes.

### Security — control, not privilege

The bridge is **off** unless explicitly enabled (`?agent=1`). When on, every
action is one the signed-in user could already perform by tapping. It does
**not** bypass the sign-in wall, mint currency, touch the wallet, or reach
the server. Lab Credits stay earned-only behind the server-authoritative
economy, which this file has no path to.

### `tools/nexus_agent.mjs` — build and deploy, end to end

```
node tools/nexus_agent.mjs plan | verify | build | deploy | smoke | run
node tools/nexus_agent.mjs run --json      # NDJSON, one record per line
```

Every verb emits `{"event":"step","name":...,"status":"ok|failed|skipped"}`.
The human rendering is derived **from** those records, so an agent and an
operator can never be told different things.

`skipped` is a first-class result and is **never coerced to `ok`**.
`deploy` with no `NEXUS_DEPLOY_CMD` reports *skipped, nothing was deployed* —
it will not claim a success it cannot verify, and there is no invented Abacus
API call in it. `run` refuses to build or deploy on a failed verify.

> While writing this I hit the exact bug it exists to prevent: `plan` printed
> **FULLY GREEN** under a list of SKIPs, because the summary was built from a
> hardcoded array instead of the emitted statuses. Fixed, and the fix is
> commented in place.

### `tools/agent_pilot.mjs` — the reference agent

Drives the live app through the bridge the way a browser agent would, and
**falls back to synthetic input with a clear message** when the bridge isn't
deployed — so "the API isn't there yet" can never look like "the game is
broken". It runs inside `nexus_agent.mjs smoke`, so a broken bridge turns the
build red instead of being discovered later by an agent.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/AgentBridge.ts` | game source `core/` |
| `files/core/AgentControlSource.ts` | game source `core/` |
| `files/core/CameraStandoff.ts` | game source `core/` |
| `files/core/groundSnap.ts` | game source `core/` |
| `files/anim/restPoseApply.ts` | game source `anim/` |
| `files/anim/SkinningGuard.ts` | game source `anim/` — **REPLACES M68's** |
| `files/public/agent-manifest.json` | served at `/agent-manifest.json` |
| `files/tools/nexus_agent.mjs` | repo `tools/` — pipeline entry point |
| `files/tools/agent_pilot.mjs` | repo `tools/` — reference agent driver |
| `files/tools/smoke.mjs` | repo `tools/` — **REPLACES M68's** (start-gate fix) |
| `files/tools/verify_batch.mjs` | repo `tools/` — **REPLACES M66's** (two gate bugs, below) |

## WIRING

Each file's footer carries its exact call site. In short:

1. **`restPoseApply`** — `CharacterLibrary.spawn()`, right after
   `solveArmsDown(skeleton)`:
   `applyRestPoseToSkeleton(skeleton, pose);`
2. **`groundSnap`** — last step of `spawn()`: `snapToGround(rootNode, meshes, 0);`
3. **`SkinningGuard` v3** — add the 6th argument:
   `SkinningGuard.verify(scene, id, meshes, skeleton, () => animator.isPlaying, () => animator.currentFrame)`
   and add the matching `currentFrame` accessor next to the `isPlaying` one
   you already added.
4. **`CameraStandoff`** — wrap the existing line in `follow()`/`followTwo()`:
   `enforceStandoff(subject, this.clampToBounds(this.resolveOcclusion(...))).pos`
5. **`AgentBridge`** — once at boot: `installAgentBridge(MODE_REGISTRY)`;
   in `ModeHarness`, `agentBridge()?.attach({ scene, modeId, control, getScore, getHero })`
   and `agentBridge()?.detach()` on dispose.
6. **`AgentControlSource`** — in each mode that supports intent play, give
   the agent the local slot when the bridge is on (one line, shown in the
   file footer).

## ACCEPTANCE

1. `node tools/smoke.mjs --modes dunk,onevone,threevthree,karate,carnival`
   → **all five PASS, each having reached `data-state="playing"`**. A mode
   stuck at `loaded` must FAIL.
2. Stand still in any mode: **arms hang at the sides on every character**,
   hero and AI alike — not just whoever is playing `idle_stand`.
3. Every character's **feet contact the court**; no one is sunk to the hip.
   Console shows `[FEL-SPAWN] groundSnap: ... lifted Xm` once per spawn.
4. Karate, drive at the walls: **no `[FEL-FRAME] hero off-screen`**. Camera
   may sit higher in the dojo — that is the standoff guard working.
5. Karate to a KO: **no `SKINNING STALL`** on the downed fighter (playhead
   parked → held pose, correctly ignored).
6. `node tools/agent_pilot.mjs --all` → `bridge=live` and
   `state=playing|ended` for every mode.
7. `node tools/nexus_agent.mjs run --json` → parseable NDJSON; no step
   reports `ok` for something it did not actually do.

## STILL UNVERIFIED — not claimed as green

- **Swift/iOS** (1425 sources) — needs macOS + Xcode.
- **182 integration tests** — need a live backend + MongoDB.
- **tsc / 65-page Next.js build** — Abacus's result; I have no repo access to
  that app and did not re-run it.
- Everything here was verified against **software rendering** (SwiftShader).
  Frame-budget and shader-compile behaviour needs a real GPU device pass.
