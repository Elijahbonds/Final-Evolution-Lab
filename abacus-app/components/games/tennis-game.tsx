'use client';

import { useEffect, useRef, useState } from 'react';
import type { GameProps } from '@/components/games/game-shell';
import { SessionRecorder } from '@/lib/game-systems';

export default function TennisGame({ grade, prq, onEnd, gamepad }: GameProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [started, setStarted] = useState(false);
  const endedRef = useRef(false);
  const stateRef = useRef<any>(null);
  const onEndRef = useRef(onEnd);
  onEndRef.current = onEnd;
  const gradeRef = useRef(grade);
  gradeRef.current = grade;

  useEffect(() => {
    if (!started) return;
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext?.('2d');
    if (!canvas || !ctx) return;
    const W = 960, H = 540;
    canvas.width = W; canvas.height = H;

    const bg = new Image();
    bg.src = '/backdrops/tennis.jpg';

    const st: any = {
      px: W / 2, py: H - 60, ox: W / 2, oy: 60,
      bx: W / 2, by: H - 90, bvx: 0, bvy: 0, spin: 0, live: false, server: 'player',
      pScore: 0, oScore: 0, msg: 'YOUR SERVE — CLICK/TAP OR SPACE', msgT: 99,
      aiSkill: 0.55, last: 0, startTime: Date.now(), rally: 0, flash: 0,
      keys: {} as Record<string, boolean>, pointerX: null as number | null, rec: new SessionRecorder(),
    };

    const speedMult = gradeRef.current?.speedMult ?? 1;

    const serve = () => {
      if (st.live) return;
      st.live = true; st.rally = 0;
      if (st.server === 'player') { st.bx = st.px; st.by = st.py - 20; st.bvy = -430; st.bvx = (Math.random() - 0.5) * 160; }
      else { st.bx = st.ox; st.by = st.oy + 20; st.bvy = 430; st.bvx = (Math.random() - 0.5) * 160; }
      st.msgT = 0;
    };

    const kd = (e: KeyboardEvent) => {
      const k = e?.key?.toLowerCase?.() ?? '';
      st.keys[k] = true;
      if (k === ' ') { e.preventDefault?.(); serve(); }
    };
    const ku = (e: KeyboardEvent) => { st.keys[e?.key?.toLowerCase?.() ?? ''] = false; };
    window.addEventListener('keydown', kd);
    window.addEventListener('keyup', ku);

    const onPointer = (e: PointerEvent) => {
      const rect = canvas.getBoundingClientRect();
      if (!rect?.width) return;
      st.pointerX = ((e.clientX - rect.left) / rect.width) * W;
    };
    const onTap = () => serve();
    canvas.addEventListener('pointermove', onPointer);
    canvas.addEventListener('pointerdown', onTap);
    stateRef.current = st;
    (canvas as any).felServe = serve;

    const pointWon = (who: 'player' | 'ai') => {
      st.live = false;
      if (who === 'player') { st.pScore++; st.rec.recordHit(); st.rec.recordChain(st.rally); } else { st.oScore++; st.rec.recordMiss(); }
      st.server = who;
      st.msg = who === 'player' ? 'POINT — YOU!' : 'POINT — RIVAL';
      st.msgT = 1.4; st.flash = 0.15;
      // DDA: AI adapts to score gap
      const gap = st.pScore - st.oScore;
      st.aiSkill = Math.max(0.35, Math.min(0.85, 0.55 + gap * 0.08));
      setTimeout(() => { if (!endedRef.current) { st.msg = `${st.server === 'player' ? 'YOUR' : 'RIVAL'} SERVE${st.server === 'player' ? ' — TAP/SPACE' : ''}`; st.msgT = 99; if (st.server === 'ai') setTimeout(serve, 900); } }, 900);
    };

    let raf = 0;
    const loop = (now: number) => {
      if (endedRef.current) return;
      const dt = Math.min((now - (st.last || now)) / 1000, 0.05);
      st.last = now;
      if (st.flash > 0) st.flash -= dt;
      const elapsed = (Date.now() - st.startTime) / 1000;

      // player movement
      const mv = 420 * speedMult;
      if (st.keys['a'] || st.keys['arrowleft']) st.px -= mv * dt;
      if (st.keys['d'] || st.keys['arrowright']) st.px += mv * dt;
      if (st.pointerX != null) st.px += (st.pointerX - st.px) * Math.min(dt * 10, 1);
      st.px = Math.max(70, Math.min(W - 70, st.px));

      if (st.live) {
        // ball physics with spin curve
        st.bvx += st.spin * 60 * dt;
        st.bx += st.bvx * dt; st.by += st.bvy * dt;
        if (st.bx < 30 || st.bx > W - 30) st.bvx *= -1;

        // AI tracking
        const aiSpeed = 260 * (0.6 + st.aiSkill);
        const targetX = st.bvy < 0 ? st.bx : W / 2;
        st.ox += Math.max(-aiSpeed * dt, Math.min(aiSpeed * dt, targetX - st.ox));
        st.ox = Math.max(70, Math.min(W - 70, st.ox));

        // player hit
        if (st.by > st.py - 34 && st.bvy > 0) {
          if (Math.abs(st.bx - st.px) < 78) {
            st.bvy = -(400 + Math.random() * 120 + st.rally * 8);
            st.bvx = (st.bx - st.px) * 5.2;
            st.spin = st.keys['q'] ? -2 : st.keys['e'] ? 2 : (Math.random() - 0.5);
            st.rally++;
          } else if (st.by > H + 20) {
            pointWon('ai');
          }
        }
        // AI hit
        if (st.by < st.oy + 34 && st.bvy < 0) {
          const reach = 60 + st.aiSkill * 40;
          if (Math.abs(st.bx - st.ox) < reach && Math.random() < 0.75 + st.aiSkill * 0.2) {
            st.bvy = 380 + Math.random() * 130 + st.rally * 7;
            st.bvx = (st.bx - st.ox) * 4.5 + (Math.random() - 0.5) * 180;
            st.spin = (Math.random() - 0.5) * 2;
            st.rally++;
          } else if (st.by < -20) {
            pointWon('player');
          }
        }
        if (st.by > H + 30) pointWon('ai');
        if (st.by < -30) pointWon('player');
      }

      // win conditions: first to 5, or leader at 120s tiebreak
      const target = 5;
      if (!endedRef.current && (st.pScore >= target || st.oScore >= target || (elapsed >= 120 && st.pScore !== st.oScore && !st.live))) {
        endedRef.current = true;
        onEndRef.current?.({
          score: st.pScore, opponentScore: st.oScore, won: st.pScore > st.oScore,
          duration: Math.round(elapsed),
          headline: st.pScore > st.oScore ? 'MATCH WON' : 'MATCH LOST',
          tallies: st.rec.tallies(), maxCombo: st.rec.bestChain,
        });
        return;
      }

      // RENDER
      ctx.clearRect(0, 0, W, H);
      if (bg.complete && bg.naturalWidth > 0) { ctx.drawImage(bg, 0, 0, W, H); ctx.fillStyle = 'rgba(5,10,8,0.66)'; ctx.fillRect(0, 0, W, H); }
      else { ctx.fillStyle = '#071410'; ctx.fillRect(0, 0, W, H); }
      // court
      ctx.fillStyle = 'rgba(13,51,39,0.82)'; ctx.fillRect(50, 20, W - 100, H - 40);
      ctx.strokeStyle = 'rgba(255,255,255,0.65)'; ctx.lineWidth = 2;
      ctx.strokeRect(50, 20, W - 100, H - 40);
      ctx.strokeRect(140, 20, W - 280, H - 40);
      ctx.beginPath(); ctx.moveTo(50, H / 2); ctx.lineTo(W - 50, H / 2); ctx.stroke();
      ctx.setLineDash([6, 8]); ctx.beginPath(); ctx.moveTo(W / 2, 20); ctx.lineTo(W / 2, H - 20); ctx.stroke(); ctx.setLineDash([]);
      // net band
      ctx.fillStyle = 'rgba(0,229,255,0.25)'; ctx.fillRect(50, H / 2 - 3, W - 100, 6);

      // opponent paddle/player
      ctx.save();
      ctx.shadowColor = '#FF3366'; ctx.shadowBlur = 14;
      ctx.fillStyle = '#FF3366';
      ctx.beginPath(); ctx.arc(st.ox, st.oy, 14, 0, Math.PI * 2); ctx.fill();
      ctx.fillRect(st.ox - 40, st.oy + 16, 80, 6);
      ctx.restore();
      // player
      const auraColor = gradeRef.current?.color ?? '#00E5FF';
      ctx.save();
      ctx.shadowColor = auraColor; ctx.shadowBlur = 16;
      ctx.fillStyle = '#EDEDF2';
      ctx.beginPath(); ctx.arc(st.px, st.py, 14, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = auraColor;
      ctx.fillRect(st.px - 44, st.py - 22, 88, 6);
      ctx.restore();
      // ball
      if (st.live) {
        ctx.save(); ctx.shadowColor = '#D8FF3E'; ctx.shadowBlur = 12;
        ctx.fillStyle = '#D8FF3E';
        ctx.beginPath(); ctx.arc(st.bx, st.by, 8, 0, Math.PI * 2); ctx.fill();
        ctx.restore();
      }

      // HUD
      ctx.fillStyle = 'rgba(15,15,19,0.85)'; ctx.fillRect(W * 0.2, 8, W * 0.6, 52);
      ctx.strokeStyle = 'rgba(255,255,255,0.1)'; ctx.strokeRect(W * 0.2, 8, W * 0.6, 52);
      ctx.textAlign = 'center'; ctx.font = 'bold 28px "JetBrains Mono", monospace';
      ctx.fillStyle = '#00E5FF'; ctx.fillText(String(st.pScore), W / 2 - 80, 46);
      ctx.fillStyle = '#FF3366'; ctx.fillText(String(st.oScore), W / 2 + 80, 46);
      ctx.fillStyle = '#fff'; ctx.font = '600 14px "Barlow Condensed", sans-serif';
      const clock = Math.max(0, 120 - Math.floor(elapsed));
      ctx.fillText(`MATCH PLAY · FIRST TO 5 · ${String(Math.floor(clock / 60))}:${String(clock % 60).padStart(2, '0')}`, W / 2, 22);
      ctx.textAlign = 'right'; ctx.font = '12px "JetBrains Mono", monospace';
      ctx.fillStyle = gradeRef.current?.color ?? '#00FF9D';
      ctx.fillText(`PRQ ${Math.round(prq)} · ${gradeRef.current?.label ?? ''}`, W - 60, 24);
      ctx.fillStyle = 'rgba(255,255,255,0.55)';
      ctx.fillText(`RALLY ${st.rally} · AI ${(st.aiSkill * 100).toFixed(0)}%`, W - 60, 42);
      if (st.msgT > 0) {
        ctx.textAlign = 'center'; ctx.fillStyle = '#FFD700'; ctx.font = 'bold 26px "Barlow Condensed", sans-serif';
        ctx.fillText(st.msg, W / 2, H / 2 + 46);
      }
      if (st.flash > 0) { ctx.fillStyle = `rgba(255,255,255,${0.3 * (st.flash / 0.15)})`; ctx.fillRect(0, 0, W, H); }

      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', kd);
      window.removeEventListener('keyup', ku);
      canvas.removeEventListener('pointermove', onPointer);
      canvas.removeEventListener('pointerdown', onTap);
    };
  }, [started, prq]);

  return (
    <div className="select-none">
      <div className="relative mx-auto w-full max-w-[960px]">
        <canvas ref={canvasRef} className="w-full rounded-lg border border-white/10 bg-[#0F0F13]" style={{ aspectRatio: '16/9' }} />
        {!started && (
          <div className="absolute inset-0 flex flex-col items-center justify-center rounded-lg bg-black/70 backdrop-blur-sm">
            <h2 className="fel-heading text-4xl font-bold text-white">MATCH PLAY</h2>
            <p className="mt-2 max-w-md text-center text-sm text-white/60">Rally against an adaptive AI. First to 5 points — 120 second tiebreak clock.</p>
            <div className="mt-4 grid grid-cols-2 gap-x-8 gap-y-1 font-mono text-xs text-white/55">
              <span>MOUSE / A D — Move</span><span>SPACE / TAP — Serve</span>
              <span>Q — Slice spin</span><span>E — Topspin</span>
            </div>
            <button onClick={() => setStarted(true)} className="fel-heading mt-6 rounded-md bg-[#00E5FF] px-10 py-3 text-xl font-bold text-black transition-all hover:shadow-[0_0_28px_rgba(0,229,255,0.5)]">
              SERVE
            </button>
          </div>
        )}
      </div>
      {/* mobile touch controls */}
      {started && (
        <div className="mx-auto mt-3 flex max-w-[960px] items-center justify-between gap-2 !hidden">
          <div className="flex gap-2">
            <button onTouchStart={() => { const s = stateRef.current; if (s) s.keys['a'] = true; }} onTouchEnd={() => { const s = stateRef.current; if (s) s.keys['a'] = false; }} className="h-14 w-14 rounded-full border border-white/20 bg-[#16161A] text-xl text-white">◀</button>
            <button onTouchStart={() => { const s = stateRef.current; if (s) s.keys['d'] = true; }} onTouchEnd={() => { const s = stateRef.current; if (s) s.keys['d'] = false; }} className="h-14 w-14 rounded-full border border-white/20 bg-[#16161A] text-xl text-white">▶</button>
          </div>
          <button onTouchStart={() => (canvasRef.current as any)?.felServe?.()} className="h-14 rounded-full border border-[#00E5FF]/50 bg-[#16161A] px-5 text-sm font-bold text-[#00E5FF]">SERVE</button>
        </div>
      )}
    </div>
  );
}
