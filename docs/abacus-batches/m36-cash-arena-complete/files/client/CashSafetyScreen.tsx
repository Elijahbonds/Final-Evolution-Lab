// CashSafetyScreen — player-facing responsible-play controls: live limit
// usage, self-exclusion, age-verification entry point. Linked from Profile
// AND from every cash contest card ("Manage limits").

import React, { useEffect, useState } from 'react';
import type { ComplianceState } from '../shared/arenaContracts';

interface SafetyPayload {
  compliance: ComplianceState | null;
  limits: { minAge: number; maxWeeklyCashEntries: number; maxWeeklyDepositUsdCents: number; selfExclusionDays: readonly number[] };
}

const usd = (c: number) => `$${(c / 100).toFixed(0)}`;

export function CashSafetyScreen(props: { onBack: () => void }) {
  const [data, setData] = useState<SafetyPayload | null>(null);
  const [confirming, setConfirming] = useState<number | null>(null);
  const [busy, setBusy] = useState(false);

  const load = () => fetch('/api/arena/safety').then((r) => r.json()).then(setData).catch(() => {});
  useEffect(() => { load(); }, []);

  const verifyAge = async () => {
    setBusy(true);
    try {
      const res = await fetch('/api/arena/verify-age', { method: 'POST' });
      const { url } = await res.json();
      window.location.assign(url);
    } finally { setBusy(false); }
  };

  const selfExclude = async (days: number) => {
    setBusy(true);
    try {
      await fetch('/api/arena/safety/self-exclude', {
        method: 'POST', headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ days }),
      });
      setConfirming(null);
      load();
    } finally { setBusy(false); }
  };

  if (!data) return <p className="p-6 text-center text-sm text-slate-400">Loading…</p>;
  const c = data.compliance;
  const excluded = c?.selfExcludedUntil && +new Date(c.selfExcludedUntil) > Date.now();

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header>
        <button onClick={props.onBack} className="text-xs text-slate-400">← Back</button>
        <h1 className="text-lg font-black">PLAY SAFELY</h1>
        <p className="text-xs text-slate-400">Cash contests are skill competitions with hard limits.</p>
      </header>

      {excluded && (
        <div className="rounded-2xl border border-rose-500/60 bg-rose-500/10 p-4">
          <p className="font-black text-rose-300">Self-exclusion active</p>
          <p className="text-xs text-slate-300">
            Cash entries paused until {new Date(c!.selfExcludedUntil!).toLocaleDateString()}.
            Free contests stay open.
          </p>
        </div>
      )}

      <div className="rounded-2xl bg-slate-900 p-4">
        <p className="text-[10px] font-black tracking-widest text-slate-400">AGE VERIFICATION (18+)</p>
        {c?.ageVerified
          ? <p className="mt-1 text-sm font-bold text-emerald-400">Verified ✓</p>
          : <button onClick={verifyAge} disabled={busy}
              className="mt-2 w-full rounded-xl bg-cyan-400 py-2 text-sm font-black text-black disabled:opacity-40">
              VERIFY WITH STRIPE IDENTITY
            </button>}
      </div>

      <div className="rounded-2xl bg-slate-900 p-4">
        <p className="text-[10px] font-black tracking-widest text-slate-400">THIS WEEK</p>
        <Meter label="Cash entries" now={c?.weeklyEntries ?? 0} max={data.limits.maxWeeklyCashEntries} fmt={(n) => `${n}`} />
        <Meter label="Deposits" now={c?.weeklyDepositUsdCents ?? 0} max={data.limits.maxWeeklyDepositUsdCents} fmt={usd} />
        <p className="mt-2 text-[10px] text-slate-500">Limits reset weekly and cannot be raised in-app.</p>
      </div>

      <div className="rounded-2xl bg-slate-900 p-4">
        <p className="text-[10px] font-black tracking-widest text-slate-400">TAKE A BREAK</p>
        <p className="mt-1 text-xs text-slate-300">Pause all cash entries. This cannot be undone early.</p>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {data.limits.selfExclusionDays.map((d) => (
            <button key={d} onClick={() => setConfirming(d)} disabled={busy || !!excluded}
              className="rounded-xl border border-slate-600 py-2 text-sm font-bold disabled:opacity-40">
              {d} days
            </button>
          ))}
        </div>
        {confirming !== null && (
          <div className="mt-3 rounded-xl border border-rose-500/50 bg-rose-500/10 p-3">
            <p className="text-sm font-bold text-rose-300">Pause cash play for {confirming} days?</p>
            <div className="mt-2 flex gap-2">
              <button onClick={() => selfExclude(confirming)} disabled={busy}
                className="flex-1 rounded-lg bg-rose-500 py-2 text-sm font-black text-white">CONFIRM</button>
              <button onClick={() => setConfirming(null)}
                className="flex-1 rounded-lg bg-slate-700 py-2 text-sm font-bold">CANCEL</button>
            </div>
          </div>
        )}
      </div>

      <p className="text-center text-[10px] leading-4 text-slate-500">
        Skill-based competition — outcomes are determined by measured performance,
        never chance. If play stops feeling fun, take a break. Support: in-app chat.
      </p>
    </div>
  );
}

function Meter(props: { label: string; now: number; max: number; fmt: (n: number) => string }) {
  const pct = Math.min(100, (props.now / props.max) * 100);
  return (
    <div className="mt-2">
      <div className="flex justify-between text-xs">
        <span className="text-slate-300">{props.label}</span>
        <span className="font-bold">{props.fmt(props.now)} / {props.fmt(props.max)}</span>
      </div>
      <div className="mt-1 h-2 rounded-full bg-slate-800">
        <div className={`h-2 rounded-full ${pct > 80 ? 'bg-amber-400' : 'bg-cyan-400'}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}
