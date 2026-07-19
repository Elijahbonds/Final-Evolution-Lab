// Purchase screen: buy the 4-week personalized plan (shards) or the 12-week
// program upsell. Balance comes from the server wallet; this component never
// mutates currency locally.

import { useState } from 'react';
import { SHARD_PRICES, type PurchaseReceipt } from '../shared/contracts';

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    headers: { 'Content-Type': 'application/json' }, ...init,
  });
  if (!res.ok) throw new Error((await res.json().catch(() => ({})))?.message ?? `HTTP ${res.status}`);
  return res.json();
}

const TIERS = [
  {
    product: 'workout_4w' as const,
    title: '4-WEEK PERSONALIZED PLAN',
    price: SHARD_PRICES.workout_4w,
    bullets: [
      'Film one movement screen or stress test',
      'Your mini avatar, built from your video',
      'Every exercise animated — performed by YOU',
      'Plan targets what your scan actually shows',
    ],
  },
  {
    product: 'program_12w' as const,
    title: '12-WEEK FULL PROGRAM',
    price: SHARD_PRICES.program_12w,
    badge: 'BEST VALUE',
    bullets: [
      'Everything in the 4-week plan',
      'Three phases: Correct → Build → Express',
      'Auto-progressions as you level up',
      'Retest week with a fresh scan included',
    ],
  },
];

export function WorkoutPurchaseFlow(props: {
  shardBalance: number;
  onPurchased: (receipt: PurchaseReceipt) => void;  // navigate → ScanCaptureScreen
  onBuyShards: () => void;                          // open the shard store
}) {
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const buy = async (product: 'workout_4w' | 'program_12w') => {
    setBusy(product); setError(null);
    try {
      const receipt = await api<PurchaseReceipt>('/api/workout/purchase', {
        method: 'POST', body: JSON.stringify({ product }),
      });
      props.onPurchased(receipt);
    } catch (e: any) {
      setError(e.message);
    } finally {
      setBusy(null);
    }
  };

  return (
    <div className="mx-auto max-w-md space-y-4 p-4">
      <header className="text-center">
        <h1 className="text-xl font-black tracking-wide">TRAIN AS YOURSELF</h1>
        <p className="mt-1 text-sm text-slate-400">
          Upload one video. Get a plan built for your body — with your own avatar
          showing you every rep.
        </p>
      </header>

      {TIERS.map((t) => {
        const affordable = props.shardBalance >= t.price;
        return (
          <div key={t.product} className="relative rounded-2xl border border-slate-700 bg-slate-900 p-4">
            {t.badge && (
              <span className="absolute -top-2 right-4 rounded-full bg-amber-500 px-2 py-0.5 text-[10px] font-black text-black">
                {t.badge}
              </span>
            )}
            <div className="flex items-baseline justify-between">
              <h2 className="font-bold">{t.title}</h2>
              <span className="font-mono text-cyan-300">{t.price} ◆</span>
            </div>
            <ul className="mt-2 space-y-1 text-sm text-slate-300">
              {t.bullets.map((b) => <li key={b}>· {b}</li>)}
            </ul>
            <button
              disabled={busy !== null}
              onClick={() => (affordable ? buy(t.product) : props.onBuyShards())}
              className={`mt-3 w-full rounded-xl py-3 text-sm font-black tracking-wider ${
                affordable ? 'bg-cyan-400 text-black' : 'bg-slate-700 text-slate-200'
              }`}
            >
              {busy === t.product ? 'PROCESSING…'
                : affordable ? `UNLOCK — ${t.price} SHARDS`
                : `GET SHARDS (${props.shardBalance}/${t.price})`}
            </button>
          </div>
        );
      })}

      {error && <p className="text-center text-sm text-rose-400">{error}</p>}
      <p className="text-center text-[11px] leading-4 text-slate-500">
        Training guidance, not medical advice. Consult a professional for injuries.
      </p>
    </div>
  );
}
