'use client';

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { PerformanceMonitor } from '@react-three/drei';
import * as THREE from 'three';
import type { GameProps } from '@/components/games/game-shell';
import { Avatar, type AvatarHandle } from '@/components/three/avatar';
import { SceneLighting } from '@/components/three/lighting';
import { FollowCamera } from '@/components/three/follow-camera';
import { PerfSampler } from '@/components/three/perf-hud';
import { MapMesh } from '@/components/three/map-loader';
import { SceneBackdrop } from '@/components/three/scene-backdrop';
import { PremiumHoop, CourtLineOverlay, DustMotes, HoopGlow, Basketball } from '@/components/three/basketball-court';
import { RimGlowPulse } from '@/components/three/effects';
import { useOrientation } from '@/components/three/orientation';
import { PERF_BUDGET, gradePerf, type PerfSample } from '@/lib/three-budget';
import { MAPS } from '@/lib/map-data';

const MODEL_URL = '/models/elijah.glb';
const MODEL_YAW = Math.PI;
const SUB_START = 488, SUB_END = 582, CLIP_FPS = 30;
const MAP = MAPS['venice-blacktop'];
const RACKS = 5;
const BALLS_PER_RACK = 5;
const GAME_LEN = 60;
const WIN_PTS = 18;

// Rack positions around the 3-point arc
const RACK_POSITIONS: [number, number, number][] = [
  [-5.5, 0, 4],  // left corner
  [-3, 0, 7],    // left wing
  [0, 0, 8],     // top
  [3, 0, 7],     // right wing
  [5.5, 0, 4],   // right corner
];

interface HudState {
  pts: number; rack: number; ball: number; timeLeft: number;
  streak: number; barVal: number; isMoneyBall: boolean; inFlight: boolean;
  msg: string; msgColor: string;
}

