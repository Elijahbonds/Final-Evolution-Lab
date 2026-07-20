// BootSplash — the console ritual (Shell 03 §1.2): cartridge insert → venue art
// boot with progress → READY gate → 3-2-1 → GO. Doubles as the loading cover
// (no raw spinner anywhere) and renders the error/retry state from the harness.

import React, { useEffect, useState } from 'react';
import type { ModePhase } from '../hotfix/ModeHarness';

const VENUE_ART: Record<string, { art: string; sub: string; tint: string }> = {
  dunk: { art: '/img/venues/venice-court.jpg', sub: 'VENICE BEACH COURT', tint: '#ffb36b' },
  karate: { art: '/img/venues/dojo.jpg', sub: 'SHIMOGAMO DOJO', tint: '#ff9d5c' },
  football: { art: '/img/venues/gridiron.jpg', sub: 'THE GRIDIRON', tint: '#9fb7ff' },
  skateboard: { art: '/img/venues/skatepark.jpg', sub: 'VENICE SKATEPARK', tint: '#ffd75e' },
  snowboard_slalom: { art: '/img/venues/slope.jpg', sub: 'MOUNTAIN SLOPE', tint: '#cfe8ff' },
  default: { art: '/img/venues/default.jpg', sub: 'FINAL EVOLUTION', tint: '#22d3ee' },
};

export function BootSplash(props: {
  modeId: string;
  title: string;
  phase: ModePhase;
  detail?: number | string;         // countdown number or error message
  onStart: () => void;              // READY tap
  onRetry: () => void;              // error retry
}) {
  const v = VENUE_ART[props.modeId] ?? VENUE_ART.default;
  const [inserted, setInserted] = useState(false);
  useEffect(() => { const t = setTimeout(() => setInserted(true), 60); return () => clearTimeout(t); }, []);

  if (props.phase === 'playing' || props.phase === 'paused' || props.phase === 'ended') return null;

  return (
    <div className="absolute inset-0 z-40 overflow-hidden"
      style={{ background: '#05060a', fontFamily: 'var(--fel-font-display, ui-monospace)' }}>
      {/* cartridge-insert wipe */}
      <div className="absolute inset-0 transition-transform duration-500 ease-out"
        style={{
          transform: inserted ? 'translateY(0)' : 'translateY(-100%)',
          backgroundImage: `linear-gradient(180deg, rgba(5,6,10,.25), rgba(5,6,10,.92)), url(${v.art})`,
          backgroundSize: 'cover', backgroundPosition: 'center',
        }} />
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 px-6 text-center">
        <p className="text-[11px] font-black tracking-[0.4em]" style={{ color: v.tint }}>{v.sub}</p>
        <h1 className="text-4xl font-black tracking-wide text-white drop-shadow-lg">{props.title}</h1>

        {props.phase === 'loading' && (
          <div className="w-56">
            <div className="h-1.5 overflow-hidden rounded-full bg-white/15">
              <div className="fel-boot-bar h-full rounded-full" style={{ background: v.tint }} />
            </div>
            <p className="mt-2 text-[11px] tracking-widest text-white/60">LOADING ARENA…</p>
          </div>
        )}

        {props.phase === 'ready' && (
          <button onClick={props.onStart}
            className="fel-cta mt-2 rounded-2xl px-10 py-4 text-lg font-black text-black"
            style={{ background: v.tint, boxShadow: `0 0 34px ${v.tint}66` }}>
            TAP TO START
          </button>
        )}

        {props.phase === 'countdown' && (
          <div key={String(props.detail)} className="fel-count text-8xl font-black text-white">
            {props.detail === 0 || props.detail === undefined ? 'GO!' : props.detail}
          </div>
        )}

        {props.phase === 'error' && (
          <div className="max-w-sm space-y-3">
            <p className="text-sm text-rose-300">
              {typeof props.detail === 'string' ? props.detail : 'The arena failed to load.'}
            </p>
            <button onClick={props.onRetry}
              className="rounded-2xl bg-white px-8 py-3 font-black text-black">RETRY</button>
          </div>
        )}
      </div>

      <style>{`
        .fel-boot-bar { width: 30%; animation: felboot 1.1s ease-in-out infinite alternate; }
        @keyframes felboot { from { margin-left: 0; width: 30%; } to { margin-left: 70%; width: 30%; } }
        .fel-cta { transition: transform .12s ease; }
        .fel-cta:active { transform: scale(.95); }
        .fel-count { animation: felcount .8s cubic-bezier(.2,1.4,.4,1); }
        @keyframes felcount { from { transform: scale(1.8); opacity: 0; } to { transform: scale(1); opacity: 1; } }
      `}</style>
    </div>
  );
}

/** Eject wipe on quit-to-hub: call, await, then navigate. */
export function ejectTransition(mount: HTMLElement): Promise<void> {
  return new Promise((resolve) => {
    const el = document.createElement('div');
    el.style.cssText =
      'position:fixed;inset:0;background:#05060a;z-index:60;transform:translateY(100%);' +
      'transition:transform .35s cubic-bezier(.4,0,.2,1);';
    mount.appendChild(el);
    requestAnimationFrame(() => { el.style.transform = 'translateY(0)'; });
    setTimeout(() => { resolve(); setTimeout(() => el.remove(), 400); }, 360);
  });
}
