# M18 — FEL LIVE · Streaming Platform Tab

Copy this document into Abacus together with every file in `files/`.

---

## PROMPT FOR ABACUS

Add **LIVE** as a new tab in the bottom navigation (Home · Modes · **Live** · Coach ·
Story · Profile) using the files in this package. FEL LIVE is the platform's
streaming surface with three jobs:

1. **Streaming shows & classes** — scheduled live sessions and replays:
   Pilates, dance, and the flagship **Elijah Bonds** programming — HIIT, Regressed &
   Progressed Plyometrics and Isometrics, Corrective Self-Myofascial Release
   Strategies, and Biomechanical Education with practical applications.
2. **Advertising inventory** — sellable ad slots (banner, pre-roll, sponsored
   schedule cards) for outside advertisers, PLUS house ads for FEL's own services,
   products, and in-game items (shard packs, creator cards, workout plans).
3. **Creator highlights** — a spotlight rail that features creators, their cards,
   their clips, and their upcoming streams.

Integrate with the existing meta layer: shard tips and class passes debit/credit
through the server-authoritative wallet (10-phase Phase 6); watching live earns
season XP at a capped drip rate. Video delivery is standard HLS — any provider that
outputs an HLS URL works (Mux, Cloudflare Stream, IVS); the player is
provider-agnostic. Prove completion with a recording: open Live tab → watch the
featured stream with an ad slot visible → tip shards (ledger entry) → buy a class
pass → browse schedule + creator spotlight.

## FILES

| File | Purpose |
|---|---|
| `files/shared/streamContracts.ts` | Types: channels, streams, schedule, ad slots, passes, tips, spotlights |
| `files/shared/programGuide.ts` | Seed schedule: Elijah Bonds classes, Pilates, dance + house-ad inventory |
| `files/server/streamApi.ts` | API: guide, live state, ad delivery, tips, class-pass purchase, watch-XP drip |
| `files/client/LiveTab.tsx` | The tab: live-now hero, schedule rail, creator spotlight, ad banner |
| `files/client/StreamPlayer.tsx` | HLS player: gating, tips, ad overlay/pre-roll, live badge, viewer count |

## INTEGRATION POINTS
1. Bottom nav: insert Live tab center position; badge dot when a stream is live.
2. Wallet: `tip` and `buyClassPass` call EconomyService; NO client-side balances.
3. XP: `watchHeartbeat` grants capped season XP (anti-idle: requires player
   interaction every 5 min).
4. HLS: set `hlsUrlResolver` to the chosen provider's playback URL; `hls.js` for
   non-Safari (new dependency), native HLS on Safari.
5. Creator spotlight pulls from the existing creator-card system (M17/Phase 7).

## MONETIZATION MODEL (as implemented)
- **Ad slots:** `banner_live_tab`, `preroll`, `schedule_sponsor` — each slot serves
  a weighted rotation from `adInventory`; house ads fill unsold slots so the surface
  never looks empty. Click-through + impression counters per creative (the sales
  deck needs those numbers).
- **Class passes:** free streams vs. pass-gated classes (shards). Pass = per-class
  or monthly all-access.
- **Tips:** shard tips during live streams with on-screen shoutout event.

## COMPLIANCE — BLOCKING
- Ads must be visibly labeled "AD" / "SPONSORED"; house promotions labeled "FEL".
- No third-party ad tracking SDKs — first-party impression counting only.
- Class content carries the training disclaimer; SMR/corrective content adds
  "gentle pressure, never on joints/spine; stop if painful."
- If minors can access streams, chat is OFF by default for <18 accounts.
- Recorded classes note "AI features may be present" only where true; live video of
  real instructors needs no AI badge.

## ACCEPTANCE
1. Live tab in bottom nav with live badge; hero shows the live/next stream.
2. Player: plays HLS, pre-roll ad slot fires with AD label, banner slot on the tab,
   sponsored card in schedule — impressions logged server-side.
3. Tip flow: shards debited via ledger, shoutout renders.
4. Class pass: gated stream blocked → purchase → unblocked; ledger entry exists.
5. Schedule shows the seeded program guide including all five Elijah Bonds class
   types, Pilates, and dance, with correct local times.
6. Watch XP drips and caps; idle viewers stop earning.
