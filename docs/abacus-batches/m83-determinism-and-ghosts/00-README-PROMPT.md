# M83 — determinism, and ghost multiplayer with no server

Wave 3 of `docs/BLUEPRINT.md`. Depends on M48 (`PlayerSlot`) and M81.

**110 tests pass by execution**, including a full record-and-replay round trip
that asserts a match reproduces bit-identically.

**One real desync found and fixed.** See §2.

---

## §1 — Why determinism comes before everything else in Wave 3

Every mode currently updates like this:

```ts
const dt = engine.getDeltaTime() / 1000;
if (phase === 'playing') def.update(ctx, dt);
```

`dt` is whatever the last frame happened to take. Physics integrated against a
variable `dt` gives a different answer every run, which means:

- **A ghost cannot be exact.** Replay the same inputs at a different frame rate
  and you get a different match. The drift is worst during busy frames — i.e.
  exactly when it matters.
- **No netcode is possible.** Lockstep and rollback both require two machines
  to agree on state given the same inputs.
- **No bug is reproducible.** "It happened once" stays "it happened once".
- **Jump height depends on frame rate.** A 120 Hz phone and a throttled 30 Hz
  browser are not playing the same game.
- **Cash Arena cannot be audited.** A prize-pool match whose outcome depends on
  unrecorded randomness is not verifiable by anyone, including you. That is a
  product blocker, not a code-quality preference.

`core/FixedStep.ts` accumulates real time and consumes it in fixed 60 Hz
slices. `core/Rng.ts` replaces `Math.random()` with a seeded stream whose
entire state is one number.

---

## §2 — THE DESYNC THIS FOUND

The first version of `FixedStep` failed its own frame-rate test:

```
2 seconds at 60 Hz  → 120 ticks
2 seconds at 30 Hz  → 120 ticks
2 seconds at 144 Hz → 119 ticks     ← ✗
```

`1/144` is not exactly representable in binary floating point. 288 additions
accumulate to `1.999999999999994` — **six femtoseconds short**. The 120th tick
never fires.

A player on a 144 Hz display falls one tick behind a 60 Hz player every two
seconds. **About 30 ticks a minute.** Any ghost recorded on one and replayed on
the other drifts apart permanently, and the symptom appears nowhere near the
cause.

Fixed with a relative epsilon on the tick comparison, measured rather than
guessed: ~17 nanoseconds, far above the accumulated float error and far below
any real quantity of time.

**This is the argument for the whole batch in one bug.** It is invisible to
inspection, invisible on the machine you develop on, and it silently breaks the
feature that depends on it.

---

## §3 — Ghosts: multiplayer Phase A, no infrastructure

`core/PlayerSlot.ts` (M48) already made this cheap. Every body on the court is
driven by a `ControlSource` returning an `Intent` each tick, and no game logic
reads the input bus directly. **A recorded opponent is just another
ControlSource.** That decision, made long before it was needed, is why
`GhostSource` is 200 lines instead of a rewrite.

A recording is **inputs, not positions.** Replaying positions gives you a
video, and you cannot play against a video. Replaying inputs re-runs the actual
match — which is what makes a ghost a real opponent, and what lets a server
re-simulate a prize-pool result and audit it against the stamped final hash.

**Run-length encoding, with one rule that matters:** input is overwhelmingly
repetitive, so a three-minute match compresses from ~170 KB to a few KB. But
`action`, `pass` and `steal` are one-tick **edges** and are never merged —
merging them would turn one shot into ninety. There is a test.

### The honesty layer

A ghost **cannot react to you.** In a rally sport that is nearly
indistinguishable from a live opponent. In 1v1 basketball, a ghost that drives
left because the *original* defender was on its right looks broken the moment
you stand on its left.

So `GHOST_FIDELITY` rates every mode rather than letting each one discover this
the hard way:

| | modes | ship a ghost? |
|---|---|---|
| **exact** | dunk, skate, snowboard, surf, golf, baseball, gymnastics, irl… | yes — replay *is* the performance |
| **good** | tennis, volleyball, soccer, football, brain_brawl, who_scene_it… | yes — exchanges are discrete |
| **poor** | onevone, threevthree, karate, karate-vs, mixedcombat | **no** — wait for real netcode |

Unknown modes default to `poor`. Shipping a ghost into a mode that cannot
support one is how a feature gets a reputation it never recovers from.

### Refusal over silent desync

`GhostSource.from()` validates before playing and returns `null` with a reason
if the recording was made in a different mode, at a different tick rate, in an
older format, without a seed, or truncated. **Playing a ghost that cannot
reproduce is worse than playing none** — the player would lose to an opponent
that never existed and have no way to know.

---

## §4 — `verifyDeterminism()`, the tool that pays for the batch

Re-simulates a recorded match and compares state hashes tick by tick. When they
differ it names the tick:

