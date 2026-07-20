# M33 — CASH DUNK ARENA · Compete for Money vs Ghosts, Judged by AI

Copy this document into Abacus with every file in `files/`. This is a
**real-money skill competition** feature — the compliance section is not
optional; several items are launch blockers.

---

## PROMPT FOR ABACUS

Build the Cash Dunk Arena: entry-fee dunk contests where players compete
head-to-head against the **recorded ghosts of other competitors**, scored by
**AI judges**, for real-money prize pools. Two surfaces, one platform:

1. **IN-GAME ARENA** — deterministic dunk contest (same seed = same wind/rim/
   conditions for every entrant). Your run records as a ghost (input+transform
   stream); you dunk SIDE-BY-SIDE against your opponent's ghost rendered as a
   translucent shadow. AI judges score both runs from telemetry.
2. **IRL PROVING GROUND (testing real athletic ability)** — film a real dunk;
   the existing client-side pose pipeline (M17) extracts keypoints; AI judges
   score REAL athleticism: jump height, hang time, execution, style. Same
   contest/payout rails.

## COMPLIANCE — LAUNCH BLOCKERS (skill-contest model, Skillz-style)
- **This is a SKILL competition, never gambling:** outcomes must be 100%
  determined by player performance. Deterministic seeds, identical conditions
  per contest, zero chance elements in scoring. The `aiJudges` core score is a
  pure function of the run data (auditable, replayable); persona flavor is
  commentary ONLY, never score-affecting beyond the declared ±bounds.
- **Geo-gating required:** cash contests blocked where paid skill contests are
  restricted (maintain the state/country list server-side in `GEO_RULES`; start
  conservative, expand with counsel sign-off). Free-entry versions of every
  contest remain available everywhere (also strengthens the skill-contest
  posture).
- **18+ with verification** for any cash entry (Stripe Identity seam included).
- **Separate money rails:** entry fees and prizes are USD via Stripe (Checkout
  in, **Connect payouts** out) — NEVER shards/coins. Virtual currency stays
  non-redeemable ("no cash value" in ToS must remain true or the whole economy
  reclassifies).
- **Anti-cheat:** results are server-validated — the submitted ghost replays
  deterministically server-side to reproduce the claimed score; mismatch =
  rejected entry + flag. IRL: keypoint physics sanity checks (M17 bounds) +
  human review queue above prize thresholds.
- **Responsible play:** deposit caps, self-exclusion, and per-week entry
  limits in `arenaContracts.ts` — enforced server-side.
- **Dispute window:** payouts release after a 24 h review window; disputes
  freeze the pool, founder/mod resolves.

## FILES
| File | Purpose |
|---|---|
| `files/shared/arenaContracts.ts` | Contest/entry/ghost/judge/payout types, geo rules, limits, rake |
| `files/server/cashArenaApi.ts` | Contest lifecycle: create/join (Stripe entry), matching, server-side score verification, pool split, Connect payout seam, disputes |
| `files/server/aiJudges.ts` | Deterministic 3-judge scoring (technique/difficulty/style) from telemetry or IRL keypoints + commentary seam (M19 LLM route) |
| `files/client/DunkArenaScreen.tsx` | Arena UI: contests, entry flow, vs-ghost match, results + payout status |
| `files/irl/irlDunkJudging.ts` | IRL video → keypoints (reuses M17 extractor) → athletic metrics → judge input |

## WIRING
1. **Entry fees:** reuse M25 Stripe Checkout with product `arena_entry_{id}`
   (metadata carries contestId); the webhook confirms entry (idempotent, same
   event-id ledger as shard packs). **Payouts:** bind `PayoutService` to Stripe
   Connect transfers (Express accounts for competitors — onboarding seam
   included). Rake = `PLATFORM_RAKE` (10%) of each pool, declared in the UI.
2. **Ghost dunk-off:** reuse the M32 ghost format + M27 DunkMode. Render the
   opponent ghost as a 40%-alpha tinted spawn (`spawnNpc` + transform playback)
   running beside the live player. Same seed applied via contest config.
3. **AI judges:** `scoreRun()` is the deterministic core; judge personas
   (Silk, Doc, Prime) add bounded flavor and LLM commentary through the M19
   chat route (new persona configs included in `aiJudges.ts`).
4. **IRL:** capture flow = M17 `ScanCaptureScreen` in `dunk` activity mode;
   `irlDunkJudging.judgeIrlRun(frames, heightCm)` produces the same
   `JudgeScorecard` shape as in-game — one leaderboard schema, two surfaces.
5. Arena entry point: TRIUMPH ARENA card on the hub expands to include
   "CASH ARENA" (geo/age-gated) alongside the existing LC duels.

## ACCEPTANCE
1. Free contest end-to-end: enter → dunk vs ghost (shadow visibly replaying
   beside you) → three judge cards with scores + one-line commentary → 
   leaderboard updates.
2. Cash contest (test mode): Stripe entry → ledger entry → play → server
   re-verification reproduces the score (log both) → pool = entries − 10% rake
   → payout recorded through the Connect seam after the 24 h window.
3. Tamper test: submit a hand-edited ghost score → server replay mismatch →
   entry rejected + account flagged.
4. Geo/age: restricted-region account sees free contests only; unverified
   account cannot pay a cash entry.
5. IRL: one real dunk video → keypoints only uploaded → judge scorecard with
   measured jump height/hang time → appears on the IRL leaderboard.
6. Self-exclusion + weekly entry cap enforced server-side (attempt #cap+1 → 429).
