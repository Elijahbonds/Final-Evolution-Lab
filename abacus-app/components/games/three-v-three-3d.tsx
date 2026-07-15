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
const TARGET = 21;
const GAME_LEN = 90;

type Phase = 'pass' | 'shot' | 'msg';

interface HudState {
  myScore: number; aiScore: number; phase: Phase; timeLeft: number;
  openLane: number; passTimer: number; barVal: number;
  msg: string; msgColor: string;
}

function ThreeVThreeScene({
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

  const sweet = grade.key === 'ELITE' ? 0.2 : grade.key === 'PRIMED' ? 0.17 : grade.key === 'READY' ? 0.14 : 0.12;

  const st = useRef({
    phase: 'pass' as Phase,
    myScore: 0, aiScore: 0, assists: 0,
    timeLeft: GAME_LEN,
    openLane: Math.floor(Math.random() * 3),
    passTimer: 2.0,
    barT: 0,
    shotIsOpen: false,
    msg: '', msgColor: '#FFF', msgTimer: 0,
    aiTick: 0,
    startTime: Date.now(),
  });

  const showMsg = useCallback((text: string, color: string) => {
    const s = st.current;
    s.msg = text; s.msgColor = color; s.msgTimer = 1.0; s.phase = 'msg';
  }, []);

  const newPossession = useCallback(() => {
    const s = st.current;
    s.openLane = Math.floor(Math.random() * 3);
    s.passTimer = 2.0;
    s.phase = 'pass';
  }, []);

  const finish = useCallback(() => {
    if (endedRef.current) return;
    endedRef.current = true;
    const s = st.current;
    const won = s.myScore > s.aiScore;
    onEndRef.current?.({
      score: s.myScore * 100 + s.assists * 30,
      opponentScore: s.aiScore * 100,
      won,
      duration: Math.round((Date.now() - s.startTime) / 1000),
      headline: won ? `${s.myScore}-${s.aiScore} — STREETBALL LEGENDS` : `${s.myScore}-${s.aiScore} — NEXT GAME`,
    });
  }, []);

  useEffect(() => {
    const pass = (lane: number) => {
      if (endedRef.current) return;
      const s = st.current;
      if (s.phase !== 'pass') return;
      if (lane === s.openLane) {
        s.assists += 1;
        s.shotIsOpen = true;
        s.barT = 0;
        s.phase = 'shot';
      } else {
        showMsg('PICKED OFF! TURNOVER', '#FF3366');
        s.aiScore += 2;
      }
    };
    const shoot = () => {
      if (endedRef.current) return;
      const s = st.current;
      if (s.phase !== 'shot') return;
      const p = Math.abs(Math.sin(s.barT));
      const err = Math.abs(p - 0.75);
      const win = sweet * 1.4;
      if (err < win * 0.45) { s.myScore += 3; showMsg('SPLASH! +3', '#FFD700'); }
      else if (err < win) { s.myScore += 2; showMsg('AND ONE! +2', '#00FF9D'); }
      else { showMsg('RIMMED OUT', '#FF3366'); s.aiScore += 1; }
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.code === 'Digit1' || e.code === 'ArrowLeft') { e.preventDefault(); pass(0); }
      else if (e.code === 'Digit2' || e.code === 'ArrowUp') { e.preventDefault(); pass(1); }
      else if (e.code === 'Digit3' || e.code === 'ArrowRight') { e.preventDefault(); pass(2); }
      else if (e.code === 'Space') { e.preventDefault(); shoot(); }
    };
    window.addEventListener('keydown', onKey);
    (window as any).__fel3v3 = { pass, shoot };
    return () => {
      window.removeEventListener('keydown', onKey);
      delete (window as any).__fel3v3;
    };
  }, [sweet, showMsg, finish]);

  useFrame((_, dtRaw) => {
    const dt = Math.min(dtRaw, 0.05);
    const s = st.current;
    if (endedRef.current) return;

    s.timeLeft -= dt;
    if (s.timeLeft <= 0 || s.myScore >= TARGET || s.aiScore >= TARGET) { finish(); return; }

    s.aiTick += dt;
    if (s.aiTick > 8) { s.aiTick = 0; s.aiScore += Math.random() > 0.5 ? 2 : 1; }

    if (s.phase === 'pass') {
      s.passTimer -= dt;
      if (s.passTimer <= 0) { showMsg('SHOT CLOCK! TURNOVER', '#FF3366'); s.aiScore += 1; }
    }
    if (s.phase === 'shot') s.barT += dt * 3.2;
    if (s.phase === 'msg') {
      s.msgTimer -= dt;
      if (s.msgTimer <= 0) newPossession();
    }

    if (avatar.current) avatar.current.mixer.update(dt * 0.3);
    if (ballRef.current) ballRef.current.position.set(0.3, 1.0, 5.8);

    onHud({
      myScore: s.myScore, aiScore: s.aiScore, phase: s.phase, timeLeft: s.timeLeft,
      openLane: s.openLane, passTimer: s.passTimer, barVal: Math.abs(Math.sin(s.barT)),
      msg: s.msg, msgColor: s.msgColor,
    });
  });

  const camOffset = useMemo(
    () => orientation === 'portrait' ? new THREE.Vector3(3.0, 2.7, 6.6) : new THREE.Vector3(3.6, 2.3, 5.4),
    [orientation]
  );

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
          onReady={(h) => { avatar.current = h; h.group.rotation.y = MODEL_YAW; h.group.position.set(0, 0, 6); if (h.action) { h.action.setLoop(THREE.LoopRepeat, Infinity); h.action.timeScale = 0.3; h.action.play(); } }} />
      </Suspense>
      <FollowCamera target={camTarget} offset={camOffset}
        boundsMin={new THREE.Vector3(...MAP.boundsMin)} boundsMax={new THREE.Vector3(...MAP.boundsMax)}
        floorY={MAP.floorY} ceilingY={MAP.ceilingY} />
      <PerfSampler onSample={onPerf} />
    </>
  );
}

