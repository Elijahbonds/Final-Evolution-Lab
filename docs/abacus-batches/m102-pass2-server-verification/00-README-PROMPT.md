# M102 — Pass 2, Phase 9: a real match, re-simulated and matched

**29 tests pass by execution, and they play an actual dunk contest through
record → serialise → parse → re-simulate → verify, then tamper with each part.**

This is Phase 9's gate, met. Not with a fixture — with `DunkSim`, the same mode
M94 migrated and M101 measured as the one deployed mode making no gameplay
random calls.

---

## WHAT THE SERVER RECEIVES TODAY

Captured from the deployed build in M100:

```
POST /api/sessions        {"mode":"dunkContest","score":25,"won":false,"duration":40}
POST /api/v1/wallet/earn  {"payload":{"score":25}}   →  granted 53 coins
```

**No replay. No seed. No hash.** The server is not failing to verify — it has
nothing to verify against. A client states a number and currency is minted from
it.

## THE BUG THIS BATCH FOUND IN MY OWN M94

The very first run of the end-to-end test failed:

```
rejected: the replay carries no final hash, so there is nothing to check against
```

M94's `DunkMode` called `ModeKit.create({ modeId: 'dunk', record: true })` —
**without `captureHashes: true`.** `SimLoop.finish()` then returns a replay with
no final hash, and `verifyMatch` refuses it outright.

Every dunk replay recorded in production would have been **unverifiable while
looking perfectly well-formed**: it parses, it re-simulates, and it is refused.
Fixed in M94's source in this batch.

That is the third bug of this exact shape found in pass 2 — a system that runs,
tests clean, and does nothing — and the second one in my own work. It was only
findable by building the *other* end and running a real match through it.

## THE POLICY: THREE OUTCOMES, NOT TWO

| eligibility | cash | progress | when |
|---|:-:|:-:|---|
| `verified` | ✅ | ✅ | re-simulated and matched |
| `unverified` | ❌ | ✅ | no replay — old client, dropped connection, unmigrated mode |
| `rejected` | ❌ | ❌ | checked and contradicted, or claimed the impossible |

**`unverified` is not `rejected`, and that distinction is the whole design.** A
submission with no replay is not evidence of cheating — the overwhelming
majority are an old client or a mode that has not been migrated yet. Treating
them as fraud bans most of the player base; treating them as verified is what
happens now.

Unverified sessions keep their XP, shards and season tier, and are not eligible
for cash. That is what lets verification roll out **one mode at a time** without
taking anything away from anyone.

## THE CEILING IS NOT REDUNDANT

An unverified session still earns XP, shards and season tier — all worth real
money in this economy. So the claim is checked against M100's `scoreScale`
ceiling **before** re-simulation, because that is the only guard that applies to
the unverified majority:

```
{"modeId":"dunk","claimedScore":999999}   →  rejected, 0 awarded, no progress
{"modeId":"dunk","claimedScore":120}      →  unverified, progress kept
```

A perfect game is 120 and is not rejected; `CLAIM_TOLERANCE` leaves room for a
rounding difference so a legitimate perfect game never trips it.

## WHAT THE TESTS ACTUALLY DO

- Play a real contest with varied intents — charging, releasing, style taps, a
  rim hang — so the replay is not a run of identical frames that would verify
  trivially.
- Verify it. **Re-simulation of a full contest costs under 2 ms.**
- Then: inflate the score on the same replay (rejected, and the reason names
  the *score*, not a desync). Swap the mode id. Corrupt the JSON. Exceed the
  tick limit — refused *before* any simulation runs, in under 50 ms.
- Play a **second** match with a different seed, verify both independently, and
  check that A's replay with B's score is rejected. A verifier that passed
  everything would pass the first four tests too.

---

## FILES

| File | Goes where |
|---|---|
| `files/server/verifySession.ts` | `server/` — runs on Node |
| `files/tests/verify_session_test.ts` | `tests/` — 29 tests |

**Also modifies `m94-pass2-dunk-migration/files/modes/dunk/DunkMode.ts`** —
one line, `captureHashes: true`. If M94 has already been integrated, apply that
change or its replays are worthless.

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Replay` | M83 | `parseReplay`, the submission format |
| `FixedStep` | M83 | `FIXED_DT` and `stateHash` — the per-tick fingerprint |
| `HeadlessSim` | M91 | `verifyMatch`, `SimulatableMode` |
| `DunkSim` | M94 | the only mode that can be verified today |
| `scoreScale` | M100 | the ceiling |

## WIRING

**Run this on Node, importing the same files the client bundles. Not a port.**
M91 recorded why and it is worth repeating: this project has already paid four
times for re-implementing a rule in a second language — PRQ tables drifting up
to 57% between Swift and Python, MRI existing in Python with no producer, DDA
stranded in Swift. A ported simulation would be that same failure with money
attached.

1. Client: send `replay: serialiseReplay(kit.finish(score, outcome))` alongside
   the score. It is the existing `POST /api/sessions` with one more field.
2. Server: `verifySession(submission, { mode: DunkSim, ceiling: 120 })`.
3. Gate the wallet on `cashPayable(decision)` and progress on
   `progressPayable(decision)`.
4. Verification is pure and synchronous — no database, no clock, no network. It
   belongs in a queue worker, not the request path.

## ACCEPTANCE

1. A real dunk session submits a replay and comes back `verified`.
2. The same replay with a higher score comes back `rejected`, naming the score.
3. Every other mode comes back `unverified` and keeps its progress. **Nothing a
   player has today gets taken away by shipping this.**

## LIMITS

- **Only `dunk` can be verified.** M101 measured four other cash modes rolling
  `Math.random()` for gameplay; until those route through the seeded `Rng`,
  they can only ever be `unverified`.
- **Nothing here is deployed.** The client does not send a replay and the server
  does not ask for one. This is the missing piece between M91 and the product,
  tested end to end and integrated nowhere.
- **The ceiling is only as good as `scoreScale`.** M100 ships two cited scales
  out of twenty-five modes. Without a ceiling, an unverified claim of any size
  keeps its progress.
- **Verification proves the replay is self-consistent, not that a human played
  it.** A bot that drives the real client produces a replay that verifies
  perfectly. That is a different problem — input plausibility, timing analysis,
  device attestation — and this batch makes no claim about it.
- **Replay size is unmeasured.** A 40-second contest is 2,400 ticks run-length
  encoded; a twenty-minute session is not, and nobody has looked at the bytes on
  a mobile connection.
