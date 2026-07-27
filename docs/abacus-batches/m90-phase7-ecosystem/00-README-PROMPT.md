# M90 — Phase 7 of 10: ecosystem

Depends on M83 (`Rng`, replay hashes), M89 (`CreatorLoop`), M76 (`CardBridge`).
**98 tests pass by execution.**

Not re-shipped: `CardBridge` and its one-hop `royaltiesFor()` (M76, 38 tests),
`economy_engine.py`, `marketplace_service.py`.

---

## §1 — A SCORE IS BELIEVED IN PROPORTION TO THE EVIDENCE

`session_receipt.py` says:

> *"Economy fields are recomputed server-side; the client never supplies
> rewards."*

**That is true, and it is not the same as integrity.** The client never
supplies XP or shards — but it does supply `score`, `outcome`, `combo_count`,
`duration_seconds` and `completed`. The server recomputes rewards *from those*.

```
POST /api/games/session {"score": 999999, "outcome": "win"}
```

is a fully-formed, correctly-authenticated, server-computed reward. **Nothing
in the pipeline asks whether that score was possible.**

For XP that's a leaderboard problem. For **Cash Dunk Arena**, which pays real
prize pools, it's the whole product.

### The policy

M83 already gave us the tool: a recorded match is inputs plus a seed, and a
server that replays them gets the same answer or catches a lie. `SimLoop`
already stamps a `finalHash`. This is the policy layer on top.

| Trust | Evidence | XP | Shards/PRQ | Leaderboard | Ranked | **Cash** |
|---|---|:-:|:-:|:-:|:-:|:-:|
| `unverified` | a bare claim | ✅ | — | — | — | — |
| `plausible` | within the mode's envelope | ✅ | ✅ | — | — | — |
| `attested` | replay attached, internally consistent | ✅ | ✅ | ✅ | ✅ | — |
| `resimulated` | **the server re-ran it and matched** | ✅ | ✅ | ✅ | ✅ | ✅ |

Two properties worth stating:

- **An unverified claim still earns XP.** Refusing to score an ordinary
  player's ordinary game would be absurd. It simply can't win money.
- **There is no client path to `resimulated`.** The highest trust in the system
  cannot be *claimed* — only earned by someone else doing the work. A test
  asserts a client cannot reach it by asserting anything.

A hash mismatch is the most serious result in the file: it drops straight to
`unverified` and says *"The server replayed this match and got a different
result. The claim is false."*

### Plausibility is a bug detector, not a security boundary

A determined cheat submits a plausible score. What the envelope really catches
is **our own bugs** — a scoring change that makes 40,000 points reachable in a
30-second dunk run shows up here first. That's why exceeding it is a *flag*
rather than a rejection, and why the flags are specific enough for a human to
review.

### Cash Arena launches narrow, on purpose

`CASH_ELIGIBLE_MODES` is the eight modes where a replay is an *exact*
reproduction — the same set M83's `GHOST_FIDELITY` rates `'exact'`. 1v1 and
karate are excluded not because they're unfair but because verification is
harder there. **Money should follow verification rather than lead it.**

---

## §2 — XP HAS NOWHERE TO GO

`economy_engine.py` computes XP per session. `constants.py` has the min, cap
and divisor. **Nothing consumes it.** No level curve, no season, no objectives,
no reward track — so `FEL-VISION.md` describes a Season Pass ticking in the
background that has no implementation on either side.

A per-session reward with no destination is a scoreboard. The destination is
what turns twenty-five modes into a reason to open the app on a Tuesday.

`Progression.ts` is built on three rules, each enforced rather than stated:

**1. Nothing behind the paywall affects gameplay.** `assertNotPayToWin()`
throws on `stat_boost`, `multiplier`, `unlock_mode`, `advantage` — **on the
free track too**, because the rule is about gameplay, not money. Same guard as
`CreatorLoop.assertCosmetic`, same reason: the moment money buys advantage,
ranked play and the Cash Arena are both compromised.

**2. Objectives point at modes you have *not* played.** A daily aimed at your
habit is a tax on it. Most players will otherwise see a fifth of a twenty-five
mode product, and a daily is the cheapest tour available. Seeded, so client and
server agree on today without a round trip.

