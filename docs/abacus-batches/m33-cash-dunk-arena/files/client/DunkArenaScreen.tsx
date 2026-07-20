// Dunk Arena — contests list, entry flow (free / cash via Stripe), vs-ghost
// match hand-off, judge scorecards, payout status. Rake declared in UI.

import React, { useEffect, useState } from 'react';
import type { Contest, JudgeScorecard } from '../shared/arenaContracts';

const usd = (c: number) => `$${(c / 100).toFixed(2)}`;

export function DunkArenaScreen(props: {
  onPlayContest: (contest: Contest) => Promise<JudgeScorecard | null>; // runs DunkMode w/ seed + ghost shadow
  onNeedVerification: () => void;      // Stripe Identity flow
  onNeedPayoutAccount: () => void;     // Connect onboarding
}) {
  const [contests, setContests] = useState<Contest[]>([]);
  const [card, setCard] = useState<JudgeScorecard | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const load = () => fetch('/api/arena/contests').then((r) => r.json()).then(setContests).catch(() => {});
  useEffect(() => { load(); }, []);

  const enter = async (c: Contest) => {
    setBusy(c.id); setNotice(null);
    try {
      if (c.entryUsdCents > 0) {
        // Cash entry → Stripe Checkout (M25 rails); webhook confirms the entry
        const res = await fetch(`/api/arena/${c.id}/checkout`, { method: 'POST' });
        if (res.status === 451) { setNotice('Cash contests aren’t available in your region — free contests are.'); return; }
        if (res.status === 403) { props.onNeedVerification(); return; }
        if (res.status === 429) { setNotice((await res.json()).message); return; }
        if (!res.ok) throw new Error('entry failed');
        const { url } = await res.json();
        window.location.assign(url);
        return;
      }
      const res = await fetch(`/api/arena/${c.id}/enter`, { method: 'POST' });
      if (!res.ok) throw new Error((await res.json().catch(() => ({})))?.message ?? 'entry failed');
      const scorecard = await props.onPlayContest(c);   // → DunkMode(seed) + ghost shadow → submitRun
      if (scorecard) setCard(scorecard);
      load();
    } catch (e: unknown) {
      setNotice(e instanceof Error ? e.message : 'Something went wrong');
    } finally { setBusy(null); }
  };

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header>
        <h1 className="text-xl font-black tracking-wide">DUNK ARENA</h1>
        <p className="text-xs text-slate-400">
          Head-to-head vs real competitors' ghosts · scored by AI judges ·
          skill decides everything. 18+ for cash · 10% platform fee on pools.
        </p>
      </header>

      {notice && <p className="rounded-xl bg-slate-800 p-3 text-sm text-amber-300">{notice}</p>}

      {contests.map((c) => (
        <div key={c.id} className={`rounded-2xl border p-4 ${
          c.entryUsdCents > 0 ? 'border-amber-500/50' : 'border-slate-700'} bg-slate-900`}>
          <div className="flex items-start justify-between">
            <div>
              <p className="text-[10px] font-black tracking-widest text-cyan-300">
                {c.surface === 'irl' ? 'IRL PROVING GROUND' : 'IN-GAME ARENA'}
              </p>
              <h2 className="font-bold">{c.title}</h2>
              <p className="mt-0.5 text-[11px] text-slate-400">
                {c.entrantCount}/{c.maxEntrants} in · locks {new Date(c.locksAt).toLocaleString(undefined, { weekday: 'short', hour: 'numeric' })}
              </p>
            </div>
            <div className="text-right">
              {c.entryUsdCents > 0 ? (
                <>
                  <p className="font-black text-amber-300">{usd(c.prizePoolUsdCents)} pool</p>
                  <p className="text-[11px] text-slate-400">{usd(c.entryUsdCents)} entry</p>
                </>
              ) : <p className="font-black text-emerald-400">FREE</p>}
            </div>
          </div>
          <button disabled={busy !== null || c.state !== 'open'}
            onClick={() => enter(c)}
            className={`mt-3 w-full rounded-xl py-3 font-black disabled:opacity-40 ${
              c.entryUsdCents > 0 ? 'bg-amber-400 text-black' : 'bg-cyan-400 text-black'}`}>
            {busy === c.id ? '…' : c.entryUsdCents > 0 ? `ENTER · ${usd(c.entryUsdCents)}` : 'ENTER FREE'}
          </button>
        </div>
      ))}

      {/* Judge scorecard after a run */}
      {card && (
        <div className="rounded-2xl border border-slate-600 bg-slate-950 p-4">
          <p className="text-center text-[10px] font-black tracking-widest text-slate-400">THE JUDGES HAVE SCORED</p>
          <p className="my-1 text-center text-4xl font-black text-amber-300">{card.grandTotal}</p>
          {card.metrics.jumpHeightCm && (
            <p className="text-center text-[11px] text-slate-400">
              {card.metrics.jumpHeightCm} cm vert · {card.metrics.hangTimeMs} ms hang
            </p>
          )}
          <div className="mt-3 space-y-2">
            {card.scores.map((s) => (
              <div key={s.judgeId} className="rounded-xl bg-slate-900 p-3">
                <div className="flex justify-between text-sm font-bold">
                  <span className="capitalize">{s.judgeId}</span>
                  <span className="text-amber-300">{s.total}</span>
                </div>
                <p className="text-[11px] text-slate-400">
                  T {s.technique} · D {s.difficulty} · S {s.style}
                </p>
                <p className="mt-1 text-xs italic text-slate-300">“{s.commentary}”</p>
              </div>
            ))}
          </div>
          <button onClick={() => setCard(null)} className="mt-3 w-full rounded-xl bg-slate-700 py-2 text-sm font-bold">
            BACK TO ARENA
          </button>
        </div>
      )}

      <p className="text-center text-[10px] leading-4 text-slate-500">
        Skill-based competition. No purchase necessary for free contests. Cash
        contests: 18+, identity-verified, unavailable in some regions. Payouts
        release after a 24-hour review. Deposit and entry limits apply —
        manage limits and self-exclusion in Profile.
      </p>
    </div>
  );
}
