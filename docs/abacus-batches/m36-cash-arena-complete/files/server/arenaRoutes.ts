// arenaRoutes — every Arena endpoint behind ONE catch-all Next route.
//
// app/api/arena/[[...path]]/route.ts:
//   import { handleArena } from '@/server/arenaRoutes';
//   export const GET = (req: Request, c: { params: Promise<{ path?: string[] }> }) =>
//     c.params.then((p) => handleArena(req, p.path ?? []));
//   export const POST = GET;
//
// app/api/stripe/arena-webhook/route.ts (RAW body — do not parse):
//   import { handleStripeWebhook } from '@/server/stripeRails';
//   import { arenaDeps } from '@/server/arenaRoutes';
//   export async function POST(req: Request) {
//     const raw = await req.text();
//     const sig = req.headers.get('stripe-signature') ?? '';
//     await handleStripeWebhook(raw, sig, arenaDeps());
//     return Response.json({ received: true });
//   }

import { LIMITS, type ArenaEntry, type ComplianceState, type Contest, type Payout } from '../shared/arenaContracts';
import { deterministicSimulator } from '../shared/deterministicSim';
import { confirmEntry, releasePayouts, settleContest, submitRun, type Db } from './cashArenaApi';
import { judgeIrlRun } from '../irl/irlDunkJudging';
import { ensureWeeklyContests, getArenaDb, pickRivalGhost, saveGhost, type GhostDoc } from './arenaStore';
import { createEntryCheckout, StripeConnectPayouts, StripeIdentityService } from './stripeRails';

// ── AUTH SEAM — wire to the app's existing session (one line to change) ────
async function getUserId(req: Request): Promise<string> {
  // TODO(abacus): replace with the app's real session lookup, e.g.:
  //   const session = await getServerSession(); return session.user.id;
  const uid = req.headers.get('x-fel-user');
  if (!uid) throw Object.assign(new Error('sign in required'), { status: 401 });
  return uid;
}

export function arenaDeps() {
  const db = getArenaDb();                               // pass Mongo db here if available
  const identity = new StripeIdentityService(db);
  const payouts = new StripeConnectPayouts(db);
  return { db, identity, payouts, sim: deterministicSimulator };
}

const json = (data: unknown, status = 200) => Response.json(data, { status });