**3. A season must be completable.** `seasonFeasibility()` makes it checkable:
a committed player clears the track inside 90 days, a casual one gets most of
the way. If the full track ever needs more days than the season lasts, **the
track is an advertisement rather than a reward** and the constants are wrong.

Two smaller calls: the free lane is **never blank for more than 3 tiers** (a
gap of ten is a paywall wearing a progress bar), and buying premium mid-season
**grants retroactively** — paying forward only punishes the player who tried
the game first, who is exactly the one you most want to convert.

### A curve bug the tests caught

My first level curve made **level 50 cost 50× level 1** — the quadratic term
swamped everything and turned the back half into a wall only the people who
least need motivating ever climb. Now ~11×, with tests asserting *both* bounds:
under 15× (not a wall) and over 8× (still a gradient).

---

## §3 — ONE SECURITY NOTE, STATED ACCURATELY

`firebase_verify.py` decodes tokens **without verifying the signature** when
`environment != "production"`. I checked the production path: it fetches
Google's certs and verifies properly. **This is a legitimate emulator
affordance, not a vulnerability.**

What's worth knowing is *how it fails*. The gate is a string comparison against
`"production"`. If `environment` is unset, typo'd, or set to `"prod"`, the app
**silently accepts unsigned tokens** — anyone can authenticate as anyone. It's
a fail-open default on the most security-critical check in the system.

Not a bug today. One config typo from total auth bypass. A `startup_check` that
refuses to boot when the deployed environment isn't recognised would close it,
and that's a one-function change I'd rather flag than make blind.

---

## FILES

| File | Goes where |
|---|---|
| `files/core/ReceiptIntegrity.ts` | `core/` |
| `files/core/Progression.ts` | `core/` |
| `files/tests/ecosystem_test.ts` | `tests/` — 98 tests |

## PREREQUISITES

| Module | From | Used for |
|---|---|---|
| `Rng` | M83 | seeded objectives |
| `Replay` / `SimLoop` | M83 | the replay and `finalHash` a receipt carries |
| `CreatorLoop` | M89 | the cosmetic-only rule this extends |
| `CardBridge` | M76 | one-hop royalties — **not re-shipped** |

## WIRING

1. **Client:** attach `sim.finish()`'s replay header to the session receipt —
   seed, `totalTicks`, `dt`, `finalHash`, score.
2. **Server:** call `assessReceipt(claim)` before `economy_engine.compute_session`.
   Gate each reward on `verdict.payout`. **This is the change that makes the
   ecosystem trustworthy** — everything else in the file is arithmetic.
3. **Server, for ranked and cash:** re-run the replay through the same
   deterministic sim, then `assessReceipt(claim, serverHash)`. This needs the
   sim to exist server-side, which is Phase 8's real work.
4. **Progression:** persist `totalXp`, `seasonXp`, `premium`, `recentModes`.
   `nextMilestone()` drives the hub bar — one thing, not a dashboard.
5. **Objectives:** seed the RNG from the UTC date so client and server agree.

## ACCEPTANCE

1. Tests: **98 passed**.
2. POST a receipt claiming 999999 in dunk: XP only, flagged, no shards.
3. POST an honest receipt with no replay: shards and PRQ, no leaderboard.
4. POST with a replay, server re-simulates and matches: full eligibility.
5. Tamper with one input and re-submit: hash mismatch, claim rejected as false.
6. Attempt a cash entry on 1v1: refused with a reason, at any trust level.
7. Play a season as a casual player for 90 days: you don't finish, and you can
   see how far you got.

## LIMITS

- **The server cannot re-simulate anything yet.** `assessReceipt` accepts a
  `serverHash` and does the right thing with it; producing that hash means
  running FEL's deterministic sim in Python or Node on the backend. **Until
  that exists, no receipt can reach `resimulated` and Cash Arena cannot pay
  out.** That is Phase 8 and it is the largest remaining piece of the product.
- **`MODE_BOUNDS` numbers are estimates.** I have never watched a real session
  in most of these modes. They should be re-derived from a week of real
  telemetry — set them from data, not from me.
- **`CreatorLoop` still has no persistence.** Loadouts and libraries need a
  server-side store and an authority; the schemas aren't written.
- **No purchase flow, no receipt validation with Apple/Google, no refunds.**
  Premium is modelled as a boolean.
- Not type-checked against the live source. `docs/ACCESS-SETUP.md`.
