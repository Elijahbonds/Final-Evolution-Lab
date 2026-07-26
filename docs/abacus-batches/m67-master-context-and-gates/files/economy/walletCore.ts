// walletCore — the SERVER-AUTHORITATIVE wallet, ledger and ownership store.
//
// The compliance register names this as a hard gate: "must exist before any
// payment or ownership." It is the prerequisite for the marketplace (M60),
// the All-Access pass (M60), Creator Card ownership, and the Music Academy's
// Shard spends (M57) — all of which currently call a `spendShards` seam with
// nothing authoritative behind it. This is that authority.
//
// THE RULES, ENCODED
//   1. The SERVER owns balances. The client may read; it may never assert.
//      Every mutation goes through here and lands in the ledger.
//   2. LAB CREDITS are EARNED-ONLY. There is no code path that grants LC for
//      money — that is deliberate and load-bearing: an earned-only currency
//      stays outside gambling/real-money-transfer regimes. SHARDS are the
//      purchasable currency (M25 Stripe rails).
//   3. Every mutation is IDEMPOTENT via a caller-supplied key. A retried
//      request credits once. This is what makes webhook retries safe.
//   4. Nothing is deleted. The ledger is append-only; balances are derived
//      state that must always equal the sum of their entries. `audit()`
//      proves it.
//
// Framework-agnostic (same injected-Db pattern as M25/M60's stripeApi) so it
// drops into whatever server layer exists.

export type Currency = 'LC' | 'SHARDS';

export type LedgerReason =
  // ── LC: earned only ──
  | 'session_reward' | 'lesson_complete' | 'streak_bonus' | 'daily_login'
  | 'food_scan' | 'achievement' | 'admin_grant'
  // ── SHARDS ──
  | 'purchase' | 'pass_stipend' | 'refund'
  | 'spend_cosmetic' | 'spend_kit' | 'spend_market' | 'spend_generation'
  // ── marketplace ──
  | 'market_sale_net' | 'market_fee';

/** Reasons that may CREDIT Lab Credits. Anything else is rejected — this
 *  set is the enforcement point for "LC is earned-only". */
const LC_EARN_REASONS = new Set<LedgerReason>([
  'session_reward', 'lesson_complete', 'streak_bonus', 'daily_login',
  'food_scan', 'achievement', 'admin_grant',
]);

export interface LedgerEntry {
  id: string;                  // == idempotency key
  userId: string;
  currency: Currency;
  delta: number;               // signed; credits positive, spends negative
  reason: LedgerReason;
  meta?: Record<string, unknown>;
  at: number;
}

export interface Balances { LC: number; SHARDS: number }

export interface OwnershipGrant {
  userId: string;
  itemId: string;
  grantedAt: number;
  via: 'purchase' | 'reward' | 'pass' | 'admin';
  ledgerId: string | null;     // the spend that paid for it, when applicable
}

export interface Db {
  get<T>(collection: string, id: string): Promise<T | null>;
  set(collection: string, id: string, doc: unknown): Promise<void>;
  /** All docs in a collection whose `userId` matches. */
  queryByUser<T>(collection: string, userId: string): Promise<T[]>;
}

const C = { balances: 'wallet_balances', ledger: 'wallet_ledger', owned: 'wallet_ownership' };

export class InsufficientFunds extends Error {
  // NOTE: written WITHOUT TypeScript parameter properties on purpose —
  // strip-only toolchains (Node's native --experimental-strip-types among
  // them) reject `constructor(public x: T)`. Explicit fields work everywhere.
  readonly currency: Currency;
  readonly required: number;
  readonly available: number;
  constructor(currency: Currency, required: number, available: number) {
    super(`insufficient ${currency}: need ${required}, have ${available}`);
    this.name = 'InsufficientFunds';
    this.currency = currency;
    this.required = required;
    this.available = available;
  }
}
export class InvalidGrant extends Error {}

export class Wallet {
  private db: Db;
  constructor(db: Db) { this.db = db; }

  async balances(userId: string): Promise<Balances> {
    return (await this.db.get<Balances>(C.balances, userId)) ?? { LC: 0, SHARDS: 0 };
  }

  /**
   * Apply a signed change. `idempotencyKey` MUST be stable for a given
   * real-world event (e.g. `stripe_${eventId}`, `session_${sessionId}_reward`)
   * — a replay then returns the existing entry instead of double-crediting.
   */
  async apply(
    userId: string, currency: Currency, delta: number,
    reason: LedgerReason, idempotencyKey: string, meta?: Record<string, unknown>,
  ): Promise<LedgerEntry> {
    if (!Number.isFinite(delta) || delta === 0) throw new InvalidGrant('delta must be a non-zero finite number');
    if (!idempotencyKey) throw new InvalidGrant('idempotencyKey is required');

    const existing = await this.db.get<LedgerEntry>(C.ledger, idempotencyKey);
    if (existing) return existing;                       // replay — already applied

    // LC is earned-only: no purchase path, ever.
    if (currency === 'LC' && delta > 0 && !LC_EARN_REASONS.has(reason)) {
      throw new InvalidGrant(
        `Lab Credits are earned-only — "${reason}" cannot credit LC. `
        + 'Use SHARDS for anything purchasable.',
      );
    }

    const bal = await this.balances(userId);
    const next = bal[currency] + delta;
    if (next < 0) throw new InsufficientFunds(currency, -delta, bal[currency]);

    const entry: LedgerEntry = { id: idempotencyKey, userId, currency, delta, reason, meta, at: Date.now() };
    // ledger first: a crash between the two leaves an entry without a balance
    // update, which `audit()` detects and `reconcile()` repairs. The reverse
    // order would silently lose money.
    await this.db.set(C.ledger, idempotencyKey, entry);
    await this.db.set(C.balances, userId, { ...bal, [currency]: next });
    return entry;
  }

