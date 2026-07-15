'use client';

import { Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { PerformanceMonitor } from '@react-three/drei';
import * as THREE from 'three';
import type { GameProps } from '@/components/games/game-shell';
import { Avatar, type AvatarHandle } from '@/components/three/avatar';
import { DojoLighting, FightCamera, IncenseEmbers } from '@/components/three/dojo-scene';
import { RimGlowPulse } from '@/components/three/effects';
import { PerfSampler } from '@/components/three/perf-hud';
import { MapMesh } from '@/components/three/map-loader';
import { SceneBackdrop } from '@/components/three/scene-backdrop';
import { useOrientation } from '@/components/three/orientation';
import { PERF_BUDGET, gradePerf, type PerfSample } from '@/lib/three-budget';
import { MAPS } from '@/lib/map-data';

const HERO_URL = '/models/elijah.glb';
const MAP = MAPS['dojo'];
const ROUNDS_TO_WIN = 2;

// player faces +X (toward opponent), opponent faces -X
const PLAYER_YAW = -Math.PI / 2;
const FOE_YAW = Math.PI / 2;
const PLAYER_BASE_X = -1.5;
const FOE_BASE_X = 1.5;
const FIGHT_Z = 0;
// The Shimogamo temple is a raised structure — its walkable veranda deck sits
// ~1.25 world units above the model origin (ground/stilt base at y=0).
const DECK_Y = 1.25;

type AiState = 'idle' | 'windup' | 'attack' | 'stunned';

interface HudState {
  round: number; myWins: number; aiWins: number;
  myHp: number; aiHp: number; chi: number;
  aiState: AiState; msg: string; msgColor: string; roundMsg: boolean;
}

function KarateVsScene({
  grade, prq, onEnd, gamepad, onHud, onPerf,
}: GameProps & { onHud: (h: HudState) => void; onPerf: (p: PerfSample) => void }) {
  const player = useRef<AvatarHandle | null>(null);
  const foe = useRef<AvatarHandle | null>(null);
  const onEndRef = useRef(onEnd); onEndRef.current = onEnd;
  const gradeRef = useRef(grade); gradeRef.current = grade;
  const endedRef = useRef(false);

  const dmgMult = grade.key === 'ELITE' ? 1.25 : grade.key === 'PRIMED' ? 1.15 : grade.key === 'READY' ? 1.05 : 1.0;

  const st = useRef({
    round: 1, myWins: 0, aiWins: 0,
    myHp: 100, aiHp: 100, chi: 0, totalDamage: 0,
    aiState: 'idle' as AiState, aiTimer: 1.2, windupLen: 0.9,
    blockHeld: false,
    playerLunge: 0, foeLunge: 0, playerFlinch: 0, foeFlinch: 0,
    msg: '', msgColor: '#FFF', msgTimer: 0, roundMsgTimer: 1.4,
    startTime: Date.now(),
  });

  const showMsg = useCallback((text: string, color: string) => {
    const s = st.current; s.msg = text; s.msgColor = color; s.msgTimer = 0.9;
  }, []);

  const finish = useCallback(() => {
    if (endedRef.current) return;
    endedRef.current = true;
    const s = st.current;
    const won = s.myWins > s.aiWins;
    onEndRef.current?.({
      score: Math.round(s.totalDamage * 10 + s.myWins * 300),
      opponentScore: s.aiWins * 300,
      won,
      duration: Math.round((Date.now() - s.startTime) / 1000),
      headline: won ? `${s.myWins}-${s.aiWins} — SENSEI APPROVED` : `${s.myWins}-${s.aiWins} — MEDITATE AND RETURN`,
    });
  }, []);

  const newRound = useCallback(() => {
    const s = st.current;
    s.myHp = 100; s.aiHp = 100; s.chi = Math.min(s.chi, 50);
    s.aiState = 'idle'; s.aiTimer = 1.2; s.roundMsgTimer = 1.4;
  }, []);

  const endRound = useCallback((playerWon: boolean) => {
    const s = st.current;
    if (playerWon) s.myWins += 1; else s.aiWins += 1;
    if (s.myWins >= ROUNDS_TO_WIN || s.aiWins >= ROUNDS_TO_WIN) { finish(); return; }
    s.round += 1;
    showMsg(playerWon ? 'ROUND WON!' : 'ROUND LOST', playerWon ? '#00FF9D' : '#FF3366');
    newRound();
  }, [finish, newRound, showMsg]);

  const checkHp = useCallback(() => {
    const s = st.current;
    if (s.aiHp <= 0) endRound(true);
    else if (s.myHp <= 0) endRound(false);
  }, [endRound]);

  useEffect(() => {
    const strike = () => {
      const s = st.current;
      if (endedRef.current || s.roundMsgTimer > 0) return;
      s.playerLunge = 1;
      if (s.aiState === 'windup' || s.aiState === 'stunned') {
        const dmg = (s.aiState === 'stunned' ? 18 : 12) * dmgMult;
        s.aiHp -= dmg; s.totalDamage += dmg; s.chi = Math.min(100, s.chi + 18);
        s.foeFlinch = 0.35;
        showMsg(s.aiState === 'stunned' ? 'COUNTER STRIKE!' : 'CLEAN HIT!', '#00FF9D');
        s.aiState = 'idle'; s.aiTimer = 0.8 + Math.random() * 0.8;
      } else if (s.aiState === 'attack') {
        s.myHp -= 10; s.playerFlinch = 0.3; showMsg('TRADED — TOO SLOW', '#FF3366');
        s.aiState = 'idle'; s.aiTimer = 1.0;
      } else {
        if (Math.random() < 0.5) {
          const dmg = 6 * dmgMult; s.aiHp -= dmg; s.totalDamage += dmg; s.chi = Math.min(100, s.chi + 8);
          s.foeFlinch = 0.2; showMsg('JAB +6', '#00E5FF');
        } else { s.myHp -= 8; s.playerFlinch = 0.2; showMsg('PARRIED!', '#FF3366'); }
      }
      checkHp();
    };
    const special = () => {
      const s = st.current;
      if (endedRef.current || s.chi < 100 || s.roundMsgTimer > 0) return;
      s.chi = 0; s.playerLunge = 1.3;
      const dmg = 30 * dmgMult;
      s.aiHp -= dmg; s.totalDamage += dmg; s.foeFlinch = 0.5;
      s.aiState = 'stunned'; s.aiTimer = 1.2;
      showMsg('DRAGON PALM! -30', '#FFD700');
      checkHp();
    };
    const blockOn = () => { st.current.blockHeld = true; };
    const blockOff = () => { st.current.blockHeld = false; };

    const onKeyDown = (e: KeyboardEvent) => {
      if (e.code === 'Space') { e.preventDefault(); if (!e.repeat) strike(); }
      else if (e.code === 'ArrowDown' || e.code === 'KeyB') { e.preventDefault(); blockOn(); }
      else if (e.code === 'ArrowUp' || e.code === 'KeyS') { e.preventDefault(); special(); }
    };
    const onKeyUp = (e: KeyboardEvent) => {
      if (e.code === 'ArrowDown' || e.code === 'KeyB') blockOff();
    };
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    (window as any).__felKarateVs3D = { strike, special, blockOn, blockOff };
    newRound();
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      delete (window as any).__felKarateVs3D;
    };
  }, [dmgMult, checkHp, newRound, showMsg]);

  const gpPrev = useRef({ x: false, y: false, lb: false });

  useFrame((_, dtRaw) => {
    const dt = Math.min(dtRaw, 0.05);
    const s = st.current;
    if (endedRef.current) return;

    if (s.msgTimer > 0) s.msgTimer -= dt;
    if (s.roundMsgTimer > 0) s.roundMsgTimer -= dt;
    if (s.playerLunge > 0) s.playerLunge = Math.max(0, s.playerLunge - dt * 4);
    if (s.foeLunge > 0) s.foeLunge = Math.max(0, s.foeLunge - dt * 4);
    if (s.playerFlinch > 0) s.playerFlinch = Math.max(0, s.playerFlinch - dt * 3);
    if (s.foeFlinch > 0) s.foeFlinch = Math.max(0, s.foeFlinch - dt * 3);

    // gamepad edge-triggered
    if (gamepad) {
      const api = (window as any).__felKarateVs3D;
      if (gamepad.x && !gpPrev.current.x) api?.strike();
      if (gamepad.y && !gpPrev.current.y) api?.special();
      if (gamepad.lb || gamepad.rb) api?.blockOn(); else api?.blockOff();
      gpPrev.current = { x: !!gamepad.x, y: !!gamepad.y, lb: !!(gamepad.lb || gamepad.rb) };
    }

    // AI state machine
    if (s.roundMsgTimer <= 0) {
      s.aiTimer -= dt;
      if (s.aiTimer <= 0) {
        if (s.aiState === 'idle') { s.aiState = 'windup'; s.windupLen = 0.55 + Math.random() * 0.5; s.aiTimer = s.windupLen; }
        else if (s.aiState === 'windup') {
          s.aiState = 'attack'; s.aiTimer = 0.35; s.foeLunge = 1;
          if (s.blockHeld) { s.chi = Math.min(100, s.chi + 12); showMsg('BLOCKED! CHI +12', '#00E5FF'); }
          else { s.myHp -= 14; s.playerFlinch = 0.35; showMsg('HIT! -14', '#FF3366'); checkHp(); }
        } else if (s.aiState === 'attack' || s.aiState === 'stunned') { s.aiState = 'idle'; s.aiTimer = 0.9 + Math.random() * 1.1; }
      }
    }

    // drive avatar transforms — mixer.update handled by Avatar's useFrame
    if (player.current) {
      const lunge = s.playerLunge * 0.9 - s.playerFlinch * 0.4;
      player.current.group.position.set(PLAYER_BASE_X + lunge, DECK_Y, FIGHT_Z);
      player.current.group.rotation.y = PLAYER_YAW + (s.blockHeld ? -0.25 : 0);
    }
    if (foe.current) {
      const lunge = s.foeLunge * 0.9 - s.foeFlinch * 0.4;
      foe.current.group.position.set(FOE_BASE_X - lunge, DECK_Y, FIGHT_Z);
      foe.current.group.rotation.y = FOE_YAW;
    }

    onHud({
      round: s.round, myWins: s.myWins, aiWins: s.aiWins,
      myHp: s.myHp, aiHp: s.aiHp, chi: s.chi,
      aiState: s.aiState, msg: s.msg, msgColor: s.msgColor,
      roundMsg: s.roundMsgTimer > 0,
    });
  });

  return (
    <>
      {MAP.backdrop && (
        <Suspense fallback={null}><SceneBackdrop url={MAP.backdrop} /></Suspense>
      )}
      <Suspense fallback={null}>
        <MapMesh config={MAP} />
      </Suspense>
      <IncenseEmbers count={36} />
      <RimGlowPulse color="#ff4422" position={[-3, 3, 0]} baseIntensity={10} pulseAmp={5} pulseSpeed={1.0} />
      <RimGlowPulse color="#ffaa44" position={[3, 2.5, 0]} baseIntensity={8} pulseAmp={4} pulseSpeed={0.8} />
      <Suspense fallback={null}>
        <Avatar
          url={HERO_URL}
          onReady={(h) => {
            player.current = h;
            h.group.rotation.y = PLAYER_YAW;
            h.group.position.set(PLAYER_BASE_X, DECK_Y, FIGHT_Z);
            h.play('guard', { loop: true, timeScale: 1 });
          }}
        />
      </Suspense>
      <Suspense fallback={null}>
        <Avatar
          url={HERO_URL}
          tint="#ff5a6e"
          onReady={(h) => {
            foe.current = h;
            h.group.rotation.y = FOE_YAW;
            h.group.position.set(FOE_BASE_X, DECK_Y, FIGHT_Z);
            h.play('guard', { loop: true, timeScale: 0.9 });
          }}
        />
      </Suspense>
      <FightCamera position={[0.3, 2.75, 6.1]} target={[0, 2.05, FIGHT_Z]} />
      <PerfSampler onSample={onPerf} />
    </>
  );
}

