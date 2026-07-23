# M62 — PHASE 10: FEL KITCHENS (ghost-kitchen subscription marketplace) + the final regression pass

Copy this into Abacus with every file in `files/`. Prerequisite: M60 (the
Stripe subscription pattern its checkout seams reference). Both files NEW.
`FINAL-REGRESSION-PASS.md` is the plan-closing checklist.

---

## PROMPT FOR ABACUS

### FEL KITCHENS — the legitimate build of the food-business idea
A two-sided, subscription-based marketplace ("like meal prep, but they
subscribe — plug into the systems in place"):
- **KITCHEN PARTNERS** list licensed commercial kitchens (city-level
  location, amenities, operator-entered certification CLAIMS labeled as
  such) with three auto-generated recurring shifts (AM prep / late-night /
  weekend) priced from their base rate — idle kitchens stay employed.
- **CHEFS** subscribe monthly to a shift (Stripe seam, lookup-key
  `fel_kitchen_{id}_{shift}` on M60's exact subscription pattern), and can
  then publish **meal-prep plans** — the marketplace's integrity rule:
  every plan must name the partner kitchen it's made in, enforced in code.
- **EATERS** subscribe weekly to a chef's plan (`fel_meal_{planId}`),
  DoorDash-meal-prep-style but recurring.
- **Compliance, never hidden**: a permanent notice states FEL is a
  marketplace facilitator; operators own licensing/permits/insurance,
  chefs own food-safety law; certification claims render as claims until
  a real ops verification process exists (seamed, never a fake checkmark).
Storage is localStorage + SYNC SEAMs (the Studio/Marketplace pattern);
payment truth belongs to Stripe webhooks exactly as M60 established.

### THE FINAL REGRESSION PASS
`FINAL-REGRESSION-PASS.md` closes the 10-phase plan: deployment order for
M51–M62, the standing KNOWN-ERRORS sweep, the human/real-device items (the
E25 skinning check above all), the credentials list, one-line acceptance
spot-checks per batch, and the honest list of what remains open (network
transport, LLM seams, streaming credentials, story-mode build). Once
everything is dropped in, I run the full live playtest audit next cycle
and verify it line by line.

### FILES
| File | What it does |
|---|---|
| `files/kitchens/KitchenMarket.ts` | Two-sided data layer: kitchens/shifts/plans/subs, Stripe + SYNC seams, kitchen-gated plan publishing, compliance text. |
| `files/kitchens/KitchenHub.tsx` | The UI: EAT / COOK / LIST A KITCHEN floors. |
| `FINAL-REGRESSION-PASS.md` | The plan-closing checklist. |

### WIRING
1. Route/card: `/kitchens` → KitchenHub. Pass `profile` and a
   `startCheckout(priceLookupKey, description)` bridge to the M60 Stripe
   layer (absent = simulated + logged, for UI review before rails).
2. Stripe: shift/meal Prices are created per-listing — in production
   create them via the API at listing time (server-side), or start with a
   few fixed tiers; the lookup-key convention is in-code.
3. Ops: stand up the certification-verification queue before any
   "verified" badge ships; until then claims render as claims.
4. Work through FINAL-REGRESSION-PASS.md top to bottom after deploying.

## ACCEPTANCE
1. List a kitchen → 3 shifts appear priced off the base rate; subscribing
   marks the shift TAKEN and it can't be double-booked.
2. Publishing a plan WITHOUT a kitchen subscription is refused with the
   pointer to COOK; with one, the plan goes live naming its kitchen.
3. Subscribing to a plan increments its subscriber count and shows
   SUBSCRIBED ✓ for that user.
4. The compliance notice is visible on every floor; certification text
   always reads as operator claims.
5. FINAL-REGRESSION-PASS.md executed after full deployment; findings come
   back for the next live-audit cycle.
