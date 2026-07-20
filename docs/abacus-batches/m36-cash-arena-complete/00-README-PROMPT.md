# M36 — CASH DUNK ARENA · COMPLETE BUILD (drag-and-drop)

Copy this document into Abacus with every file in `files/` **plus the five M33
files** (`shared/arenaContracts.ts`, `server/aiJudges.ts`, `server/cashArenaApi.ts`,
`irl/irlDunkJudging.ts`, `client/DunkArenaScreen.tsx`). M33 defined the rules;
M36 is everything that was still missing to actually run it: money rails,
routes, storage, the deterministic simulator, ghosts, the contest game mode,
and the remaining screens. Together they are the whole feature.

---

## PROMPT FOR ABACUS

Build the Cash Dunk Arena end to end. All business logic is in these files —
your job is placement, wiring the 4 marked seams, env vars, and deploy.

### WHAT THIS FEATURE IS
An online dunking platform: players enter contests (free or cash), perform a
seeded 3-attempt dunk run against the **ghost** of a real competitor, get
scored by three AI judges on deterministic athletic metrics, and top-3 split
the prize pool (USD via Stripe Connect). IRL contests score real filmed dunks
from on-device pose data. **Skill competition, never gambling**: outcomes are a
pure function of measured performance; the same run always scores the same.

### FILES IN THIS BATCH
| File | What it is |
|---|---|
| `shared/deterministicSim.ts` | THE dunk simulator + input-stream codec. Client records inputs and scores itself with this function; server re-runs the SAME function to verify (anti-cheat). Constants are frozen — never tune them while a contest is open. |
| `server/arenaStore.ts` | Db impl (Mongo via existing client, in-memory when `MOCK_DB=1`), idempotent weekly contest seeding (daily free, Friday cash, weekly IRL), ghost storage + deterministic rival-ghost picker. |
| `server/stripeRails.ts` | Stripe Checkout for entry fees, webhook with per-event idempotency + auto-refund when confirm fails, Stripe Identity 18+ verification, Connect Express onboarding + idempotent transfers. |
| `server/arenaRoutes.ts` | Every endpoint behind one catch-all route (contests, checkout, enter, submit, rival-ghost, irl-submit, results, payouts, safety, admin sweep). Route-file snippets are in the header comment. |
| `game/GhostSystem.ts` | GhostRecorder (10 Hz, ~6 KB/run) + GhostPlayback (translucent cyan shadow re-running the rival's actual attempt beside you). |
| `game/ArenaDunkMode.ts` | Contest mode: 3 seeded attempts, every input recorded, best run auto-selected, rival ghost runs alongside, ends with `{telemetry, ghostData}` for submission. Reuses the M35 TouchOverlay dunk verbs. |
| `client/ArenaResultsScreen.tsx` | Leaderboard, placement banner, payout status, Connect onboarding button, WATCH (rival ghost replay). |
| `client/CashSafetyScreen.tsx` | Responsible-play hub: age verification, live weekly limit meters, self-exclusion with confirm. Link from Profile AND from every cash contest card. |
| `irl/IrlUploadScreen.tsx` | Film/pick a dunk → MediaPipe pose extraction on device → keypoints-only upload → scorecard (or human-review notice). |

### WIRING — exactly 4 seams, each marked `TODO(abacus)` or in comments
1. **Auth**: `getUserId()` in `arenaRoutes.ts` → the app's real session lookup.
2. **Mongo**: pass the existing connected db into `getArenaDb(mongoDb)` (or set
   nothing and it runs in-memory for `MOCK_DB=1` smoke tests).
3. **CharacterLibrary**: expose `meshes` on SpawnedCharacter and `currentClip`
   on CharacterAnimator (one line each — noted at the bottom of GhostSystem.ts).
4. **modeVerbs**: `MODE_VERBS.dunk_arena = MODE_VERBS.dunk;`

Route files (copy from the `arenaRoutes.ts` header comment):
- `app/api/arena/[[...path]]/route.ts` → `handleArena`
- `app/api/stripe/arena-webhook/route.ts` → `handleStripeWebhook` (RAW body!)

Screen flow: DunkArenaScreen (M33) `onPlayContest` → fetch `rival-ghost` →
run `makeArenaDunkMode({seed: contest.seed, rivalGhostData})` in the M26
harness → on end POST `/{id}/submit` with `{telemetry, ghostData}` → show the
returned scorecard → ArenaResultsScreen.

### ENV (Abacus secrets — NEVER hardcode, NEVER commit)
`STRIPE_SECRET_KEY` · `STRIPE_WEBHOOK_SECRET` (from the webhook endpoint you
register for `checkout.session.completed` + `identity.verification_session.verified`)
· `APP_URL` · `ADMIN_KEY` (random string). Scheduler: hit
`POST /api/arena/admin/sweep` with header `x-admin-key: $ADMIN_KEY` every 30
min — it settles locked contests and releases payouts after the 24 h review
window automatically.

### COMPLIANCE (unchanged from M33 — these are launch-blocking)
Cash entry requires: allowed region (GEO_RULES), Stripe Identity 18+, under
weekly entry/deposit limits, no active self-exclusion. Free contests work for
everyone everywhere. USD rails stay fully separate from shards/coins. Rake
(10%) and payout split (60/30/10) are declared in the UI. Cash IRL runs are
held for human review before verification. Use Stripe TEST keys until counsel
signs off on go-live.

## ACCEPTANCE
1. **Free loop e2e (MOCK_DB=1)**: enter Daily Open → 3 seeded attempts with
   the single M35 overlay → best run submits → scorecard renders → results
   board shows the run. Second account sees the first account's ghost running
   beside them.
2. **Determinism**: submit a run, then replay its `inputStream` through
   `simulateDunkRun` server-side — identical telemetry (this is the existing
   `verifyRun` path; log proof). A tampered `apexHeight` gets 422.
3. **Cash loop (Stripe test mode)**: checkout → webhook confirms entry (event
   replayed twice = one entry) → contest locks → sweep settles → after review
   window sweep releases → test Connect account receives the transfer. A
   checkout for a full contest auto-refunds.
4. **Gates**: unverified user gets the verify-age flow; blocked-state region
   gets 451 with the friendly notice; self-excluded user is blocked from cash
   but not free; limit meters move on CashSafetyScreen.
5. **IRL**: upload a test clip → progress → keypoints-only POST (network tab
   shows no video upload) → scorecard or review notice renders.
6. M31 smoke test stays green; no secrets in the repo (run the scanner).