  earn(userId: string, amount: number, reason: LedgerReason, key: string, meta?: Record<string, unknown>): Promise<LedgerEntry> {
    if (amount <= 0) throw new InvalidGrant('earn amount must be positive');
    return this.apply(userId, 'LC', amount, reason, key, meta);
  }

  spendShards(userId: string, amount: number, reason: LedgerReason, key: string, meta?: Record<string, unknown>): Promise<LedgerEntry> {
    if (amount <= 0) throw new InvalidGrant('spend amount must be positive');
    return this.apply(userId, 'SHARDS', -amount, reason, key, meta);
  }

  grantShards(userId: string, amount: number, reason: LedgerReason, key: string, meta?: Record<string, unknown>): Promise<LedgerEntry> {
    if (amount <= 0) throw new InvalidGrant('grant amount must be positive');
    return this.apply(userId, 'SHARDS', amount, reason, key, meta);
  }

  // ── ownership ──────────────────────────────────────────────────────────
  async owns(userId: string, itemId: string): Promise<boolean> {
    return (await this.db.get<OwnershipGrant>(C.owned, `${userId}:${itemId}`)) !== null;
  }
  async ownedItems(userId: string): Promise<string[]> {
    return (await this.db.queryByUser<OwnershipGrant>(C.owned, userId)).map((g) => g.itemId);
  }

  /** Buy an item with Shards. Spend and grant are one operation keyed by the
   *  same idempotency key, so a retry can never charge twice or grant twice. */
  async purchaseItem(
    userId: string, itemId: string, priceShards: number, idempotencyKey: string,
  ): Promise<OwnershipGrant> {
    const grantId = `${userId}:${itemId}`;
    const already = await this.db.get<OwnershipGrant>(C.owned, grantId);
    if (already) return already;

    const entry = priceShards > 0
      ? await this.spendShards(userId, priceShards, 'spend_cosmetic', idempotencyKey, { itemId })
      : null;

    const grant: OwnershipGrant = {
      userId, itemId, grantedAt: Date.now(),
      via: priceShards > 0 ? 'purchase' : 'reward',
      ledgerId: entry?.id ?? null,
    };
    await this.db.set(C.owned, grantId, grant);
    return grant;
  }

  /** Non-purchase grant (pass benefit, reward, admin). */
  async grantItem(userId: string, itemId: string, via: OwnershipGrant['via'] = 'reward'): Promise<OwnershipGrant> {
    const grantId = `${userId}:${itemId}`;
    const already = await this.db.get<OwnershipGrant>(C.owned, grantId);
    if (already) return already;
    const grant: OwnershipGrant = { userId, itemId, grantedAt: Date.now(), via, ledgerId: null };
    await this.db.set(C.owned, grantId, grant);
    return grant;
  }

  // ── integrity ──────────────────────────────────────────────────────────
  /** Recompute balances from the ledger and report any drift. Run on a
   *  schedule; drift means a crash between the two writes in apply(). */
  async audit(userId: string): Promise<{ ok: boolean; stored: Balances; derived: Balances }> {
    const entries = await this.db.queryByUser<LedgerEntry>(C.ledger, userId);
    const derived: Balances = { LC: 0, SHARDS: 0 };
    for (const e of entries) derived[e.currency] += e.delta;
    const stored = await this.balances(userId);
    return { ok: stored.LC === derived.LC && stored.SHARDS === derived.SHARDS, stored, derived };
  }

  /** The ledger is the source of truth — repair balances from it. */
  async reconcile(userId: string): Promise<Balances> {
    const { derived } = await this.audit(userId);
    await this.db.set(C.balances, userId, derived);
    return derived;
  }
}

// ── the client-facing seam every existing feature already calls ───────────
/** Matches the `spendShards(cost, reason)` prop the Studio (M57) and
 *  Marketplace (M60) already take. Wire this to the real wallet and those
 *  features become authoritative with no UI change. */
export function makeSpendShards(wallet: Wallet, userId: string) {
  return async (cost: number, reason: string): Promise<boolean> => {
    try {
      // key on the spend intent so a double-click cannot double-charge
      const key = `spend_${userId}_${reason}_${Date.now()}`.replace(/\s+/g, '_');
      await wallet.spendShards(userId, cost, 'spend_generation', key, { reason });
      return true;
    } catch (e) {
      if (e instanceof InsufficientFunds) return false;
      throw e;
    }
  };
}
