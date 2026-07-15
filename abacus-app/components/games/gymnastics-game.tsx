'use client';

import { useEffect, useRef, useState } from 'react';
import type { GameProps } from '@/components/games/game-shell';
import { SessionRecorder } from '@/lib/game-systems';

const W = 960;
const H = 540;
const TOTAL_MOVES = 16;
const WIN_SCORE = 800;

const LANES = ['left', 'up', 'down', 'right'] as const;
type Lane = (typeof LANES)[number];
const LANE_X: Record<Lane, number> = { left: W / 2 - 210, up: W / 2 - 70, down: W / 2 + 70, right: W / 2 + 210 };
const LANE_ARROW: Record<Lane, string> = { left: '←', up: '↑', down: '↓', right: '→' };
const MOVE_NAMES = ['ROUND-OFF', 'BACK HANDSPRING', 'FULL TWIST', 'AERIAL', 'TUCK', 'LAYOUT', 'SPLIT LEAP', 'DOUBLE PIKE'];

interface Prompt {
  lane: Lane;
  t: number; // countdown to perfect moment
  window: number;
  hit: boolean;
  missed: boolean;
  name: string;
}

export default function GymnasticsGame({ grade, prq, onEnd, gamepad }: GameProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [started, setStarted] = useState(false);
  const endedRef = useRef(false);
  const onEndRef = useRef(onEnd);
  onEndRef.current = onEnd;
  const gradeRef = useRef(grade);
  gradeRef.current = grade;

  useEffect(() => {
    if (!started) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const bg = new Image();
    bg.src = '/backdrops/gymnastics.jpg';
    let bgReady = false;
    bg.onload = () => { bgReady = true; };

    // higher grade = slightly wider timing windows
    const windowBonus = grade.key === 'ELITE' ? 1.3 : grade.key === 'PRIMED' ? 1.2 : grade.key === 'READY' ? 1.1 : 1.0;

    const startTime = Date.now();
    let moveIdx = 0;
    let judgePts = 0; // out of 10 per move -> avg
    let perfects = 0;
    let greats = 0;
    let goods = 0;
    let misses = 0;
    let combo = 0;
    let bestCombo = 0;
    const rec = new SessionRecorder();
    let current: Prompt | null = null;
    let gapTimer = 0.8;
    let msg = '';
    let msgColor = '#FFFFFF';
    let msgTimer = 0;
    let flourish = 0; // athlete animation phase

    function nextPrompt() {
      const lane = LANES[Math.floor(Math.random() * 4)];
      const speed = Math.max(1.0, 1.9 - moveIdx * 0.05); // gets faster
      current = {
        lane,
        t: speed,
        window: 0.16 * windowBonus,
        hit: false,
        missed: false,
        name: MOVE_NAMES[Math.floor(Math.random() * MOVE_NAMES.length)],
      };
    }

    function judge(result: 'perfect' | 'great' | 'good' | 'miss') {
      moveIdx += 1;
      if (result === 'perfect') { perfects += 1; combo += 1; judgePts += 10; msg = 'PERFECT 10!'; msgColor = '#FFD700'; }
      else if (result === 'great') { greats += 1; combo += 1; judgePts += 8; msg = 'GREAT 8.0'; msgColor = '#00FF9D'; }
      else if (result === 'good') { goods += 1; combo = 0; judgePts += 5; msg = 'GOOD 5.0'; msgColor = '#00E5FF'; }
      else { misses += 1; combo = 0; judgePts += 1; msg = 'STUMBLE 1.0'; msgColor = '#FF3366'; }
      bestCombo = Math.max(bestCombo, combo);
      if (result === 'perfect' || result === 'great') { rec.recordHit(result === 'perfect'); rec.recordChain(combo); }
      else if (result === 'good') { rec.recordHit(); }
      else { rec.recordMiss(); }
      msgTimer = 0.9;
      flourish = 1;
      current = null;
      gapTimer = 0.55;
      if (moveIdx >= TOTAL_MOVES) finish();
    }

    function hit(lane: Lane) {
      if (endedRef.current || !current || current.hit || current.missed) return;
      if (lane !== current.lane) { current.missed = true; judge('miss'); return; }
      const err = Math.abs(current.t);
      if (err <= current.window * 0.45) judge('perfect');
      else if (err <= current.window) judge('great');
      else if (err <= current.window * 2.2) judge('good');
      else { judge('miss'); }
    }

    function finish() {
      if (endedRef.current) return;
      endedRef.current = true;
      const judgeScore = judgePts / TOTAL_MOVES; // 0..10
      const score = Math.round(judgeScore * 100 + bestCombo * 10);
      const won = score >= WIN_SCORE;
      onEndRef.current?.({
        score,
        won,
        duration: Math.round((Date.now() - startTime) / 1000),
        headline: won ? `JUDGES SCORE ${judgeScore.toFixed(1)} — GOLD ROUTINE` : `JUDGES SCORE ${judgeScore.toFixed(1)} — KEEP TRAINING`,
        tallies: rec.tallies(), maxCombo: rec.bestChain,
      });
    }

    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'ArrowLeft') { e.preventDefault(); hit('left'); }
      else if (e.code === 'ArrowUp') { e.preventDefault(); hit('up'); }
      else if (e.code === 'ArrowDown') { e.preventDefault(); hit('down'); }
      else if (e.code === 'ArrowRight') { e.preventDefault(); hit('right'); }
    };
    window.addEventListener('keydown', onKey);
    (canvas as any).felGym = { hit };

    let raf = 0;
    let last = performance.now();

    const loop = (now: number) => {
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      if (msgTimer > 0) msgTimer -= dt;
      if (flourish > 0) flourish = Math.max(0, flourish - dt * 2);

      if (!endedRef.current) {
        if (current) {
          current.t -= dt;
          if (current.t < -current.window * 2.2 && !current.hit && !current.missed) {
            current.missed = true;
            judge('miss');
          }
        } else {
          gapTimer -= dt;
          if (gapTimer <= 0 && moveIdx < TOTAL_MOVES) nextPrompt();
        }
      }

      // ===== draw =====
      ctx.clearRect(0, 0, W, H);
      if (bgReady) {
        ctx.drawImage(bg, 0, 0, W, H);
        ctx.fillStyle = 'rgba(8,5,12,0.5)';
        ctx.fillRect(0, 0, W, H);
      } else {
        ctx.fillStyle = '#120A1C';
        ctx.fillRect(0, 0, W, H);
      }

      // floor mat
      ctx.fillStyle = 'rgba(168,85,247,0.18)';
      ctx.fillRect(W / 2 - 330, H - 130, 660, 90);
      ctx.strokeStyle = 'rgba(168,85,247,0.5)';
      ctx.strokeRect(W / 2 - 330, H - 130, 660, 90);

      // athlete (simple dynamic figure)
      const ax = W / 2;
      const ay = H - 150 - flourish * 60;
      ctx.strokeStyle = '#FFFFFF';
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.arc(ax, ay - 42, 12, 0, Math.PI * 2); // head
      ctx.moveTo(ax, ay - 30);
      ctx.lineTo(ax, ay); // torso
      const spin = flourish * Math.PI;
      ctx.moveTo(ax, ay - 22);
      ctx.lineTo(ax - 22 * Math.cos(spin), ay - 22 - 18 * Math.sin(spin));
      ctx.moveTo(ax, ay - 22);
      ctx.lineTo(ax + 22 * Math.cos(spin), ay - 22 - 18 * Math.sin(spin));
      ctx.moveTo(ax, ay);
      ctx.lineTo(ax - 14, ay + 30 - flourish * 10);
      ctx.moveTo(ax, ay);
      ctx.lineTo(ax + 14, ay + 30 - flourish * 10);
      ctx.stroke();

      // lane targets
      for (const lane of LANES) {
        const lx = LANE_X[lane];
        const ly = H / 2 - 20;
        ctx.strokeStyle = 'rgba(255,255,255,0.3)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(lx, ly, 34, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fillStyle = 'rgba(255,255,255,0.5)';
        ctx.font = 'bold 26px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(LANE_ARROW[lane], lx, ly);
        ctx.textBaseline = 'alphabetic';
      }

      // active prompt: shrinking ring
      if (current) {
        const lx = LANE_X[current.lane];
        const ly = H / 2 - 20;
        const r = 34 + Math.max(0, current.t) * 120;
        const inWindow = Math.abs(current.t) <= current.window;
        ctx.strokeStyle = inWindow ? '#FFD700' : '#A855F7';
        ctx.lineWidth = inWindow ? 5 : 3;
        ctx.beginPath();
        ctx.arc(lx, ly, r, 0, Math.PI * 2);
        ctx.stroke();
        ctx.fillStyle = inWindow ? '#FFD700' : '#FFFFFF';
        ctx.font = 'bold 34px sans-serif';
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(LANE_ARROW[current.lane], lx, ly);
        ctx.textBaseline = 'alphabetic';
        // move name
        ctx.fillStyle = '#A855F7';
        ctx.font = 'bold 22px "Barlow Condensed", sans-serif';
        ctx.fillText(current.name, W / 2, H / 2 - 110);
      }

      // HUD
      ctx.fillStyle = 'rgba(5,5,5,0.72)';
      ctx.fillRect(W * 0.2, 10, W * 0.6, 52);
      ctx.strokeStyle = 'rgba(168,85,247,0.4)';
      ctx.strokeRect(W * 0.2, 10, W * 0.6, 52);
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 22px "Barlow Condensed", sans-serif';
      ctx.textAlign = 'left';
      ctx.fillText(`JUDGE ${(judgePts / Math.max(1, moveIdx) || 0).toFixed(1)}`, W * 0.2 + 16, 44);
      ctx.textAlign = 'center';
      ctx.fillText(`MOVE ${Math.min(moveIdx + 1, TOTAL_MOVES)}/${TOTAL_MOVES}`, W / 2, 44);
      ctx.textAlign = 'right';
      ctx.fillStyle = combo >= 3 ? '#FFD700' : '#FFFFFF';
      ctx.fillText(`COMBO x${combo}`, W * 0.8 - 16, 44);

      ctx.fillStyle = 'rgba(0,229,255,0.8)';
      ctx.font = '12px "JetBrains Mono", monospace';
      ctx.textAlign = 'right';
      ctx.fillText(`PRQ ${prq.toFixed(0)} · ${gradeRef.current.label}`, W - 14, 24);

      if (msgTimer > 0) {
        ctx.fillStyle = msgColor;
        ctx.font = 'bold 34px "Barlow Condensed", sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(msg, W / 2, H / 2 + 70);
      }

      if (!endedRef.current) raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener('keydown', onKey);
      delete (canvas as any).felGym;
    };
  }, [started, prq]);

  return (
    <div className="relative w-full">
      <div className="relative w-full overflow-hidden rounded-xl border border-white/10 bg-[#120A1C]" style={{ aspectRatio: '16/9' }}>
        <canvas ref={canvasRef} width={W} height={H} className="h-full w-full" />
        {!started && (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 bg-black/80 p-6 text-center">
            <h2 className="fel-heading text-4xl text-white">FLOOR ROUTINE</h2>
            <p className="max-w-md text-sm text-gray-300">
              16 moves. When a ring shrinks onto an arrow, press that <span className="text-[#A855F7]">ARROW KEY</span> — nail the gold moment for a PERFECT 10. The judges average every move. Score {WIN_SCORE}+ to win.
            </p>
            <button
              onClick={() => setStarted(true)}
              className="rounded-lg bg-[#A855F7] px-8 py-3 font-bold text-white transition hover:bg-[#9333ea]"
            >
              SALUTE THE JUDGES
            </button>
          </div>
        )}
      </div>
      <div className="mt-3 flex justify-center gap-2 !hidden">
        {LANES.map((lane) => (
          <button
            key={lane}
            className="rounded-lg bg-[#A855F7]/20 px-6 py-4 text-xl font-bold text-[#A855F7] active:bg-[#A855F7]/40"
            onClick={() => (canvasRef.current as any)?.felGym?.hit(lane)}
          >
            {LANE_ARROW[lane]}
          </button>
        ))}
      </div>
    </div>
  );
}
