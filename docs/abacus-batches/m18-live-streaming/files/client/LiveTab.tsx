// FEL LIVE tab: live-now hero, next-48h schedule rail, creator spotlight,
// labeled ad banner. Mount at the new bottom-nav Live position.

import { useEffect, useState } from 'react';
import type { GuideResponse, StreamMeta } from '../shared/streamContracts';

const CATEGORY_LABEL: Record<string, string> = {
  hiit: 'HIIT', plyo_iso: 'PLYOS & ISOS', smr_corrective: 'CORRECTIVE SMR',
  biomech_edu: 'BIOMECHANICS', pilates: 'PILATES', dance: 'DANCE',
  creator: 'CREATOR', event: 'EVENT',
};

function timeLabel(s: StreamMeta): string {
  if (s.state === 'live') return 'LIVE NOW';
  const d = new Date(s.startsAt);
  return d.toLocaleString(undefined, { weekday: 'short', hour: 'numeric', minute: '2-digit' });
}

export function LiveTab(props: { onOpenStream: (s: StreamMeta) => void; onDeepLink: (l: string) => void }) {
  const [guide, setGuide] = useState<GuideResponse | null>(null);

  useEffect(() => {
    fetch('/api/live/guide').then((r) => r.json()).then(setGuide).catch(() => {});
  }, []);

  if (!guide) return <p className="p-6 text-center text-sm text-slate-400">Tuning in…</p>;
  const hero = guide.liveNow[0] ?? guide.upNext[0];

  return (
    <div className="mx-auto max-w-md space-y-5 p-4 pb-24">
      <h1 className="text-xl font-black tracking-wide">FEL LIVE</h1>

      {/* Hero: live now or next up */}
      {hero && (
        <button onClick={() => props.onOpenStream(hero)}
          className="relative block w-full overflow-hidden rounded-2xl bg-slate-900 text-left">
          <div className="aspect-video w-full bg-gradient-to-br from-cyan-900 to-slate-950" />
          <span className={`absolute left-3 top-3 rounded px-2 py-0.5 text-[10px] font-black ${
            hero.state === 'live' ? 'bg-rose-500 text-white' : 'bg-slate-700 text-slate-200'}`}>
            {hero.state === 'live' ? '● LIVE' : timeLabel(hero)}
          </span>
          <div className="p-3">
            <p className="text-[10px] font-bold tracking-widest text-cyan-300">
              {CATEGORY_LABEL[hero.category]}
            </p>
            <h2 className="font-bold">{hero.title}</h2>
            {hero.state === 'live' && hero.viewerCount != null && (
              <p className="text-xs text-slate-400">{hero.viewerCount} watching</p>
            )}
          </div>
        </button>
      )}

      {/* Ad banner — always labeled */}
      {guide.banner && (
        <button
          onClick={() => {
            fetch('/api/live/ad-click', { method: 'POST', body: JSON.stringify({ creativeId: guide.banner!.id }) });
            props.onDeepLink(guide.banner!.deepLink);
          }}
          className="relative flex w-full items-center gap-3 rounded-xl border border-amber-500/40 bg-slate-900 p-3 text-left"
        >
          <span className="absolute right-2 top-1 text-[9px] font-black tracking-wider text-amber-400">
            {guide.banner.kind === 'house' ? 'FEL' : 'AD'}
          </span>
          <div className="h-12 w-12 shrink-0 rounded-lg bg-slate-700" />
          <div>
            <p className="text-sm font-semibold">{guide.banner.headline}</p>
            <p className="text-[11px] font-black text-cyan-300">{guide.banner.cta} →</p>
          </div>
        </button>
      )}

      {/* Schedule rail */}
      <section>
        <h3 className="mb-2 text-[11px] font-black tracking-widest text-slate-500">UP NEXT</h3>
        <div className="flex gap-2 overflow-x-auto pb-1">
          {guide.upNext.map((s) => (
            <button key={s.id} onClick={() => props.onOpenStream(s)}
              className={`w-44 shrink-0 rounded-xl border p-3 text-left ${
                s.sponsorAdId ? 'border-amber-500/50' : 'border-slate-700'} bg-slate-900`}>
              {s.sponsorAdId && <span className="text-[9px] font-black text-amber-400">SPONSORED</span>}
              <p className="text-[10px] font-bold tracking-widest text-cyan-300">{CATEGORY_LABEL[s.category]}</p>
              <p className="mt-0.5 text-sm font-semibold leading-tight">{s.title}</p>
              <p className="mt-1 text-[11px] text-slate-400">{timeLabel(s)}</p>
              {s.access === 'pass' && <span className="text-[10px] text-amber-300">◆ CLASS PASS</span>}
            </button>
          ))}
        </div>
      </section>

      {/* Creator spotlight */}
      <section>
        <h3 className="mb-2 text-[11px] font-black tracking-widest text-slate-500">SPOTLIGHT</h3>
        {guide.spotlights.map((sp) => {
          const ch = guide.channels.find((c) => c.id === sp.channelId);
          if (!ch) return null;
          return (
            <div key={sp.channelId} className="flex items-center gap-3 rounded-xl bg-slate-900 p-3">
              <div className="h-12 w-12 shrink-0 rounded-full bg-slate-700" />
              <div>
                <p className="text-[10px] font-black tracking-wider text-amber-400">{sp.headline}</p>
                <p className="text-sm font-bold">{ch.name}</p>
                <p className="text-[11px] leading-4 text-slate-400">{ch.bio}</p>
              </div>
            </div>
          );
        })}
      </section>

      {/* Replays */}
      {guide.replays.length > 0 && (
        <section>
          <h3 className="mb-2 text-[11px] font-black tracking-widest text-slate-500">REPLAYS</h3>
          <div className="grid grid-cols-2 gap-2">
            {guide.replays.map((s) => (
              <button key={s.id} onClick={() => props.onOpenStream(s)}
                className="rounded-xl bg-slate-900 p-3 text-left">
                <p className="text-[10px] font-bold tracking-widest text-cyan-300">{CATEGORY_LABEL[s.category]}</p>
                <p className="text-sm font-semibold leading-tight">{s.title}</p>
              </button>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
