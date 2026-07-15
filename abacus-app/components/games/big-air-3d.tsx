'use client';

import { useEffect, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { PerformanceMonitor } from '@react-three/drei';
import * as THREE from 'three';
import type { GameProps } from '@/components/games/game-shell';
import { Avatar, type AvatarHandle } from '@/components/three/avatar';
import { SceneLighting } from '@/components/three/lighting';
import { MapMesh } from '@/components/three/map-loader';
import { MAPS } from '@/lib/map-data';
import { DustMotes, RimGlowPulse, useImpactFlash, ImpactFlashLight } from '@/components/three/effects';
import { PerfSampler } from '@/components/three/perf-hud';
import { useOrientation } from '@/components/three/orientation';
import { PERF_BUDGET, type PerfSample } from '@/lib/three-budget';

const MODEL_URL = '/models/elijah.glb';
const MAP = MAPS['mountain-slope'];
const SUB_START = 488, SUB_END = 582, CLIP_FPS = 30;
const MODEL_YAW = Math.PI;
const JUMPS = 5;
const WIN_SCORE = 1100;
const TRICKS = ['INDY GRAB', 'BACKSIDE 360', 'METHOD', 'CORK 720'];

type Phase = 'charge' | 'air' | 'land' | 'msg' | 'done';
interface HudState {
  score: number; jump: number; phase: Phase; charge: number;
  msg: string; msgColor: string; trickPrompt: string;
}

// ---------------------------------------------------------------- Scene
function BigAirScene({
  input, orientation, onHud, onPerf, gradeRef,
}: {
  input: React.RefObject<{ down: boolean; tap: boolean }>;
  orientation: string;
  onHud: (h: HudState) => void;
  onPerf: (s: PerfSample) => void;
  gradeRef: React.RefObject<any>;
}) {
  const avatar = useRef<AvatarHandle | null>(null);
  const { ref: flashRef, trigger: flashTrigger } = useImpactFlash();
  const camRef = useRef<THREE.PerspectiveCamera>(null);

  const st = useRef({
    score: 0, jump: 1, phase: 'charge' as Phase,
    charge: 0, charging: false,
    airT: 0, airLen: 1.5, trickReady: false, trickDone: false, trickName: '',
    landT: 0, msgT: 0, msg: '', msgColor: '#FFD700',
    elapsed: 0, playerY: 0,
  });
  const hudAcc = useRef(0);

  useFrame(({ camera }, dtRaw) => {
    const dt = Math.min(dtRaw, 0.05);
    const s = st.current;
    const a = avatar.current;
    if (!a || s.phase === 'done') return;

    s.elapsed += dt;
    const inp = input.current;
    if (!inp) return;
    const hang = 1 + (gradeRef.current?.hangBonus ?? 0);

    switch (s.phase) {
      case 'charge':
        if (inp.down) {
          s.charging = true;
          s.charge = Math.min(1, s.charge + dt * 1.5);
        } else if (s.charging) {
          s.charging = false;
          s.airLen = 1.2 + s.charge * 1.5 * hang;
          s.airT = 0;
          s.trickReady = false;
          s.trickDone = false;
          s.trickName = TRICKS[Math.floor(Math.random() * TRICKS.length)];
          s.phase = 'air';
        }
        s.playerY = 0;
        break;

      case 'air':
        s.airT += dt;
        const progress = s.airT / s.airLen;
        s.playerY = Math.sin(progress * Math.PI) * (3 + s.charge * 4);

        // Trick prompt
        if (progress > 0.3 && progress < 0.7 && !s.trickDone) {
          s.trickReady = true;
          if (inp.tap) {
            inp.tap = false;
            s.trickDone = true;
            s.trickReady = false;
          }
        } else {
          s.trickReady = false;
        }
        if (inp.tap) inp.tap = false;

        if (progress >= 1) {
          // Land
          const baseScore = Math.round(100 + s.charge * 200);
          const trickBonus = s.trickDone ? Math.round(150 + s.charge * 100) : 0;
          const total = baseScore + trickBonus;
          s.score += total;
          s.msg = s.trickDone ? `${s.trickName} +${total}` : `CLEAN LAND +${baseScore}`;
          s.msgColor = s.trickDone ? '#A855F7' : '#00FF9D';
          s.msgT = 1.5;
          s.phase = 'land';
          s.landT = 0;
          s.playerY = 0;
          flashTrigger(new THREE.Vector3(0, 0.2, 0), s.trickDone ? '#A855F7' : '#FFD700', 50, 0.3);
        }
        break;

      case 'land':
        s.landT += dt;
        if (s.landT > 1.5) {
          s.msgT = 0;
          if (s.jump >= JUMPS) {
            s.phase = 'done';
          } else {
            s.jump++;
            s.charge = 0;
            s.phase = 'charge';
          }
        }
        break;
    }

    if (s.msgT > 0) s.msgT -= dt;

    // Avatar
    a.group.position.set(0, s.playerY, 0);
    a.group.rotation.y = MODEL_YAW;
    if (s.phase === 'air') {
      a.group.rotation.z = s.trickDone ? Math.sin(s.airT * 8) * 0.5 : 0;
    } else {
      a.group.rotation.z = 0;
    }
    const clipT = (s.elapsed * 0.5) % (a.clipDuration || 1);
    a.scrub(clipT);

    // Camera
    const camY = 2.5 + s.playerY * 0.4;
    camera.position.lerp(new THREE.Vector3(
      orientation === 'portrait' ? 2 : 4,
      camY,
      orientation === 'portrait' ? 8 : 7,
    ), Math.min(1, 5 * dt));
    camera.lookAt(0, s.playerY * 0.6 + 1, 0);

    hudAcc.current += dt;
    if (hudAcc.current > 0.05) {
      hudAcc.current = 0;
      onHud({
        score: s.score, jump: s.jump, phase: s.phase, charge: s.charge,
        msg: s.msgT > 0 ? s.msg : '', msgColor: s.msgColor,
        trickPrompt: s.trickReady ? `TAP for ${s.trickName}` : '',
      });
    }
  });

  return (
    <>
      <color attach="background" args={['#0a0a14']} />
      <fog attach="fog" args={['#0a0a14', 18, 50]} />
      <SceneLighting shadows variant="venice" />
      {MAP && <MapMesh config={MAP} />}
      <DustMotes count={40} radius={12} speed={0.3} />
      <RimGlowPulse color="#A855F7" position={[-5, 3, 0]} baseIntensity={14} pulseAmp={7} />
      <RimGlowPulse color="#FFD700" position={[5, 2.5, 0]} baseIntensity={10} pulseAmp={5} />
      <ImpactFlashLight lightRef={flashRef} />
      <PerfSampler onSample={onPerf} />
      <Avatar
        url={MODEL_URL}
        subStartFrame={SUB_START}
        subEndFrame={SUB_END}
        clipFps={CLIP_FPS}
        onReady={(h) => { avatar.current = h; h.group.position.set(0, 0, 0); h.group.rotation.y = MODEL_YAW; h.scrub(0); }}
      />
    </>
  );
}

// ---------------------------------------------------------------- Main
export default function BigAir3D(props: GameProps) {
  const orientation = useOrientation();
  const input = useRef({ down: false, tap: false });
  const gradeRef = useRef(props.grade);
  gradeRef.current = props.grade;
  const [hud, setHud] = useState<HudState>({ score: 0, jump: 1, phase: 'charge', charge: 0, msg: '', msgColor: '#FFD700', trickPrompt: '' });
  const [perf, setPerf] = useState<PerfSample | null>(null);
  const endedRef = useRef(false);

  useEffect(() => {
    if (hud.phase === 'done' && !endedRef.current) {
      endedRef.current = true;
      const won = hud.score >= WIN_SCORE;
      setTimeout(() => {
        props.onEnd({ won, score: hud.score, duration: 90, headline: won ? 'GOLD MEDAL' : 'SILVER LANDING' });
      }, 1200);
    }
  }, [hud.phase, hud.score, props]);

  useEffect(() => {
    const kd = (e: KeyboardEvent) => {
      if (e.key === ' ') { e.preventDefault(); input.current.down = true; input.current.tap = true; }
    };
    const ku = (e: KeyboardEvent) => {
      if (e.key === ' ') input.current.down = false;
    };
    window.addEventListener('keydown', kd);
    window.addEventListener('keyup', ku);
    return () => { window.removeEventListener('keydown', kd); window.removeEventListener('keyup', ku); };
  }, []);

  return (
    <div className="select-none">
      <div
        className="relative mx-auto w-full overflow-hidden rounded-xl border border-white/5 shadow-[0_0_60px_rgba(0,229,255,0.06)]"
        style={{
          aspectRatio: orientation === 'portrait' ? '3 / 4' : '16 / 9',
          maxWidth: orientation === 'portrait' ? 560 : 960,
          background: 'linear-gradient(180deg, #07070c 0%, #0a0a14 100%)',
        }}
      >
        <Canvas
          shadows
          dpr={[PERF_BUDGET.dprMin, PERF_BUDGET.dprMax]}
          gl={{ antialias: true, powerPreference: 'high-performance', alpha: false, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.1 }}
          camera={{ fov: orientation === 'portrait' ? 56 : 48, near: 0.1, far: 60, position: [4, 2.5, 7] }}
        >
          <PerformanceMonitor onDecline={() => {}}>
            <BigAirScene input={input} orientation={orientation} onHud={setHud} onPerf={setPerf} gradeRef={gradeRef} />
          </PerformanceMonitor>
        </Canvas>

        <div className="pointer-events-none absolute inset-0">
          <div className="absolute left-1/2 top-3 -translate-x-1/2 rounded-lg border border-white/8 bg-black/70 px-5 py-2 text-center backdrop-blur-md">
            <div className="fel-heading text-[10px] tracking-[0.2em] text-white/50">BIG AIR · JUMP {hud.jump}/{JUMPS}</div>
            <div className="font-mono text-2xl font-bold text-[#00E5FF]">{hud.score}</div>
          </div>

          {/* Charge bar */}
          {hud.phase === 'charge' && (
            <div className="absolute bottom-[30%] left-1/2 -translate-x-1/2">
              <div className="mb-1 text-center font-mono text-xs text-white/50">HOLD SPACE TO CHARGE</div>
              <div className="relative h-3 w-44 overflow-hidden rounded-full bg-black/70">
                <div className="h-full rounded-full bg-gradient-to-r from-[#00E5FF] to-[#A855F7] transition-all" style={{ width: `${hud.charge * 100}%` }} />
              </div>
            </div>
          )}

          {/* Trick prompt */}
          {hud.trickPrompt && (
            <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 animate-pulse">
              <div className="rounded-lg border border-[#A855F7]/60 bg-black/70 px-4 py-2 font-mono text-sm text-[#A855F7] backdrop-blur-sm">
                {hud.trickPrompt}
              </div>
            </div>
          )}

          {hud.msg && (
            <div className="absolute left-1/2 top-1/3 -translate-x-1/2 fel-heading text-3xl font-bold drop-shadow-[0_2px_12px_rgba(0,0,0,0.8)]" style={{ color: hud.msgColor }}>{hud.msg}</div>
          )}

          {hud.phase === 'done' && (
            <div className="absolute inset-0 flex items-center justify-center bg-black/60">
              <div className="text-center">
                <div className="fel-heading text-4xl font-bold" style={{ color: hud.score >= WIN_SCORE ? '#FFD700' : '#00E5FF' }}>
                  {hud.score >= WIN_SCORE ? 'GOLD MEDAL!' : 'SILVER LANDING'}
                </div>
                <div className="mt-2 font-mono text-white/60">Final Score: {hud.score}</div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Mobile */}
      <div className="mx-auto mt-4 flex max-w-[960px] justify-center px-3 !hidden">
        <button
          onTouchStart={(e) => { e.preventDefault(); input.current.down = true; input.current.tap = true; }}
          onTouchEnd={(e) => { e.preventDefault(); input.current.down = false; }}
          onClick={() => { input.current.tap = true; }}
          className="rounded-lg border border-[#A855F7]/40 bg-[#A855F7]/10 px-10 py-4 text-lg font-bold text-[#A855F7] transition-colors active:bg-[#A855F7]/25"
        >
          {hud.phase === 'charge' ? 'HOLD TO CHARGE' : hud.phase === 'air' ? 'TAP FOR TRICK' : 'WAIT...'}
        </button>
      </div>
    </div>
  );
}
