# Court Carnival — Design Doc

**Status:** draft for Elijah's design sign-off
**Mode id:** `carnival_board`
**Route:** `/nexus/carnival` (add `?recording=1&seed=<n>` for solo recording)

---

## 1. The hybrid concept

Court Carnival is a **party meta-game wrapped around short arena mini-games** —
Mario-Party-style board on the outside, Pac-Man-Fever-style twitch play on the
inside. Between mini-games, players spin a spinner and move around a festival
**Carnival Board**; landing on spaces earns/loses coins and periodically drops
everyone into a fast 15–60s mini-game. Mini-game performance converts into
**tokens**, and coins + tokens decide the winner.

The point of the hybrid is pacing and inclusivity: the board gives everyone a
breather, social swings, and comeback hope, while the mini-games are where skill
expresses itself. It also gives us a clean **content slot machine** — new
mini-games and creator-skinned arenas plug into the same loop without touching
the board.

## 2. Core loop

```
create match ──► [ BOARD TURN ] ──► spin (seeded) ──► move + apply space
                     ▲                                        │
                     │                       land on MINIGAME │ or every Nth turn
                     │                                        ▼
                     └────── award tokens ◄── resolve ◄── [ MINI-GAME 15–60s ]
                                (with catch-up multiplier)
   ... 6–8 rounds ...  ──►  standings + highlight reel
```

* **N players:** 2–4. Absent seats are **AI-filled** (deterministic, beatable).
* **Board:** ~24 ring spaces, typed `PRIZE / MINIGAME / TRAP / SHOP /
  CREATOR_STAND`. Every 4th space is a guaranteed `MINIGAME` for predictable
  pacing; the rest are seeded weighted-random.
* **Rounds:** 6–8 mini-game rounds per match (`DEFAULT_ROUNDS = 8`). A mini-game
  triggers on landing on `MINIGAME` **or** every `MINIGAME_EVERY_NTH = 3` turns.
* **Currency:** `coins` (board economy) + `tokens` (mini-game payout). Standings
  metric = `coins + tokens`.

## 3. Determinism (the load-bearing property)

**Nothing that affects an authoritative outcome uses `Math.random` or the
wall-clock.** Every random draw derives from `match.seed`:

* Board layout, spinner rolls, mini-game instances, and AI inputs all come from
  `random.Random(blake2b(seed | tag | tag…))` sub-seeds (see
  `backend/lib/carnival.py :: _sub_seed`).
* **Spinner:** `spinner_roll(seed, turn_index)` — same match, same turn ⇒ same
  roll. Replayable.
* Mini-games are resolved **from submitted, tick-/timestamp-stamped inputs**, so
  `same seed + same inputs ⇒ identical scores`. Verified by
  `backend/tests/test_carnival.py` across 3 seeds per game.
* Replays export as `{metadata, events}` and re-validate through
  `backend/tools/replay_validator.py` (extended to dispatch `carnival` replays:
  it re-derives the board + spinner rolls and re-resolves every mini-game from
  its echoed instance + inputs).

> Client note: the React client (`frontend/src/lib/carnivalEngine.js`) mirrors
> the engines with a splitmix64 PRNG for smooth local play and RECORDING_LOCAL.
> It is deterministic *in itself* (stable visuals per seed) but is **not**
> byte-identical to Python's RNG — the **backend remains authoritative** for
> networked matches. This is a deliberate demo-scoping choice; see §8 for the
> "single authoritative engine" follow-up.

## 4. The three mini-games

### Maze Chase (Pac-Man-Fever core)
* 10×10 seeded maze (≈18% interior walls, connectivity-guarded), pellets on open
  cells, **2–3 seeded power pellets**.
* Grid-tick movement (40 ticks ≈ 15–40s). A **deterministic greedy chaser**
  minimises Manhattan distance; a power pellet makes it *frightened* (flees, and
  can be eaten for a bonus) for 6 ticks.
* **Score** = pellets ×10 + power ×50 + survival ×2/tick.
* Server resolves purely from `pid -> [{tick, move}]`. Fully playable client-side
  with arrows/WASD + touch swipe, local prediction of own movement.

### Target Burst (buzzer-style)
* 12 seeded targets, each with a position + a **900 ms open window** on a spread
  schedule.