export async function handleArena(req: Request, path: string[]): Promise<Response> {
  const deps = arenaDeps();
  try {
    const userId = await getUserId(req);
    // keep the region fresh from CDN geo headers on every call
    await deps.identity.recordRegion(
      userId,
      req.headers.get('x-vercel-ip-country'),
      req.headers.get('x-vercel-ip-country-region'),
    );
    const ctx = { userId, ...deps };
    const [a, b, c] = path;

    // ── contests ───────────────────────────────────────────────────────────
    if (req.method === 'GET' && a === 'contests') {
      await ensureWeeklyContests(deps.db);
      const open = (await deps.db.query<Contest>('arena_contests', { state: 'open' }))
        .filter((x) => +new Date(x.locksAt) > Date.now())
        .sort((x, y) => x.entryUsdCents - y.entryUsdCents);
      return json(open);
    }

    // ── entry ──────────────────────────────────────────────────────────────
    if (req.method === 'POST' && b === 'checkout') {
      const contest = await deps.db.get<Contest>('arena_contests', a);
      if (!contest || contest.state !== 'open') return json({ message: 'contest closed' }, 404);
      return json(await createEntryCheckout(userId, contest));
    }
    if (req.method === 'POST' && b === 'enter') {
      return json(await confirmEntry(ctx, a, null));     // free contests only
    }

    // ── runs & ghosts ──────────────────────────────────────────────────────
    if (req.method === 'POST' && b === 'submit') {
      const body = await req.json();
      const ghostId = body.ghostData
        ? await saveGhost(deps.db, a, userId, body.ghostData) : (body.ghostId ?? '');
      return json(await submitRun(ctx, a, { telemetry: body.telemetry, ghostId }));
    }
    if (req.method === 'GET' && b === 'rival-ghost') {
      return json(await pickRivalGhost(deps.db, a, userId));  // null = first entrant
    }
    if (req.method === 'GET' && a === 'ghosts' && b) {
      return json(await deps.db.get<GhostDoc>('arena_ghosts', b));
    }

    // ── IRL submission (pose keypoints only — video never leaves the phone) ─
    if (req.method === 'POST' && b === 'irl-submit') {
      const contest = await deps.db.get<Contest>('arena_contests', a);
      const entry = await deps.db.get<ArenaEntry>('arena_entries', `${a}_${userId}`);
      if (!contest || contest.surface !== 'irl' || !entry) return json({ message: 'no IRL entry' }, 404);
      if (entry.scorecard) return json({ message: 'run already submitted' }, 409);
      const { frames, athleteHeightCm } = await req.json();
      if (!Array.isArray(frames) || frames.length < 12) return json({ message: 'clip too short' }, 422);
      const result = await judgeIrlRun(frames, athleteHeightCm);
      if (result.scorecard) {
        entry.scorecard = result.scorecard;
        // cash IRL runs stay unverified until human review clears them
        entry.verified = contest.entryUsdCents === 0 && !result.needsHumanReview;
        await deps.db.put('arena_entries', `${a}_${userId}`, entry);
      }
      return json(result);
    }

    // ── results ────────────────────────────────────────────────────────────
    if (req.method === 'GET' && b === 'results') {
      const entries = (await deps.db.query<ArenaEntry>('arena_entries', { contestId: a }))
        .filter((e) => e.scorecard)
        .sort((x, y) => y.scorecard!.grandTotal - x.scorecard!.grandTotal);
      const payouts = await deps.db.query<Payout>('arena_payouts', { contestId: a });
      return json({
        contest: await deps.db.get<Contest>('arena_contests', a),
        board: entries.map((e, i) => ({
          rank: i + 1, userId: e.userId, total: e.scorecard!.grandTotal,
          verified: e.verified, ghostId: e.ghostId, mine: e.userId === userId,
        })),
        payouts, myEntry: entries.find((e) => e.userId === userId) ?? null,
      });
    }

    // ── payouts & safety ───────────────────────────────────────────────────
    if (req.method === 'POST' && a === 'payouts' && b === 'onboard') {
      return json({ url: await deps.payouts.onboardingLink(userId) });
    }
    if (req.method === 'POST' && a === 'verify-age') {
      return json(await deps.identity.startVerification(userId));
    }
    if (req.method === 'GET' && a === 'safety') {
      const comp = await deps.db.get<ComplianceState>('arena_compliance', userId);
      return json({ compliance: comp, limits: LIMITS });
    }
    if (req.method === 'POST' && a === 'safety' && b === 'self-exclude') {
      const { days } = await req.json();
      if (!(LIMITS.selfExclusionDays as readonly number[]).includes(days)) return json({ message: 'invalid period' }, 422);
      const comp = (await deps.db.get<ComplianceState>('arena_compliance', userId)) ?? {
        userId, ageVerified: false, region: null, selfExcludedUntil: null,
        weeklyEntries: 0, weeklyDepositUsdCents: 0,
      };
      comp.selfExcludedUntil = new Date(Date.now() + days * 86400_000).toISOString();
      await deps.db.put('arena_compliance', userId, comp);
      return json({ selfExcludedUntil: comp.selfExcludedUntil });
    }

    // ── admin/cron (Vercel cron or Abacus scheduler; ADMIN_KEY header) ─────
    if (req.method === 'POST' && a === 'admin') {
      if (req.headers.get('x-admin-key') !== process.env.ADMIN_KEY || !process.env.ADMIN_KEY) {
        return json({ message: 'forbidden' }, 403);
      }
      if (b === 'settle') return json(await settleContest(ctx, c));
      if (b === 'release') return json({ released: await releasePayouts(ctx, c) });
      if (b === 'sweep') {                               // one cron does it all
        const contests = await deps.db.query<Contest>('arena_contests', {});
        const acted: string[] = [];
        for (const ct of contests) {
          const locked = +new Date(ct.locksAt) < Date.now();
          try {
            if (locked && ['open', 'judging'].includes(ct.state)) { await settleContest(ctx, ct.id); acted.push(`settled:${ct.id}`); }
            else if (ct.state === 'review') { await releasePayouts(ctx, ct.id); acted.push(`released:${ct.id}`); }
          } catch { /* review window still open etc. — next sweep */ }
        }
        return json({ acted });
      }
    }

    return json({ message: 'not found' }, 404);
  } catch (e) {
    const err = e as Error & { status?: number };
    return json({ message: err.message }, err.status ?? 500);
  }
}