function ThreePointScene({
  grade, prq, onEnd, gamepad, orientation, onHud, onPerf,
}: GameProps & {
  orientation: 'landscape' | 'portrait';
  onHud: (h: HudState) => void;
  onPerf: (p: PerfSample) => void;
}) {
  const avatar = useRef<AvatarHandle | null>(null);
  const ballRef = useRef<THREE.Mesh>(null);
  const camTarget = useRef(new THREE.Vector3(0, 1.1, 6));
  const onEndRef = useRef(onEnd); onEndRef.current = onEnd;
  const gradeRef = useRef(grade); gradeRef.current = grade;
  const endedRef = useRef(false);

  const sweet = grade.key === 'ELITE' ? 0.16 : grade.key === 'PRIMED' ? 0.13 : grade.key === 'READY' ? 0.11 : 0.09;

  const st = useRef({
    timeLeft: GAME_LEN,
    rack: 0, ball: 0, pts: 0, makes: 0, streak: 0,
    barT: 0, anim: -1, animMade: false,
    msg: '', msgColor: '#FFF', msgTimer: 0,
    startTime: Date.now(),
  });

  const finish = useCallback(() => {
    if (endedRef.current) return;
    endedRef.current = true;
    const s = st.current;
    const won = s.pts >= WIN_PTS;
    onEndRef.current?.({
      score: s.pts * 40 + s.streak * 10,
      won,
      duration: Math.round((Date.now() - s.startTime) / 1000),
      headline: won ? `${s.pts} PTS — RANGE UNLOCKED` : `${s.pts} PTS — KEEP SHOOTING`,
    });
  }, []);

  const advance = useCallback(() => {
    const s = st.current;
    s.ball += 1;
    if (s.ball >= BALLS_PER_RACK) {
      s.ball = 0;
      s.rack += 1;
      if (s.rack >= RACKS) { finish(); return; }
    }
    s.barT = Math.random() * Math.PI;
    // Move avatar to next rack position
    if (avatar.current) {
      const pos = RACK_POSITIONS[s.rack] || RACK_POSITIONS[0];
      avatar.current.group.position.set(pos[0], pos[1], pos[2]);
      camTarget.current.set(pos[0], 1.1, pos[2]);
    }
  }, [finish]);

  useEffect(() => {
    const shoot = () => {
      if (endedRef.current) return;
      const s = st.current;
      if (s.anim >= 0) return;
      const p = Math.abs(Math.sin(s.barT));
      const err = Math.abs(p - 0.72);
      s.animMade = err < sweet;
      const perfect = err < sweet * 0.4;
      s.anim = 0;
      if (s.animMade) {
        const v = s.ball === BALLS_PER_RACK - 1 ? 2 : 1;
        s.pts += v; s.makes += 1; s.streak += 1;
        s.msg = perfect ? `SWISH +${v}` : `GOOD +${v}`;
        s.msgColor = perfect ? '#FFD700' : '#00FF9D';
      } else {
        s.streak = 0;
        s.msg = 'OFF THE IRON';
        s.msgColor = '#FF3366';
      }
      s.msgTimer = 0.8;
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Space') { e.preventDefault(); shoot(); }
    };
    window.addEventListener('keydown', onKey);
    (window as any).__fel3pt = { shoot };
    return () => {
      window.removeEventListener('keydown', onKey);
      delete (window as any).__fel3pt;
    };
  }, [sweet, advance]);

  useFrame((_, dtRaw) => {
    const dt = Math.min(dtRaw, 0.05);
    const s = st.current;
    if (endedRef.current) return;

    s.timeLeft -= dt;
    if (s.timeLeft <= 0) { finish(); return; }
    if (s.msgTimer > 0) s.msgTimer -= dt;

    if (s.anim >= 0) {
      s.anim += dt * 1.6;
      if (s.anim >= 1) { s.anim = -1; advance(); if (endedRef.current) return; }
    } else {
      s.barT += dt * (3.0 + s.rack * 0.25);
    }

    if (avatar.current) avatar.current.mixer.update(dt * 0.3);

    // Ball: in flight or at player
    if (ballRef.current) {
      if (s.anim >= 0) {
        const pos = RACK_POSITIONS[s.rack] || RACK_POSITIONS[0];
        const p = Math.min(s.anim, 1);
        const bx = pos[0] + (0 - pos[0]) * p;
        const bz = pos[2] + (0 - pos[2]) * p;
        const by = 1.5 + Math.sin(p * Math.PI) * 3 + p * 1.5;
        ballRef.current.position.set(bx, s.animMade ? by : by - p * 2, bz);
      } else {
        const pos = RACK_POSITIONS[s.rack] || RACK_POSITIONS[0];
        ballRef.current.position.set(pos[0] + 0.3, 1.0, pos[2]);
      }
    }

    onHud({
      pts: s.pts, rack: s.rack, ball: s.ball, timeLeft: s.timeLeft,
      streak: s.streak, barVal: Math.abs(Math.sin(s.barT)),
      isMoneyBall: s.ball === BALLS_PER_RACK - 1, inFlight: s.anim >= 0,
      msg: s.msg, msgColor: s.msgColor,
    });
  });

  const camOffset = useMemo(
    () => orientation === 'portrait' ? new THREE.Vector3(2.0, 3.5, 5) : new THREE.Vector3(4, 3, 4),
    [orientation]
  );

  // Position avatar at first rack on load
  useEffect(() => {
    camTarget.current.set(RACK_POSITIONS[0][0], 1.1, RACK_POSITIONS[0][2]);
  }, []);

  return (
    <>
      {MAP.backdrop && (
        <Suspense fallback={null}><SceneBackdrop url={MAP.backdrop} /></Suspense>
      )}
      <Suspense fallback={null}><MapMesh config={MAP} /></Suspense>
      <CourtLineOverlay />
      <PremiumHoop />
      <HoopGlow />
      <DustMotes count={50} />
      <RimGlowPulse color="#00e5ff" position={[-5, 3, -2]} baseIntensity={12} pulseAmp={6} />
      <RimGlowPulse color="#ff3366" position={[5, 2.5, 0]} baseIntensity={10} pulseAmp={5} />
      <Basketball ballRef={ballRef} />
      <Suspense fallback={null}>
        <Avatar url={MODEL_URL} subStartFrame={SUB_START} subEndFrame={SUB_END} clipFps={CLIP_FPS}
          onReady={(h) => {
            avatar.current = h;
            h.group.rotation.y = MODEL_YAW;
            const pos = RACK_POSITIONS[0];
            h.group.position.set(pos[0], pos[1], pos[2]);
            if (h.action) { h.action.setLoop(THREE.LoopRepeat, Infinity); h.action.timeScale = 0.3; h.action.play(); }
          }} />
      </Suspense>
      <FollowCamera target={camTarget} offset={camOffset}
        boundsMin={new THREE.Vector3(...MAP.boundsMin)} boundsMax={new THREE.Vector3(...MAP.boundsMax)}
        floorY={MAP.floorY} ceilingY={MAP.ceilingY} />
      <PerfSampler onSample={onPerf} />
    </>
  );
}