* Players submit `{latency_ms, taps:[{target_id, ts_ms}]}`; each tap is
  **latency-corrected** (`ts − latency`) then checked against the window. Closer
  to window centre ⇒ larger accuracy bonus.
* **Score** = 100/hit + up to 50 accuracy bonus. Latency normalization mirrors the
  existing buzzer/judge-offset patterns.

### Rhythm Tap
* Seeded beatmap: BPM ∈ [90, 140], a quarter-note pulse with seeded eighth-note
  flourishes (24 base beats + flourishes).
* Client records hit timestamps; server latency-normalizes and matches each tap
  to the nearest unused beat: **perfect** (≤45 ms, 100 pts) / **good** (≤110 ms,
  50 pts) / **miss**.

## 5. Score normalization (comparability)

Each mini-game reports a raw score and the **theoretical max raw** for its seeded
instance. We map to `0..100` tokens:

```
frac  = clamp(raw / raw_max, 0, 1)
tokens = round(frac * 100)      # NORMALIZED_MAX = 100
```

So a maze blowout and a rhythm blowout both cap at 100 before catch-up — every
game contributes on the same scale to the board economy. (`normalize_scores`.)

## 6. Catch-up / comeback design

Applied to a player's normalized tokens **after** each mini-game:

```
gap  = max(0, leader_total - player_total)
mult = 1.0 + min(0.5, 0.02 * gap)        # +2% per point of deficit, capped +50%
```

* The leader always gets exactly `1.0` (no bonus).
* Monotonic — a bigger deficit never yields a smaller bonus.
* Capped at +50% so a dominant lead usually holds but comebacks are live. In the
  recorded demo you can watch "×1.08 comeback!" / "×1.02 comeback!" tags fire in
  the highlight reel.

**Tunable knobs for sign-off:** the `0.02` slope and `0.5` cap. Current values
feel gentle; if playtests want more chaos, raise the cap toward `0.75`.

## 7. Creator Card tie-ins (seam notes only — not built)

* **Creator-skinned maze arenas:** the `CREATOR_STAND` space and
  `maze_chase_build` are the seams. A creator card would supply a wall/pellet
  theme + palette; the maze *layout stays seeded* so determinism is unaffected —
  only cosmetics change.
* **Creator sample audio for Rhythm Tap:** `rhythm_tap_build` already emits a
  BPM + beatmap; a creator card would attach an audio stem keyed to that BPM.
  Scoring is unchanged (timing windows), so no determinism risk.
* Landing on `CREATOR_STAND` is where a "collect this creator's card" hook lands.

## 8. Camera / audio / polish roadmap

* **Audio:** 3 CC0 synthesized stings ship now (transition / minigame_start /
  reward). Next: per-mini-game music beds, creator stems for Rhythm Tap, a win
  fanfare.
* **Camera:** board uses a static top-down ring; roadmap adds a 400–600 ms
  push-in on the active token before a spin and a whip-pan into the mini-game.
* **Single authoritative engine:** collapse the JS mirror and Python engine onto
  one shared deterministic core (WASM or a shared spec) so client replays are
  byte-identical to server replays and networked play needs no reconciliation.
* **Netcode:** wire the mini-games onto the existing WS snapshot netcode for real
  multiplayer (today's demo is local/solo-authoritative).

## 9. Future mini-game slots

The loop takes any engine that returns `{raw, raw_max}` from seeded inputs:

* **Hold-the-Flag** — occupy a seeded zone under contest; score = ticks held.
* **King-of-the-Hill** — shrinking seeded safe-zone; score = survival + centre time.
* **Short Race** — seeded obstacle lane, tick-stamped inputs; score = finish time.

Each is a `build_*` / `resolve_*` pair + a dispatch-table entry + a React view.

---

## What needs Elijah's eyes (design sign-off)

1. **Catch-up curve** (`0.02` slope, `+50%` cap) — right amount of comeback?
2. **Board pacing** — mini-game every 4th space *and* every 3rd turn: too many?
3. **Round count** — 8 rounds ≈ 3–4 min recorded. Shorter for investor clips?
4. **Client vs server engine** — accept the demo-scoped JS mirror now, or invest
   in the single authoritative engine before wider multiplayer?
5. **Creator tie-in placement** — is `CREATOR_STAND` the right hook, or should
   creator skins be a pre-match loadout instead of a board space?