export default function KarateVersus3D(props: GameProps) {
  const orient = useOrientation();
  const [dpr, setDpr] = useState(1.5);
  const [hud, setHud] = useState<HudState | null>(null);
  const [perf, setPerf] = useState<PerfSample | null>(null);
  const [started, setStarted] = useState(true);
  const [showPerf, setShowPerf] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'p') setShowPerf((v) => !v); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const grade = perf ? gradePerf(perf) : null;

  if (!started) {
    return (
      <div className="relative w-full h-full flex flex-col items-center justify-center gap-4 p-6 text-center" style={{ background: '#080604', minHeight: '60vh' }}>
        <h2 className="fel-heading text-4xl text-white">KARATE VS</h2>
        <p className="max-w-md text-sm text-gray-300">
          Best of 3 vs the Rival Sensei. <span className="text-[#00FF9D]">SPACE</span> strikes — punish gold wind-ups. Hold <span className="text-[#00E5FF]">↓</span> to block red attacks and build chi. Full chi? <span className="text-[#FFD700]">↑</span> unleashes the Dragon Palm.
        </p>
        <button onClick={() => setStarted(true)} className="rounded-lg bg-[#FF3366] px-8 py-3 font-bold text-white transition hover:bg-[#e02050]">BOW &amp; FIGHT</button>
      </div>
    );
  }

  return (
    <div
      className="relative mx-auto w-full overflow-hidden rounded-xl border border-white/5 shadow-[0_0_60px_rgba(0,229,255,0.06)]"
      style={{ aspectRatio: orient === 'portrait' ? '3 / 4' : '16 / 9', maxWidth: orient === 'portrait' ? 560 : 960, background: MAP.fogColor }}
    >
      <Canvas
        dpr={dpr}
        shadows
        gl={{ antialias: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.05, powerPreference: 'high-performance' }}
        camera={{ fov: orient === 'portrait' ? 62 : 50, near: 0.1, far: 200, position: [0.3, 2.75, 6.1] }}
        scene={{ fog: new THREE.Fog(new THREE.Color(MAP.fogColor), MAP.fogNear, MAP.fogFar) }}
      >
        <PerformanceMonitor
          onIncline={() => setDpr((d) => Math.min(d + 0.25, PERF_BUDGET.dprMax))}
          onDecline={() => setDpr((d) => Math.max(d - 0.25, PERF_BUDGET.dprMin))}
        >
          <DojoLighting />
          <KarateVsScene {...props} onHud={setHud} onPerf={setPerf} />
        </PerformanceMonitor>
      </Canvas>

      {hud && (
        <div className="absolute inset-0 pointer-events-none" style={{ fontFamily: 'var(--font-display), sans-serif' }}>
          {/* HP bars */}
          <div className="absolute top-3 left-0 right-0 flex items-start justify-between px-4">
            <div className="w-[42%]">
              <div className="flex justify-between text-xs font-bold text-white/80 mb-1"><span>YOU</span><span>{Math.max(0, Math.round(hud.myHp))}</span></div>
              <div className="h-3 rounded-full bg-black/60 overflow-hidden"><div className="h-full rounded-full bg-[#00FF9D] transition-all" style={{ width: `${Math.max(0, hud.myHp)}%` }} /></div>
            </div>
            <div className="flex flex-col items-center pt-1">
              <span className="text-sm font-bold text-white">ROUND {hud.round}</span>
              <span className="text-xs text-white/60">{hud.myWins} – {hud.aiWins}</span>
            </div>
            <div className="w-[42%]">
              <div className="flex justify-between text-xs font-bold text-white/80 mb-1"><span>{Math.max(0, Math.round(hud.aiHp))}</span><span>RIVAL SENSEI</span></div>
              <div className="h-3 rounded-full bg-black/60 overflow-hidden flex justify-end"><div className="h-full rounded-full bg-[#FF3366] transition-all" style={{ width: `${Math.max(0, hud.aiHp)}%` }} /></div>
            </div>
          </div>

          {/* chi bar */}
          <div className="absolute top-16 left-1/2 -translate-x-1/2 w-52">
            <div className="h-2 rounded-full bg-black/60 overflow-hidden">
              <div className="h-full rounded-full transition-all" style={{ width: `${hud.chi}%`, background: hud.chi >= 100 ? '#FFD700' : '#A855F7' }} />
            </div>
            {hud.chi >= 100 && <div className="text-center text-[11px] font-mono text-[#FFD700] mt-1 animate-pulse">DRAGON PALM READY — ↑</div>}
          </div>

          {/* telegraphs */}
          {hud.aiState === 'windup' && !hud.roundMsg && (
            <div className="absolute top-1/3 left-1/2 -translate-x-1/2 text-lg font-bold text-[#FFD700] animate-pulse">⚠ INCOMING — BLOCK OR COUNTER!</div>
          )}
          {hud.aiState === 'stunned' && !hud.roundMsg && (
            <div className="absolute top-1/3 left-1/2 -translate-x-1/2 text-lg font-bold text-[#A855F7] animate-pulse">STUNNED — STRIKE NOW!</div>
          )}

          {/* round / message banners */}
          {hud.roundMsg ? (
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <div className="text-5xl font-bold text-white">ROUND {hud.round}</div>
              <div className="text-2xl font-bold text-[#FF3366] mt-1">FIGHT!</div>
            </div>
          ) : hud.msg && hud.msgColor ? (
            <div className="absolute top-[42%] left-1/2 -translate-x-1/2">
              <div className="text-2xl font-bold" style={{ color: hud.msgColor, textShadow: `0 0 20px ${hud.msgColor}55` }}>{hud.msg}</div>
            </div>
          ) : null}

          {/* touch controls */}
          <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-2 !hidden pointer-events-auto">
            <button onClick={() => (window as any).__felKarateVs3D?.strike()} className="rounded-lg bg-[#FF3366]/25 px-6 py-4 font-bold text-[#FF3366] active:bg-[#FF3366]/45">STRIKE</button>
            <button onClick={() => {}} onPointerDown={() => (window as any).__felKarateVs3D?.blockOn()} onPointerUp={() => (window as any).__felKarateVs3D?.blockOff()} onPointerLeave={() => (window as any).__felKarateVs3D?.blockOff()} className="rounded-lg bg-[#00E5FF]/25 px-6 py-4 font-bold text-[#00E5FF] active:bg-[#00E5FF]/45">BLOCK</button>
            <button onClick={() => (window as any).__felKarateVs3D?.special()} className="rounded-lg bg-[#FFD700]/25 px-6 py-4 font-bold text-[#FFD700] active:bg-[#FFD700]/45">SPECIAL</button>
          </div>
        </div>
      )}

      {showPerf && perf && grade && (
        <div className="absolute bottom-2 left-2 px-2 py-1 rounded text-xs font-mono"
          style={{ background: 'rgba(0,0,0,0.7)', color: grade.status === 'ok' ? '#00FF9D' : grade.status === 'warn' ? '#FFD700' : '#FF3366' }}>
          {perf.fps}fps · {perf.triangles.toLocaleString()} tris · {perf.calls} draws
        </div>
      )}
    </div>
  );
}