export default function ThreePoint3D(props: GameProps) {
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
  const sweet = props.grade.key === 'ELITE' ? 0.16 : props.grade.key === 'PRIMED' ? 0.13 : props.grade.key === 'READY' ? 0.11 : 0.09;

  if (!started) {
    return (
      <div className="relative w-full h-full flex flex-col items-center justify-center gap-4 p-6 text-center" style={{ background: '#050508', minHeight: '60vh' }}>
        <h2 className="fel-heading text-4xl text-white">THREE-POINT SHOOTOUT</h2>
        <p className="max-w-md text-sm text-gray-300">
          5 racks, 5 balls each, 60 seconds. Tap <span className="text-[#00E5FF]">SPACE</span> at the gold line. The last ball is a <span className="text-[#FFD700]">MONEY BALL</span> worth 2. Hit {WIN_PTS}+ to win.
        </p>
        <button onClick={() => setStarted(true)} className="rounded-lg bg-[#00E5FF] px-8 py-3 font-bold text-black transition hover:bg-[#00c9e0]">LIGHT IT UP</button>
      </div>
    );
  }

  return (
    <div
      className="relative mx-auto w-full overflow-hidden rounded-xl border border-white/5 shadow-[0_0_60px_rgba(0,229,255,0.06)]"
      style={{ aspectRatio: orient === 'portrait' ? '3 / 4' : '16 / 9', maxWidth: orient === 'portrait' ? 560 : 960, background: MAP.fogColor }}
    >
      <Canvas dpr={dpr} shadows
        gl={{ antialias: true, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.1, powerPreference: 'high-performance' }}
        camera={{ fov: orient === 'portrait' ? 65 : 55, near: 0.1, far: 200, position: [0, 3, 12] }}
        scene={{ fog: new THREE.Fog(new THREE.Color(MAP.fogColor), MAP.fogNear, MAP.fogFar) }}>
        <PerformanceMonitor
          onIncline={() => setDpr((d) => Math.min(d + 0.25, PERF_BUDGET.dprMax))}
          onDecline={() => setDpr((d) => Math.max(d - 0.25, PERF_BUDGET.dprMin))}>
          <SceneLighting />
          <ThreePointScene {...props} orientation={orient} onHud={setHud} onPerf={setPerf} />
        </PerformanceMonitor>
      </Canvas>

      {hud && (
        <div className="absolute inset-0 pointer-events-none" style={{ fontFamily: 'var(--font-display), sans-serif' }}>
          {/* Scoreboard */}
          <div className="absolute top-3 left-1/2 -translate-x-1/2 flex items-center gap-4 px-5 py-2 rounded-xl" style={{ background: 'rgba(5,5,8,0.75)', backdropFilter: 'blur(12px)', border: '1px solid rgba(0,229,255,0.2)' }}>
            <span className="text-xl font-bold text-white">PTS {hud.pts}</span>
            <span className="text-xs text-white/50">RACK {hud.rack + 1}/{RACKS} · ⏱ {Math.ceil(hud.timeLeft)}s</span>
            <span className={`text-xl font-bold ${hud.streak >= 3 ? 'text-[#FFD700]' : 'text-white'}`}>x{hud.streak}</span>
          </div>

          {/* Rack indicator */}
          <div className="absolute top-14 left-1/2 -translate-x-1/2 flex gap-2">
            {Array.from({ length: BALLS_PER_RACK }).map((_, i) => (
              <div key={i} className={`w-3 h-3 rounded-full ${
                i < hud.ball ? 'bg-white/20' :
                i === BALLS_PER_RACK - 1 ? 'bg-[#FFD700]' : 'bg-[#FF6B35]'
              }`} />
            ))}
          </div>

          {/* Power bar */}
          {!hud.inFlight && (
            <div className="absolute bottom-24 left-1/2 -translate-x-1/2 w-80 text-center pointer-events-auto">
              <div className="text-xs text-white font-mono mb-2" style={{ textShadow: '0 1px 4px rgba(0,0,0,0.9), 0 0 8px rgba(0,0,0,0.7)' }}>
                {hud.isMoneyBall ? '💰 MONEY BALL — WORTH 2!' : 'SPACE AT THE GOLD LINE'}
              </div>
              <div className="relative h-3 rounded-full bg-black/60 overflow-hidden">
                <div className="absolute h-full bg-[#00FF9D]/30" style={{ left: `${(0.72 - sweet) * 100}%`, width: `${sweet * 200}%` }} />
                <div className="absolute h-full w-0.5 bg-[#FFD700]" style={{ left: '72%' }} />
                <div className="h-full rounded-full bg-[#00E5FF]" style={{ width: `${hud.barVal * 100}%` }} />
              </div>
              <button onClick={() => (window as any).__fel3pt?.shoot()}
                className="mt-3 px-10 py-3 rounded-xl bg-[#00E5FF]/20 text-[#00E5FF] font-bold !hidden active:bg-[#00E5FF]/40">
                SHOOT
              </button>
            </div>
          )}

          {/* Score message */}
          {hud.msg && hud.msgColor && (
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-3xl font-bold" style={{ color: hud.msgColor, textShadow: `0 0 20px ${hud.msgColor}40`, opacity: Math.min(1, (hud.pts > 0 || hud.msg.includes('OFF')) ? 1 : 0) }}>{hud.msg}</div>
            </div>
          )}
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
