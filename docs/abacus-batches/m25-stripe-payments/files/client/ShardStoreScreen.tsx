// Shard store: pack grid → Stripe hosted Checkout redirect → return handling.
// Mount at /shop/shards. Balance is a cached server read; the webhook is the
// only thing that changes it.

import { useEffect, useState } from 'react';
import { SHARD_PACKS } from '../shared/shardPacks';

export function ShardStoreScreen(props: {
  shardBalance: number;
  refreshBalance: () => Promise<number>;
  isMinor: boolean;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState<string | null>(null);
  const [banner, setBanner] = useState<{ kind: 'ok' | 'wait' | 'err'; text: string } | null>(null);

  // Handle return from Stripe: ?paid=1&cs=... → poll fulfillment; ?canceled=1
  useEffect(() => {
    const q = new URLSearchParams(window.location.search);
    if (q.get('canceled')) {
      setBanner({ kind: 'err', text: 'Checkout canceled — no charge was made.' });
      return;
    }
    if (q.get('paid') && q.get('cs')) {
      setBanner({ kind: 'wait', text: 'Payment received — delivering your shards…' });
      const cs = q.get('cs')!;
      let tries = 0;
      const poll = async () => {
        tries++;
        const res = await fetch(`/api/store/checkout-status?cs=${encodeURIComponent(cs)}`)
          .then((r) => r.json()).catch(() => ({ fulfilled: false }));
        if (res.fulfilled) {
          const bal = await props.refreshBalance();
          setBanner({ kind: 'ok', text: `Shards delivered! Balance: ${bal} ◆` });
        } else if (tries < 10) {
          setTimeout(poll, 1500);
        } else {
          setBanner({
            kind: 'wait',
            text: 'Payment confirmed — delivery is taking a moment. Your shards will appear shortly; no action needed.',
          });
        }
      };
      poll();
      window.history.replaceState(null, '', window.location.pathname);   // clean the URL
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const buy = async (packId: string) => {
    if (props.isMinor) {
      setBanner({ kind: 'err', text: 'Purchases need a parent or guardian — ask them to help.' });
      return;
    }
    setBusy(packId);
    try {
      const res = await fetch('/api/store/checkout', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ packId }),
      });
      if (!res.ok) throw new Error((await res.json().catch(() => ({})))?.message ?? 'Checkout failed');
      const { url } = await res.json();
      window.location.assign(url);           // → Stripe hosted Checkout
    } catch (e: any) {
      setBanner({ kind: 'err', text: e.message });
      setBusy(null);
    }
  };

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header className="flex items-center justify-between">
        <h1 className="text-xl font-black tracking-wide">SHARD STORE</h1>
        <div className="flex items-center gap-3">
          <span className="font-mono text-amber-300">{props.shardBalance} ◆</span>
          <button onClick={props.onClose} className="text-slate-500">✕</button>
        </div>
      </header>

      {banner && (
        <p className={`rounded-xl p-3 text-center text-sm font-semibold ${
          banner.kind === 'ok' ? 'bg-emerald-500/15 text-emerald-300'
          : banner.kind === 'wait' ? 'bg-cyan-500/10 text-cyan-300'
          : 'bg-rose-500/10 text-rose-300'}`}>
          {banner.text}
        </p>
      )}

      <p className="text-center text-sm text-slate-400">
        Shards unlock personalized training plans, live classes, seminars, private
        sessions, and premium Creator Card slots.
      </p>

      <div className="grid grid-cols-2 gap-3">
        {SHARD_PACKS.map((p) => (
          <button key={p.id} disabled={busy !== null} onClick={() => buy(p.id)}
            className="relative rounded-2xl border border-slate-700 bg-slate-900 p-4 text-left disabled:opacity-50">
            {p.badge && (
              <span className="absolute -top-2 right-3 rounded-full bg-amber-400 px-2 py-0.5 text-[9px] font-black text-black">
                {p.badge}
              </span>
            )}
            <p className="text-2xl font-black text-amber-300">
              {(p.shards + p.bonus).toLocaleString()} ◆
            </p>
            {p.bonus > 0 && (
              <p className="text-[11px] font-bold text-emerald-400">+{p.bonus} bonus included</p>
            )}
            <p className="mt-1 text-sm font-semibold">{p.name}</p>
            <p className="mt-2 text-lg font-black">
              {busy === p.id ? '…' : `$${(p.usdCents / 100).toFixed(2)}`}
            </p>
          </button>
        ))}
      </div>

      <p className="text-center text-[11px] leading-4 text-slate-500">
        Secure checkout by Stripe — Apple Pay, Google Pay & cards. Shards are a
        prepaid virtual currency with no cash value; unspent shards are refundable
        per our <a href="/refunds" className="underline">Refund Policy</a>. See{' '}
        <a href="/terms" className="underline">Terms</a>.
      </p>
    </div>
  );
}
