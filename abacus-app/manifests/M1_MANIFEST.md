# M1 — Double-Entry Ledger Foundation (export for Elijahbonds/Final-Evolution-Lab)

All paths are relative to `nextjs_space/`.

## New files
- lib/ledger.ts            Double-entry engine: accounts, postTransaction (balanced, idempotent, non-negative guard), balance derivation, escrow support, postLc() LC funnel.
- scripts/ledger-backfill.ts   Mirrors existing CreditLedger history onto the ledger (idempotent).
- scripts/ledger-invariants.ts Daily invariant job (I1-I5); exits non-zero on violation.
- scripts/ledger-tests.ts      9 parity/invariant tests (rolled-back txns; never touches real data).

## Modified files
- prisma/schema.prisma     +LedgerCurrency, +LedgerAccountType enums; +LedgerAccount, +LedgerTransaction, +LedgerPosting models (ADDITIVE — no existing model changed).
- lib/economy.ts           awardCredits() + purchaseCard() now route through postLc().
- lib/profile-service.ts   welcome grant routes through postLc().
- app/api/signup/route.ts  welcome grant routes through postLc().
- app/api/education/complete/route.ts  interactive tx -> postLc().
- app/api/sessions/route.ts            interactive tx -> postLc().
- app/api/shop/purchase/route.ts       interactive tx -> postLc().
- scripts/seed.ts          seed grant routes through postLc().

## Run commands (from nextjs_space/)
    yarn prisma db push            # apply additive schema
    yarn tsx scripts/ledger-backfill.ts    # one-time migration of history
    yarn tsx scripts/ledger-tests.ts       # 9/9 must pass
    yarn tsx scripts/ledger-invariants.ts  # must print OK

## Invariants proven
  I1 global SUM(postings)=0   I2 every txn balanced   I3 non-EXTERNAL balances >= 0
  I4 escrow held == open-match total (0 until M4)   I5 USER_WALLET:LC == SUM(CreditLedger.amount) per user
