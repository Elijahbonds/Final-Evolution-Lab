// M33 — Cash Dunk Arena contracts. Money rails are USD-only (Stripe), fully
// separate from shards/coins (which stay non-redeemable).

// ── Contests ────────────────────────────────────────────────────────────────
export type ContestSurface = 'ingame' | 'irl';
export type ContestState = 'open' | 'judging' | 'review' | 'paid' | 'disputed' | 'cancelled';

export interface Contest {
  id: string;
  surface: ContestSurface;
  title: string;                   // "Friday Night Eastbay Open"
  entryUsdCents: number;           // 0 = free contest (always available everywhere)
  maxEntrants: number;
  seed: string;                    // deterministic conditions (in-game)
  opensAt: string;
  locksAt: string;                 // last entry time
  state: ContestState;
  entrantCount: number;
  prizePoolUsdCents: number;       // entries − rake (server-computed)
}

export const PLATFORM_RAKE = 0.10;                 // declared in UI
/** pool split by finishing position (top 3) */
export const PAYOUT_SPLIT = [0.6, 0.3, 0.1];
export const REVIEW_WINDOW_HOURS = 24;

// ── Entries & ghosts ────────────────────────────────────────────────────────
export interface ArenaEntry {
  contestId: string;
  userId: string;
  paidLedgerRef: string | null;    // Stripe event id (null = free entry)
  ghostId: string | null;          // filled on run submission
  scorecard: JudgeScorecard | null;
  verified: boolean;               // server replay reproduced the score
  enteredAt: string;
}

/** In-game run telemetry the judges score + the server re-verifies. */
export interface DunkRunTelemetry {
  seed: string;
  style: 'power' | 'flashy' | 'sig';
  approachSpeed: number;           // m/s at gather
  chargeLevel: number;             // 0..1
  qteDeltaMs: number;              // |tap − rim-arrival| (lower = better)
  apexHeight: number;              // m
  hangTimeMs: number;
  cleanRelease: boolean;
  inputStream: string;             // compressed inputs → deterministic replay
}

// ── AI judges ───────────────────────────────────────────────────────────────
export interface JudgeScore {
  judgeId: 'silk' | 'doc' | 'prime';
  technique: number;               // 0–10, deterministic
  difficulty: number;              // 0–10, deterministic
  style: number;                   // 0–10 = deterministic base ± bounded persona lean
  total: number;                   // sum, 0–30
  commentary: string;              // flavor ONLY — never affects score
}
export interface JudgeScorecard {
  scores: JudgeScore[];            // exactly 3
  grandTotal: number;              // 0–90
  /** athletic metrics echoed for the card (IRL: measured; in-game: telemetry) */
  metrics: { jumpHeightCm?: number; hangTimeMs?: number; apexHeight?: number };
}

/** Persona style lean is bounded so scoring stays a pure skill function. */
export const PERSONA_STYLE_LEAN_MAX = 0.5;         // ± on the 0–10 style axis

// ── Compliance ──────────────────────────────────────────────────────────────
export interface GeoRules {
  /** ISO country codes where cash contests may run at all */
  allowedCountries: string[];
  /** blocked subdivisions within allowed countries (US state codes etc.) */
  blockedSubdivisions: string[];
}
/** Start conservative; expand only with counsel sign-off. */
export const GEO_RULES: GeoRules = {
  allowedCountries: ['US'],
  blockedSubdivisions: ['US-AZ', 'US-AR', 'US-CT', 'US-DE', 'US-LA', 'US-MT', 'US-SC', 'US-SD', 'US-TN'],
};

export const LIMITS = {
  minAge: 18,
  maxWeeklyCashEntries: 15,
  maxWeeklyDepositUsdCents: 20_000,   // $200
  selfExclusionDays: [7, 30, 365] as const,
};

export interface ComplianceState {
  userId: string;
  ageVerified: boolean;              // Stripe Identity (seam)
  region: string | null;             // 'US-CA'
  selfExcludedUntil: string | null;
  weeklyEntries: number;
  weeklyDepositUsdCents: number;
}

// ── Payouts ─────────────────────────────────────────────────────────────────
export interface Payout {
  contestId: string;
  userId: string;
  position: number;                  // 1-based
  amountUsdCents: number;
  state: 'pending_review' | 'released' | 'frozen' | 'paid';
  connectTransferId?: string;
}
