# M2 — Track A Revenue (Stripe Integration)

## Changed files (this milestone)

### New files
- `lib/stripe.ts` — Stripe SDK singleton + product/price config (FEL_PRO, STUDIO_CREATOR subs + Chrome Visor cosmetic SKU + 15% marketplace take rate)
- `lib/stripe-helpers.ts` — Ledger bridge: subscription/cosmetic/marketplace/payout/ladder-prize posting functions (all with enforceNonNegative:false for revenue accounts)
- `app/api/stripe/checkout/route.ts` — Checkout session creation (subscriptions, cosmetics, marketplace)
- `app/api/stripe/webhook/route.ts` — Webhook handler: checkout.session.completed, invoice.paid/failed, customer.subscription.updated/deleted. Replay-safe via event.id idempotency key.
- `app/api/stripe/portal/route.ts` — Customer portal redirect
- `app/api/stripe/payout/route.ts` — Creator payout (idempotent, ledger-backed, one per day)
- `app/api/marketplace/purchase/route.ts` — Buyer purchase history
- `app/api/ladder/enter/route.ts` — Free weekly ladder entry/leaderboard
- `app/api/ladder/results/route.ts` — Admin finalize + LC prize distribution
- `app/api/account/subscription/route.ts` — User entitlement check
- `scripts/m2-tests.ts` — 9 tests covering all M2 flows

### Modified files
- `prisma/schema.prisma` — Added: StripeCustomer, Subscription, Order, PayoutRequest, MarketplaceListing, MarketplacePurchase, LadderSeason, LadderEntry models + SubscriptionProduct, SubscriptionStatus, OrderType, OrderStatus, PayoutStatus enums + User relations

## ENV keys required (not yet set — paste test-mode values)
- `STRIPE_SECRET_KEY` (sk_test_...)
- `STRIPE_PUBLISHABLE_KEY` (pk_test_...)
- `STRIPE_WEBHOOK_SECRET` (whsec_...)

## Tests (9/9 pass)
- T1: Subscription payment → PLATFORM_REVENUE
- T2: Cosmetic purchase → PLATFORM_REVENUE  
- T3: Marketplace sale → platform + creator split
- T4: Payout CREATOR_ACCRUAL → EXTERNAL
- T5: Payout idempotency
- T6: Webhook replay safety
- T7: Ladder prize → USER_WALLET:LC
- T8: Ladder prize idempotency
- T9: Subscription cancel → status CANCELED

## Acceptance criteria status
- A1 (FEL Pro sub): ✅ Code-complete (checkout + webhook entitlements + portal + cancel-safe)
- A2 (Marketplace purchase→unlock→creator accrual): ✅ Code-complete
- A3 (Payout settlement idempotent): ✅ Code-complete + tested
- A4 (Webhook replay evidence): ✅ T6 proves same event.id = duplicate=true, 1 ledger row
- Cosmetic SKU (Chrome Visor $4.99): ✅ Code-complete
- Weekly ladder (free entry, LC prizes): ✅ Code-complete + tested