```
NON-DETERMINISTIC: diverged at tick 123 of 400 (2.05s in). Look for
Math.random(), Date.now(), Object key iteration order, or physics reading a
variable dt. Rng.detectRawRandom() will find the first of those.
```

`Rng.detectRawRandom()` monkey-patches `Math.random` in dev and reports every
remaining call site with a count. Runtime detection, not grep — it finds calls
inside bundled helpers and dependencies too.

There is a test asserting the checker can actually **fail**. A green check that
cannot go red is worse than no check.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/FixedStep.ts` | `core/` |
| `files/core/Rng.ts` | `core/` |
| `files/core/Replay.ts` | `core/` |
| `files/core/GhostSource.ts` | `core/` |
| `files/core/SimLoop.ts` | `core/` |
| `files/tests/determinism_test.ts` | `tests/` — 110 tests |

Also added to the repo (not this batch): **`tools/ts_resolve.mjs`**. Batch
source uses the app's extensionless import convention, which Node's ESM
resolver rejects — this registers a resolve hook so tests can execute the same
files the app bundles. Three previous batches worked around that mismatch by
bending the *code*; the right place to fix a resolver problem is the resolver.

```
node --experimental-strip-types --import ./tools/ts_resolve.mjs tests/determinism_test.ts
```

## WIRING

`SimLoop` is deliberately **additive** — M81 already replaced `ModeHarness`,
and a second competing copy would make the two batches order-dependent. It is
also a concrete object rather than a README paragraph, because that is the
delivery mode that has already failed once here: M69's `CameraStandoff` was
specified perfectly and never integrated while `groundSnap` from the same batch
did land.

**1. In the harness render loop**, replace the variable-dt update:

```ts
// before
engine.runRenderLoop(() => {
  const dt = engine.getDeltaTime() / 1000;
  if (phase === 'playing') def.update(ctx, dt);
  scene.render();
});

// after
const sim = new SimLoop({ modeId: def.modeId, playerPRQ: dda.playerPRQ, record: isRanked });
engine.runRenderLoop(() => {
  if (phase === 'playing') {
    sim.frame(engine.getDeltaTime() / 1000,
      (dt) => def.update(ctx, dt),          // dt is ALWAYS 1/60 here
      () => localSource.poll(0));           // recorded per tick
  }
  scene.render();
});
```

**2. Replace `Math.random()` in gameplay with `rng().next()`.** Anything that
affects the match: judge variance, wave composition, AI decisions, quiz
shuffles. Cosmetic-only randomness (particle jitter) can stay — it does not
change the result. Use `rng().fork('ai')` per system so adding a crowd effect
later cannot change every AI decision and invalidate existing recordings.

**3. On match end:** `const replay = sim.finish(score, outcome)`. Store it
against the leaderboard row. **4. To play a ghost:**
`GhostSource.from(parseReplay(json), modeId, FIXED_DT)` into the opponent slot,
and restore `ghost.recordedPRQ` into DDA or the AI behaves differently and the
ghost desyncs.

## ACCEPTANCE

1. `node --experimental-strip-types --import ./tools/ts_resolve.mjs tests/determinism_test.ts`
   → **110 passed**.
2. Play a mode on a 60 Hz and a 144 Hz display; `sim.tick` after 60 seconds
   differs by **zero**.
3. Background the tab for a minute and return: the simulation does not
   fast-forward, and `[FEL-SIM] frame stall` is logged.
4. Record a dunk run, replay it as a ghost: the ghost scores exactly what the
   recording says it scored.
5. `verifyDeterminism()` on that recording reports deterministic. **If it does
   not, the mode still has a `Math.random()` — this is the expected first
   result, not a failure of the batch.**
6. Load a ghost recorded in another mode: refused with a reason, and the match
   still starts.
7. A 3-minute recording serialises to under ~10 KB.

## LIMITS

- **No mode has been migrated.** Everything here is the machinery; the modes
  still run on variable `dt` and `Math.random()` until someone does step 2.
  Expect `verifyDeterminism()` to fail on first run for every mode — that is
  the tool working.
- **Babylon's own systems are not deterministic** and are not made so here.
  Particles, its animation blending, and any built-in physics remain
  frame-rate dependent. Keep them out of anything that decides a result.
- **`stateHash` quantises to 1/1000** before hashing, so genuine divergence
  smaller than that is invisible. That is a deliberate trade — an alarm that
  trips on the last bits of a float is one nobody keeps listening to.
- **Ghosts are not netcode.** No live opponent, no matchmaking, no rollback.
  Phase B and C in `docs/BLUEPRINT.md` §4 still need a transport, and this
  repo still cannot see the backend that would provide one.
- Not run against a real Babylon scene, for the standing reason: this repo has
  no copy of the app.
