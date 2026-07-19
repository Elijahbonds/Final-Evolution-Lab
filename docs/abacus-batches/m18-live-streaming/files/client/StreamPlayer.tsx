// Stream player: HLS playback (hls.js / native Safari), pass gating, pre-roll ad
// slot with label, shard tips, watch-XP heartbeat with anti-idle interaction check.

import { useEffect, useRef, useState } from 'react';
import Hls from 'hls.js';
import type { StreamMeta, AdCreative } from '../shared/streamContracts';

export function StreamPlayer(props: {
  stream: StreamMeta;
  canWatch: boolean;                       // resolved server-side before mount
  onBuyPass: () => void;
  onClose: () => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [preroll, setPreroll] = useState<AdCreative | null>(null);
  const [phase, setPhase] = useState<'ad' | 'playing'>('ad');
  const [tipFlash, setTipFlash] = useState<string | null>(null);
  const interacted = useRef(false);

  // Pre-roll ad slot
  useEffect(() => {
    if (!props.canWatch) return;
    fetch('/api/live/ad?slot=preroll').then((r) => r.json())
      .then((ad) => { setPreroll(ad); if (!ad) setPhase('playing'); })
      .catch(() => setPhase('playing'));
  }, [props.canWatch]);

  // HLS attach
  useEffect(() => {
    if (phase !== 'playing' || !props.canWatch || !props.stream.hlsUrl) return;
    const video = videoRef.current!;
    if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = props.stream.hlsUrl;                 // Safari native
    } else if (Hls.isSupported()) {
      const hls = new Hls({ liveSyncDurationCount: 3 });
      hls.loadSource(props.stream.hlsUrl);
      hls.attachMedia(video);
      return () => hls.destroy();
    }
  }, [phase, props.canWatch, props.stream.hlsUrl]);

  // Watch-XP heartbeat: every 60s, only if the viewer interacted since last tick
  useEffect(() => {
    if (phase !== 'playing') return;
    const iv = setInterval(() => {
      fetch('/api/live/watch-heartbeat', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ streamId: props.stream.id, interacted: interacted.current }),
      }).catch(() => {});
      interacted.current = false;
    }, 60_000);
    const mark = () => { interacted.current = true; };
    window.addEventListener('pointerdown', mark);
    return () => { clearInterval(iv); window.removeEventListener('pointerdown', mark); };
  }, [phase, props.stream.id]);

  const sendTip = async (shards: 25 | 50 | 100 | 500) => {
    try {
      const res = await fetch('/api/live/tip', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ streamId: props.stream.id, shards }),
      });
      if (!res.ok) throw new Error();
      setTipFlash(`+${shards} ◆ sent!`);
      setTimeout(() => setTipFlash(null), 2500);
    } catch { setTipFlash('Tip failed — check shard balance'); setTimeout(() => setTipFlash(null), 2500); }
  };

  if (!props.canWatch) return (
    <div className="mx-auto max-w-md space-y-4 p-6 text-center">
      <h2 className="text-lg font-black">{props.stream.title}</h2>
      <p className="text-sm text-slate-400">This is a Class Pass session.</p>
      <button onClick={props.onBuyPass} className="w-full rounded-xl bg-amber-400 py-3 font-black text-black">
        UNLOCK WITH CLASS PASS ◆
      </button>
      <button onClick={props.onClose} className="text-sm text-slate-500">Back</button>
    </div>
  );

  return (
    <div className="mx-auto max-w-md p-3">
      <div className="relative overflow-hidden rounded-2xl bg-black">
        {phase === 'ad' && preroll ? (
          <div className="relative aspect-video w-full bg-slate-900">
            <span className="absolute left-2 top-2 rounded bg-amber-400 px-1.5 text-[10px] font-black text-black">
              {preroll.kind === 'house' ? 'FEL' : 'AD'}
            </span>
            <div className="flex h-full flex-col items-center justify-center gap-2 p-4 text-center">
              <p className="font-bold">{preroll.headline}</p>
              <p className="text-xs font-black text-cyan-300">{preroll.cta}</p>
            </div>
            <button onClick={() => setPhase('playing')}
              className="absolute bottom-2 right-2 rounded bg-black/70 px-2 py-1 text-[11px] font-bold">
              SKIP ▸
            </button>
          </div>
        ) : (
          <video ref={videoRef} autoPlay playsInline controls className="aspect-video w-full" />
        )}

        {props.stream.state === 'live' && (
          <span className="absolute left-2 top-2 rounded bg-rose-500 px-2 py-0.5 text-[10px] font-black">● LIVE</span>
        )}
        {tipFlash && (
          <span className="absolute bottom-3 left-1/2 -translate-x-1/2 rounded-full bg-amber-400 px-3 py-1 text-xs font-black text-black">
            {tipFlash}
          </span>
        )}
      </div>

      <div className="mt-3 flex items-center justify-between">
        <div>
          <h2 className="font-bold leading-tight">{props.stream.title}</h2>
          {props.stream.viewerCount != null && (
            <p className="text-[11px] text-slate-400">{props.stream.viewerCount} watching</p>
          )}
        </div>
        <div className="flex gap-1">
          {[25, 50, 100] .map((s) => (
            <button key={s} onClick={() => sendTip(s as 25 | 50 | 100)}
              className="rounded-full bg-slate-800 px-3 py-1.5 text-[11px] font-black text-amber-300">
              ◆{s}
            </button>
          ))}
        </div>
      </div>
      <button onClick={props.onClose} className="mt-4 text-sm text-slate-500">← Back to FEL LIVE</button>
    </div>
  );
}
