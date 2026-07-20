// ArenaResultsScreen — leaderboard, your placement, payout status, and the
// Connect onboarding prompt for winners without a payout account.

import React, { useEffect, useState } from 'react';
import type { Contest, Payout } from '../shared/arenaContracts';

interface BoardRow { rank: number; userId: string; total: number; verified: boolean; ghostId: string | null; mine: boolean }
interface Results { contest: Contest; board: BoardRow[]; payouts: Payout[]; myEntry: unknown }

const usd = (c: number) => `$${(c / 100).toFixed(2)}`;
const medal = ['🥇', '🥈', '🥉'];

export function ArenaResultsScreen(props: { contestId: string; onBack: () => void; onWatchGhost?: (ghostId: string) => void }) {
  const [r, setR] = useState<Results | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    fetch(`/api/arena/${props.contestId}/results`).then((x) => x.json()).then(setR).catch(() => {});
  }, [props.contestId]);

  const myPayout = r?.payouts.find((p) => r.board.find((b) => b.mine && b.userId === p.userId));

  const onboard = async () => {
    setBusy(true);
    try {
      const res = await fetch('/api/arena/payouts/onboard', { method: 'POST' });
      const { url } = await res.json();
      window.location.assign(url);
    } finally { setBusy(false); }
  };

  if (!r) return <p className="p-6 text-center text-sm text-slate-400">Loading results…</p>;

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header>
        <button onClick={props.onBack} className="text-xs text-slate-400">← Arena</button>
        <h1 className="text-lg font-black">{r.contest.title}</h1>
        <p className="text-xs text-slate-400">
          {r.contest.state === 'paid' ? 'Final — payouts released'
            : r.contest.state === 'review' ? 'Under review — payouts release after 24h'
            : `${r.contest.entrantCount} entered`}
          {r.contest.prizePoolUsdCents > 0 && ` · ${usd(r.contest.prizePoolUsdCents)} pool`}
        </p>
      </header>

      {/* your payout banner */}
      {myPayout && (
        <div className="rounded-2xl border border-amber-500/60 bg-amber-500/10 p-4">
          <p className="font-black text-amber-300">
            {medal[myPayout.position - 1] ?? '🏆'} You placed #{myPayout.position} — {usd(myPayout.amountUsdCents)}
          </p>
          <p className="mt-1 text-xs text-slate-300">
            {myPayout.state === 'paid' ? 'Paid to your account.'
              : myPayout.state === 'pending_review' ? 'Releases after the 24-hour review window.'
              : myPayout.state === 'frozen' ? 'On hold — support will reach out.' : 'Releasing…'}
          </p>
          {myPayout.state === 'pending_review' && (
            <button onClick={onboard} disabled={busy}
              className="mt-2 w-full rounded-xl bg-amber-400 py-2 text-sm font-black text-black disabled:opacity-40">
              {busy ? '…' : 'SET UP PAYOUTS (Stripe)'}
            </button>
          )}
        </div>
      )}

      {/* leaderboard */}
      <div className="space-y-1.5">
        {r.board.slice(0, 25).map((row) => (
          <div key={row.userId} className={`flex items-center gap-3 rounded-xl p-3 ${
            row.mine ? 'border border-cyan-400/60 bg-cyan-400/10' : 'bg-slate-900'}`}>
            <span className="w-8 text-center font-black">{medal[row.rank - 1] ?? row.rank}</span>
            <span className="flex-1 truncate text-sm font-bold">
              {row.mine ? 'YOU' : `Baller ${row.userId.slice(-4).toUpperCase()}`}
              {!row.verified && <span className="ml-2 text-[10px] text-amber-400">REVIEW</span>}
            </span>
            <span className="font-black text-amber-300">{row.total}</span>
            {row.ghostId && props.onWatchGhost && (
              <button onClick={() => props.onWatchGhost!(row.ghostId!)}
                className="rounded-lg bg-slate-700 px-2 py-1 text-[10px] font-bold">WATCH</button>
            )}
          </div>
        ))}
        {!r.board.length && <p className="py-8 text-center text-sm text-slate-500">No scored runs yet — be first.</p>}
      </div>

      <p className="text-center text-[10px] text-slate-500">
        Scores are deterministic and server-verified. Disputes: support within 24h of lock.
      </p>
    </div>
  );
}
