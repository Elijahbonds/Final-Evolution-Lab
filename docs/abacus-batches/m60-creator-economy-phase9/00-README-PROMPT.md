# M60 — PHASE 9: creator economy ($30 All-Access Pass, book/art/music marketplace + KDP export, food-scan rewards)

Copy this into Abacus with every file in `files/`. Prerequisites: M25
(Stripe rails — subscriptionApi follows its exact injection pattern), M57
(Studio tracks for music listings). All files NEW.

---

## PROMPT FOR ABACUS

### 1. THE ALL-ACCESS PASS — $29.99/month
`shared/allAccessPass.ts` is the single source of truth (mirrors
shardPacks.ts): SKU, benefits list, `hasAllAccess()` for every gate.
Benefits: all premium mode content, a 1200◈ monthly stipend
(renewal-safe, granted once per billing period), all Music Academy kits,
marketplace seller fee 10%→5%, early Story chapters, profile badge.
`server/subscriptionApi.ts` is the server half in M25's framework-agnostic
style: Stripe SUBSCRIPTION checkout, webhook-driven entitlement (the only
writer of PassState), idempotent event handling. One dashboard step: create
the recurring Price with lookup_key `fel_all_access_monthly` and add the
three subscription events to the existing webhook. Age/geo purchase gates
from the M33/M36 cash rules apply.

### 2. THE MARKETPLACE — books, audiobooks, art, music for Shards
- `marketplace/Marketplace.ts` — listings, Shards purchases through the
  economy seam, seller fees (pass-aware), ownership, receipts. Storage is
  localStorage with SYNC SEAMs (same pattern as the Studio library). UGC
  note: listings should enter the `pending_review` flow CreatorCardTypes
  (M28) already defines.
- **KDP, the honest version**: Amazon KDP has NO public API — every KDP
  book is uploaded via the owner's dashboard. So "double publishing" is
  built the only correct way: sell in FEL for Shards now, and one click
  exports a clean manuscript + a step-by-step KDP checklist for the
  creator's own Amazon upload. Nothing pretends to publish to Amazon.
- `marketplace/AuthorStudio.ts` — the authoring engine with the requested
  20-chapter bestseller structure encoded as a real template (3 acts,
  per-chapter beat jobs). `draftOutline()` genuinely generates a coherent
  20-chapter skeleton for any topic (100◈); chapter SCAFFOLDS (40◈) give
  a structured writing frame — the marked CELL SEAM upgrades scaffolds to
  real LLM prose with the same signature when Cell/Nexus is wired. No fake
  prose is ever passed off as finished writing.
- `marketplace/MarketplaceHub.tsx` — SHOP (browse/buy/read/listen/view),
  SELL (art = image, audiobook = audio file, music = a Studio track id),
  AUTHOR DESK (outline → chapter editor → list the book → KDP export),
  MY SHELF (everything owned, playable/readable in place).

### 3. FOOD SCAN — coins/XP/Shards for eating toward YOUR goal
- `nutrition/NutritionScore.ts` — the honest design, stated in-code:
  nothing pretends to see the photo. Snap the plate, tap what's on it
  (8 chips, 5 seconds), and a TRANSPARENT rubric scores it RELATIVE TO
  YOUR GOAL — the same plate scores differently on a cut vs. a bulk, and
  post-training protein is rewarded when you trained today. Rewards:
  coins = score/2, XP = score, +10◈ only on 80+ plates. Anti-farm: 3
  scored scans/day, Shards on the first 2 only, server-enforceable at the
  SYNC SEAM. The marked VISION SEAM is where a real Cell vision call
  pre-fills the tags (user confirms — confirm-not-trust).
- `nutrition/FoodScan.tsx` — camera-first UI (mobile `capture`), photo
  proof, tag chips, score reveal with the reward breakdown, economy seam.

### FILES
| File | What it does |
|---|---|
| `files/shared/allAccessPass.ts` | Pass SKU + benefits + `hasAllAccess()` gates. |
| `files/server/subscriptionApi.ts` | Stripe subscription checkout + webhook entitlement + renewal-safe stipend. |
| `files/marketplace/Marketplace.ts` | Listings/purchases/fees + KDP export package. |
| `files/marketplace/AuthorStudio.ts` | 20-chapter template + outline generator + chapter scaffolds (CELL SEAM). |
| `files/marketplace/MarketplaceHub.tsx` | The storefront: SHOP / SELL / AUTHOR DESK / MY SHELF. |
| `files/nutrition/NutritionScore.ts` | Goal-relative scoring rubric + daily caps. |
| `files/nutrition/FoodScan.tsx` | The scan-your-plate UI. |

### WIRING
1. Routes/cards: `/pass` (render benefits from PASS_BENEFITS + checkout via
   createPassCheckout), `/market` → MarketplaceHub, `/scan` → FoodScan (or
   surface FoodScan inside the existing fitness/coach area).
2. Server: mount createPassCheckout/handlePassWebhook/passStatus alongside
   M25's stripeApi with the same Db/Economy services; do the one Stripe
   dashboard step above.
3. Pass real props: `profile`, `pass` (from passStatus), `spendShards`,
   `playStudioTrack` (bridge to StudioLibrary), FoodScan's `goal`/
   `trainedToday` from the user's profile + session history, `onReward`
   into the real wallet.
4. Gates: check `hasAllAccess()` at premium-content gates and pass
   `sellerHasPass` truthfully when the profile is wired.
5. Marketplace UGC → the existing `pending_review` moderation flow.

## ACCEPTANCE
1. Pass: checkout completes in Stripe test mode → PassState flips active
   via webhook only; stipend grants exactly once per period including on
   renewal; canceling flips `cancelAtPeriodEnd` and access survives until
   period end.
2. Marketplace: list art/audiobook/music; buy from a second profile with
   Shards; fee math shows 10% (or 5% for a pass seller) in the receipt;
   owned items read/play/view in MY SHELF.
3. Author Desk: outline generates 20 structured chapters for any topic;
   scaffold fills an empty chapter with the writing frame (never fake
   prose); a 3+-chapter book lists and its KDP EXPORT downloads the
   manuscript + checklist.
4. Food scan: same plate scores differently on cut vs. bulk; trained-today
   protein bonus applies; 4th scan of the day earns zero; 80+ plate pays
   Shards only twice a day.
