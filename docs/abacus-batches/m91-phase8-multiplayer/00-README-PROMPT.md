# M91 — Phase 8 of 10: multiplayer & arena

Depends on M83 (`FixedStep`, `Rng`, `Replay`), M90 (`ReceiptIntegrity`).
**64 tests pass by execution**, including a full record → re-simulate → verify
round trip and the same replay tampered with and caught.

**This closes the gate M90 left open.**

---

## §1 — THE ARCHITECTURAL DECISION

M90's trust policy says only a match the **server** re-ran can win real money.
Nothing could produce that hash. There were two ways to fix it:

**A.** Port the game logic to Python alongside the backend.
**B.** Run **the same TypeScript the client runs**, headless, on Node.

It has to be B, and this project has already paid for that lesson four times:

- PRQ weight tables drifted between Swift and Python — five modes wrong, one by
  **57%** (M82)
- The MRI formula existed in Python with **no producer anywhere** (M89)
- DDA lived in Swift and never reached the web (M81)

Every one was the same failure: **one rule, two implementations, silent
divergence.** A ported simulation would be that failure *with money attached* —
if the server's physics disagrees with the client's by one float, every honest
player fails verification and every payout is wrong.

**The verifier and the game must be the same code.**

### What a mode must do to be verifiable

Separate its **simulation** from its **rendering**. That's the only
requirement, and it's a good idea regardless: a mode whose logic runs without a
scene can be tested, replayed, ghosted and verified. One that can't is a mode
where nobody can ever prove anything.

`SimulatableMode<S>` is four methods. If it needs a `Scene`, it isn't
simulatable and its results can never be trusted for money.

---

## §2 — A TRAP THAT WOULD HAVE REJECTED EVERY HONEST PLAYER

The test suite failed on its first run with a hash mismatch, and the cause is
worth the whole batch:

**`ReplayRecorder` quantises analog inputs to 1/127** (M83, so recordings are
small and device-independent). If the client **simulates with the raw float**
and **records the quantised one**, the server re-runs slightly different inputs
and gets a different hash.

The failure mode is the worst kind available:

- it looks **exactly like cheating**
- it hits **every honest player**
- it would surface in production as *"Cash Arena rejects everyone"*

`asRecorded(intent)` rounds an intent through the replay format so a mode
simulates precisely what will be recorded. **Quantise first, then simulate and
record the same value.**

This is the fifth constant-shaped bug in eight phases, and the first one that
would have cost money rather than fun.

---

## §3 — VERIFICATION

`verifyMatch()` returns the answer M90 has been waiting for. Three things it
does that a naive version wouldn't:

- **Checks the score as well as the hash.** A hash proves the simulation ran
  identically; comparing the score catches a mode whose scoring isn't part of
  its fingerprint — which would otherwise verify a match while paying out the
  wrong number.
- **Never throws.** A malformed replay, a mode that panics, a runaway loop —
  all return `ok: false` with a reason. A verification endpoint crashable by a
  crafted payload is worse than no verification.
- **Has a time budget.** Servers do.

`proveDeterministic()` runs the same replay three times in one process. If
*that* diverges, the mode has non-determinism inside it and no server anywhere
will verify it. **This should gate entry into `CASH_ELIGIBLE_MODES` —
determinism is demonstrated, not assumed.**

`verificationCost()` says what it costs at scale: a three-minute match verifies
in ~200 ms, so one core clears ~5/second. Worth knowing before promising to
verify every ranked game rather than discovering it under load.

---

## §4 — ROLLBACK FALLS OUT OF THE SAME MACHINERY

Re-running a match from its inputs to **check** it, and re-running the last few
frames because a remote input arrived **late**, are the same operation at
different scales.

That's why the phase order mattered more than it looked: M83's fixed timestep
made determinism possible, M90 needed it for money, and Phase 8 gets
multiplayer largely for free. **Netcode first would have needed all the same
work and delivered none of the verification.**

**Rollback, not delay-based.** Delay adds the full round trip to *every* input —
at 80 ms ping that's 80 ms of lag on every press, over the **66 ms budget
`MotionModel` set in M81**. The game would fail its own responsiveness bar
before a packet was ever dropped. Rollback keeps local input at zero latency
and pays only on misprediction.

Three decisions worth naming:

- **Prediction repeats the last input.** Looks lazy, is correct — human input
  is highly autocorrelated at 60 Hz. A cleverer predictor is wrong in more
  interesting ways and produces *larger* corrections when it misses.
- **Edges are never repeated.** Repeating a button press turns one shot into
  sixty.
- **Beyond the buffer, inputs are dropped — and the session says so.**
  `matchmakingVerdict()` **refuses** a 250 ms match rather than degrading it. A
  match that silently drops inputs lies to both players, and refusing with a
  reason is kinder and far easier to support.

**Transport-agnostic on purpose.** This file never opens a socket — the
standing constraint against netcode written for backend infrastructure this
repo can't see still holds, and it costs nothing, because rollback's hard part
is the state bookkeeping.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/HeadlessSim.ts` | `core/` |
| `files/core/Rollback.ts` | `core/` |
| `files/tests/multiplayer_test.ts` | `tests/` — 64 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `FixedStep` | M83 | the tick, and `stateHash` |
| `Rng` | M83 | seeded simulation |
| `Replay` | M83 | the recording, and the quantisation `asRecorded` mirrors |
| `PlayerSlot` | M48 | the `Intent` shape |
| `ReceiptIntegrity` | M90 | consumes `serverHash` |

## WIRING

1. **Refactor one mode to `SimulatableMode`.** `dunk` first — it's the
   flagship, it's cash-eligible, and its logic is the most separable. Until one
   mode proves the shape, this is machinery with nothing plugged in.
2. **In the client, call `asRecorded()` before simulating.** One line, and
   without it nothing verifies.
3. **Stand up a Node verification service** that imports the same `core/`
   modules the client bundles. Not a port. The same files.
4. **On receipt:** `verifyMatch()` → `assessReceipt(claim, result.serverHash)`.
5. **Before adding a mode to `CASH_ELIGIBLE_MODES`,** run
   `proveDeterministic()` against a real recording in CI.
6. **For live play:** `RollbackSession` with your transport feeding
   `receiveRemote()`. Gate matchmaking on `matchmakingVerdict()`.

## ACCEPTANCE

1. Tests: **64 passed**.
2. Record a real dunk run, re-simulate server-side: hashes match, receipt
   reaches `resimulated`, cash eligibility granted.
3. Inflate the score on the same replay: rejected, and the reason distinguishes
   a score lie from a desync.
4. Flip one recorded input: hash mismatch.
5. `proveDeterministic` on each cash-eligible mode: all deterministic. **Expect
   failures on the first run — that's the tool working.**
6. Two clients at 60 ms: local input feels instant, rollbacks are rare.
7. One client at 300 ms: matchmaking refuses with a reason.

## LIMITS

- **No mode implements `SimulatableMode` yet.** The contract, verifier and
  rollback are built and tested against a toy mode. The real work is
  refactoring 19 modes to separate simulation from rendering, and **that is
  substantial** — most of them currently mutate Babylon meshes directly inside
  their update loop.
- **`RollbackSession` is 2-player.** 3v3 needs N-player, which is the same
  algorithm with wider input tuples and considerably more state per snapshot.
- **No transport, no matchmaking service, no lobby.** Deliberate, per the
  standing constraint.
- **Snapshot cost is untested at scale.** 8 frames of a real basketball state
  is much larger than 8 frames of a toy. If cloning is expensive, rollback
  needs delta snapshots — a real piece of work this doesn't attempt.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