export default function ThreeVThree3D(props: GameProps) {
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
  const sweet = props.grade.key === 'ELITE' ? 0.2 : props.grade.key === 'PRIMED' ? 0.17 : props.grade.key === 'READY' ? 0.14 : 0.12;

  if (!started) {
    return (
      <div className="relative w-full h-full flex flex-col items-center justify-center gap-4 p-6 text-center" style={{ background: '#050508', minHeight: '60vh' }}>
        <h2 className="fel-heading text-4xl text-white">3V3 STREETBALL</h2>
        <p className="max-w-md text-sm text-gray-300">
          Find the open man with <span className="text-[#00FF9D]">1 / 2 / 3</span> before the shot clock, then catch-and-shoot with <span className="text-[#00E5FF]">SPACE</span>. First to {TARGET} or best score in {GAME_LEN}s.
        </p>
        <button onClick={() => setStarted(true)} className="rounded-lg bg-[#00E5FF] px-8 py-3 font-bold text-black transition hover:bg-[#00c9e0]">BALL UP</button>
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
        camera={{ fov: orient === 'portrait' ? 65 : 55, near: 0.1, far: 200, position: [3.6, 2.3, 11.4] }}
        scene={{ fog: new THREE.Fog(new THREE.Color(MAP.fogColor), MAP.fogNear, MAP.fogFar) }}>
        <PerformanceMonitor
          onIncline={() => setDpr((d) => Math.min(d + 0.25, PERF_BUDGET.dprMax))}
          onDecline={() => setDpr((d) => Math.max(d - 0.25, PERF_BUDGET.dprMin))}>
          <SceneLighting />
          <ThreeVThreeScene {...props} orientation={orient} onHud={setHud} onPerf={setPerf} />
        </PerformanceMonitor>
      </Canvas>

      {hud && (
        <div className="absolute inset-0 pointer-events-none" style={{ fontFamily: 'var(--font-display), sans-serif' }}>
          {/* Scoreboard */}
          <div className="absolute top-3 left-1/2 -translate-x-1/2 flex items-center gap-4 px-5 py-2 rounded-xl" style={{ background: 'rgba(5,5,8,0.75)', backdropFilter: 'blur(12px)', border: '1px solid rgba(0,229,255,0.2)' }}>
            <span className="text-xl font-bold text-white">SQUAD {hud.myScore}</span>
            <span className="text-xs text-white/50">⏱ {Math.ceil(hud.timeLeft)}s · TO {TARGET}</span>
            <span className="text-xl font-bold text-white">RIVALS {hud.aiScore}</span>
          </div>

          {hud.phase === 'pass' && (
            <div className="absolute bottom-24 left-1/2 -translate-x-1/2 text-center pointer-events-auto">
              <div className="text-xs text-white font-mono mb-3" style={{ textShadow: '0 1px 4px rgba(0,0,0,0.9), 0 0 8px rgba(0,0,0,0.7)' }}>PASS TO THE OPEN MAN</div>
              <div className="flex gap-3">
                {[0, 1, 2].map((i) => (
                  <button key={i} onClick={() => (window as any).__fel3v3?.pass(i)}
                    className={`px-6 py-3 rounded-lg font-bold text-sm transition ${
                      i === hud.openLane
                        ? 'bg-[#00FF9D]/30 text-[#00FF9D] ring-1 ring-[#00FF9D]/50 animate-pulse'
                        : 'bg-white/10 text-white/60'
                    }`}>
                    {i + 1}
                  </button>
                ))}
              </div>
              <div className="mt-2 h-1.5 w-48 mx-auto rounded-full bg-black/60 overflow-hidden">
                <div className="h-full rounded-full bg-[#FFD700]" style={{ width: `${Math.max(0, hud.passTimer / 2) * 100}%` }} />
              </div>
            </div>
          )}

          {hud.phase === 'shot' && (
            <div className="absolute bottom-24 left-1/2 -translate-x-1/2 w-80 text-center pointer-events-auto">
              <div className="text-xs text-white font-mono mb-2" style={{ textShadow: '0 1px 4px rgba(0,0,0,0.9), 0 0 8px rgba(0,0,0,0.7)' }}>CATCH & SHOOT — SPACE AT THE GOLD LINE</div>
              <div className="relative h-3 rounded-full bg-black/60 overflow-hidden">
                <div className="absolute h-full bg-[#00FF9D]/30" style={{ left: `${(0.75 - sweet * 1.4) * 100}%`, width: `${sweet * 280}%` }} />
                <div className="absolute h-full w-0.5 bg-[#FFD700]" style={{ left: '75%' }} />
                <div className="h-full rounded-full bg-[#00E5FF]" style={{ width: `${hud.barVal * 100}%` }} />
              </div>
              <button onClick={() => (window as any).__fel3v3?.shoot()}
                className="mt-3 px-10 py-3 rounded-xl bg-[#00E5FF]/20 text-[#00E5FF] font-bold !hidden active:bg-[#00E5FF]/40">
                SHOOT
              </button>
            </div>
          )}

          {hud.phase === 'msg' && hud.msg && (
            <div className="absolute inset-0 flex items-center justify-center">
              <div className="text-3xl font-bold" style={{ color: hud.msgColor, textShadow: `0 0 20px ${hud.msgColor}40` }}>{hud.msg}</div>
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
