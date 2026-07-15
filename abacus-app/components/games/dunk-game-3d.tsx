'use client';

import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { PerformanceMonitor } from '@react-three/drei';
import * as THREE from 'three';
import type { GameProps } from '@/components/games/game-shell';
import { Avatar, type AvatarHandle } from '@/components/three/avatar';
import { SceneLighting } from '@/components/three/lighting';
import { FollowCamera } from '@/components/three/follow-camera';
import { MapMesh } from '@/components/three/map-loader';
import { SceneBackdrop } from '@/components/three/scene-backdrop';
import { MAPS } from '@/lib/map-data';
import { DustMotes as SharedDustMotes, useImpactFlash, ImpactFlashLight, RimGlowPulse, useScreenShake } from '@/components/three/effects';
import { PerfSampler } from '@/components/three/perf-hud';
import { useOrientation } from '@/components/three/orientation';
import { PERF_BUDGET, gradePerf, type PerfSample } from '@/lib/three-budget';

const BLUE_COURT = MAPS['venice-blue-court'];

const MODEL_URL = '/models/elijah.glb';
const SUB_START = 488, SUB_END = 582, CLIP_FPS = 30;
const MODEL_YAW = Math.PI;

const START_Z = 6.2;
const RIM = new THREE.Vector3(0, 3.05, 0);
const CONTACT_Z = 0.72;

type Phase = 'idle' | 'charge' | 'rise' | 'qte' | 'fall' | 'land' | 'aiTurn';
type Style = 'POWER' | 'FLASHY' | 'SIGNATURE';

export interface DunkInput { cmds: string[]; style: Style; }
export interface HudState {
  pScore: number; aiScore: number; style: Style; msg: string;
  phase: Phase; charge: number; qteProg: number; qteActive: boolean; turn: 'player' | 'ai';
}

// PremiumCourt removed — now using Venice Blue Court MapMesh

// CourtLines + CourtBranding removed — blue court map has built-in markings

// ---------------------------------------------------------------- Premium Hoop
function PremiumHoop({ netRef }: { netRef: React.RefObject<THREE.Mesh> }) {
  return (
    <group>
      {/* pole — brushed steel */}
      <mesh position={[0, 1.9, -0.95]} castShadow>
        <cylinderGeometry args={[0.1, 0.1, 3.8, 16]} />
        <meshStandardMaterial color={0x555566} metalness={0.85} roughness={0.25} />
      </mesh>
      {/* pole base plate */}
      <mesh position={[0, 0.02, -0.95]}>
        <cylinderGeometry args={[0.35, 0.4, 0.04, 16]} />
        <meshStandardMaterial color={0x444455} metalness={0.9} roughness={0.3} />
      </mesh>
      {/* support arm */}
      <mesh position={[0, 3.6, -0.45]} rotation-z={0} castShadow>
        <boxGeometry args={[0.06, 0.06, 0.95]} />
        <meshStandardMaterial color={0x555566} metalness={0.85} roughness={0.25} />
      </mesh>

      {/* backboard — frosted glass effect */}
      <mesh position={[0, 3.5, -0.5]} castShadow>
        <boxGeometry args={[1.83, 1.07, 0.04]} />
        <meshPhysicalMaterial
          color={0xffffff}
          transparent
          opacity={0.18}
          roughness={0.15}
          metalness={0.0}
          transmission={0.3}
          thickness={0.04}
          clearcoat={0.8}
          clearcoatRoughness={0.1}
          envMapIntensity={0.4}
          side={THREE.DoubleSide}
        />
      </mesh>
      {/* backboard border frame */}
      <mesh position={[0, 3.5, -0.48]}>
        <boxGeometry args={[1.87, 1.11, 0.01]} />
        <meshStandardMaterial color={0x888899} metalness={0.7} roughness={0.3} transparent opacity={0.6} />
      </mesh>
      {/* target square */}
      <mesh position={[0, 3.32, -0.465]}>
        <boxGeometry args={[0.6, 0.45, 0.005]} />
        <meshBasicMaterial color={0xff3366} transparent opacity={0.85} />
      </mesh>
      {/* target square glow */}
      <mesh position={[0, 3.32, -0.46]}>
        <boxGeometry args={[0.64, 0.49, 0.002]} />
        <meshBasicMaterial color={0xff3366} transparent opacity={0.15} />
      </mesh>

      {/* rim — metallic orange with hot glow */}
      <mesh position={[0, 3.05, 0]} rotation-x={Math.PI / 2}>
        <torusGeometry args={[0.23, 0.025, 12, 32]} />
        <meshStandardMaterial
          color={0xff6a2a}
          emissive={0xff3300}
          emissiveIntensity={0.8}
          metalness={0.7}
          roughness={0.2}
        />
      </mesh>
      {/* rim inner ring glow */}
      <mesh position={[0, 3.05, 0]} rotation-x={Math.PI / 2}>
        <torusGeometry args={[0.23, 0.035, 8, 32]} />
        <meshBasicMaterial color={0xff5500} transparent opacity={0.2} />
      </mesh>

      {/* net — white wire */}
      <mesh ref={netRef} position={[0, 2.83, 0]}>
        <cylinderGeometry args={[0.22, 0.10, 0.44, 20, 4, true]} />
        <meshBasicMaterial color={0xffffff} wireframe transparent opacity={0.5} side={THREE.DoubleSide} />
      </mesh>
    </group>
  );
}

// Old DustMotes + HoopGlow removed — using shared effects from effects.tsx
function HoopGlow() {
  const ref = useRef<THREE.Mesh>(null);
  useFrame(({ clock }) => {
    if (!ref.current) return;
    const mat = ref.current.material as THREE.MeshBasicMaterial;
    mat.opacity = 0.08 + Math.sin(clock.elapsedTime * 1.5) * 0.03;
  });
  return (
    <mesh ref={ref} rotation-x={-Math.PI / 2} position={[0, 0.003, 0]}>
      <circleGeometry args={[1.8, 32]} />
      <meshBasicMaterial color={0xff5500} transparent opacity={0.08} />
    </mesh>
  );
}

// ---------------------------------------------------------------- 3D Scene
function DunkScene({
  grade, prq, onEnd, gamepad, input, orientation, onHud, onPerf,
}: GameProps & {
  input: React.MutableRefObject<DunkInput>;
  orientation: 'landscape' | 'portrait';
  onHud: (h: HudState) => void;
  onPerf: (p: PerfSample) => void;
}) {
  const avatar = useRef<AvatarHandle | null>(null);
  const ballRef = useRef<THREE.Mesh>(null);
  const netRef = useRef<THREE.Mesh>(null);
  const camTarget = useRef(new THREE.Vector3(0, 1.1, START_Z));
  const burst = useRef<THREE.InstancedMesh>(null);

  const onEndRef = useRef(onEnd); onEndRef.current = onEnd;
  const gradeRef = useRef(grade); gradeRef.current = grade;
  const endedRef = useRef(false);
  const prevGpA = useRef(false);

  const st = useRef({
    phase: 'idle' as Phase, charge: 0, y: 0, z: START_Z, style: 'POWER' as Style,
    airT: 0, airDur: 1.3, apexH: 1.4, qteT: 0, qteWindow: 0.55, qteResult: '', hangTime: 0,
    pScore: 0, aiScore: 0, msg: '', msgT: 0, turn: 'player' as 'player' | 'ai', aiT: 0,
    startTime: Date.now(), landT: 0, ball: 'hand' as 'hand' | 'dunk' | 'net' | 'done',
    ballPos: new THREE.Vector3(), ballFrom: new THREE.Vector3(), ballT: 0, flashT: 0,
  });

  const dummy = useMemo(() => new THREE.Object3D(), []);
  const particles = useRef(Array.from({ length: 24 }, () => ({ p: new THREE.Vector3(), v: new THREE.Vector3(), life: 0 })));

  const scrubForPhase = useCallback(() => {
    const s = st.current; const a = avatar.current; if (!a) return;
    const D = a.clipDuration;
    let u = 0;
    const uGather = 0.13, uApex = 0.30, uLandStart = 0.80;
    if (s.phase === 'charge') u = s.charge * uGather;
    else if (s.phase === 'rise' || s.phase === 'qte' || s.phase === 'fall') {
      const f = THREE.MathUtils.clamp(s.airT / s.airDur, 0, 1);
      u = uGather + f * (uLandStart - uGather);
    } else if (s.phase === 'land') {
      const lf = THREE.MathUtils.clamp((Date.now() - s.landT) / 500, 0, 1);
      u = uLandStart + lf * (1 - uLandStart);
    } else u = 0;
    a.scrub(u * D);
  }, []);

  const startCharge = () => { const s = st.current; if (s.phase === 'idle' && s.turn === 'player') { s.phase = 'charge'; s.charge = 0; } };
  const release = () => {
    const s = st.current; if (s.phase !== 'charge') return;
    const power = Math.min(s.charge, 1);
    s.phase = 'rise'; s.airT = 0; s.airDur = 1.15 + power * 0.55; s.apexH = 1.05 + power * 0.7;
    s.qteResult = ''; s.hangTime = 0; s.ball = 'hand';
  };
  const qteTap = () => {
    const s = st.current; if (s.phase !== 'qte') return;
    const off = Math.abs(s.qteT - s.qteWindow / 2) / (s.qteWindow / 2);
    s.qteResult = off < 0.25 ? 'PERFECT' : off < 0.55 ? 'GREAT' : 'GOOD';
    s.phase = 'fall'; s.flashT = 0.16;
    triggerDunk();
  };
  const setStyle = (v: Style) => { const s = st.current; if (s.phase === 'rise' || s.phase === 'qte' || s.phase === 'charge') s.style = v; };

  const triggerDunk = () => {
    const s = st.current;
    s.ball = 'dunk'; s.ballT = 0;
    if (ballRef.current) s.ballFrom.copy(ballRef.current.position);
    for (const pt of particles.current) {
      pt.p.copy(RIM);
      pt.v.set((Math.random() - 0.5) * 4, Math.random() * 4.5 + 1, (Math.random() - 0.5) * 4);
      pt.life = 0.7 + Math.random() * 0.4;
    }
  };

  const scoreDunk = () => {
    const s = st.current;
    const complexity = s.style === 'SIGNATURE' ? 2 : s.style === 'FLASHY' ? 1.4 : 0.9;
    const hangPts = Math.min(s.hangTime / 0.9, 2);
    const timing = s.qteResult === 'PERFECT' ? 1 : s.qteResult === 'GREAT' ? 0.5 : s.qteResult === 'GOOD' ? 0 : -1;
    const total = Math.max(Math.round((hangPts + complexity + timing) * 10) / 10, 0);
    s.pScore = Math.round((s.pScore + total) * 10) / 10;
    s.msg = `${s.qteResult || 'MISS'} · +${total.toFixed(1)} PTS`; s.msgT = 1.8;
  };

  useFrameLoop({
    st, avatar, ballRef, netRef, burst, dummy, particles, camTarget,
    gamepad, prevGpA, input, gradeRef, onEndRef, endedRef, prq,
    startCharge, release, qteTap, setStyle, scoreDunk, scrubForPhase, onHud,
  });

  return (
    <>
      <color attach="background" args={['#5a4258']} />
      <fog attach="fog" args={['#5a4258', 32, 90]} />
      {BLUE_COURT?.backdrop && (
        <Suspense fallback={null}><SceneBackdrop url={BLUE_COURT.backdrop} /></Suspense>
      )}
      <SceneLighting shadows variant="blue-court" />
      <FollowCamera
        target={camTarget}
        offset={orientation === 'portrait' ? new THREE.Vector3(4.2, 2.9, 6.2) : new THREE.Vector3(4.6, 2.6, 5.2)}
        lookHeight={orientation === 'portrait' ? 1.7 : 1.5}
        lookOffsetX={orientation === 'portrait' ? 2.2 : 2.7}
        stiffness={6}
      />

      {/* Venice Blue Court map */}
      {BLUE_COURT && <MapMesh config={BLUE_COURT} />}
      <PremiumHoop netRef={netRef} />
      <HoopGlow />
      <SharedDustMotes count={50} radius={14} color="#aabbff" opacity={0.2} speed={0.25} />
      <RimGlowPulse color="#2277ff" position={[-6, 3, -2]} baseIntensity={10} pulseAmp={5} />
      <RimGlowPulse color="#ffd700" position={[6, 2.5, 0]} baseIntensity={8} pulseAmp={4} />

      {/* basketball — emissive leather look */}
      <mesh ref={ballRef} castShadow>
        <sphereGeometry args={[0.122, 24, 20]} />
        <meshStandardMaterial
          color={0xff7a1a}
          roughness={0.45}
          metalness={0.05}
          emissive={0x4a1800}
          emissiveIntensity={0.5}
        />
      </mesh>

      {/* score burst particles — gold + cyan mix */}
      <instancedMesh ref={burst} args={[undefined as any, undefined as any, 24]}>
        <boxGeometry args={[0.07, 0.07, 0.07]} />
        <meshBasicMaterial color={0xffd700} toneMapped={false} transparent />
      </instancedMesh>

      <PerfSampler onSample={onPerf} />
      <Avatar
        url={MODEL_URL}
        subStartFrame={SUB_START}
        subEndFrame={SUB_END}
        clipFps={CLIP_FPS}
        onReady={(h) => {
          avatar.current = h;
          h.group.rotation.y = MODEL_YAW;
          h.group.position.set(0, 0, START_Z);
          h.scrub(0);
        }}
      />
    </>
  );
}

// ---------------------------------------------------------------- Game Loop
function useFrameLoop(ctx: any) {
  const {
    st, avatar, ballRef, netRef, burst, dummy, particles, camTarget,
    gamepad, prevGpA, input, gradeRef, onEndRef, endedRef, prq,
    startCharge, release, qteTap, setStyle, scoreDunk, scrubForPhase, onHud,
  } = ctx;
  const hudAcc = useRef(0);

  useFrame((_state: any, dtRaw: number) => {
    const dt = Math.min(dtRaw, 0.05);
    const s = st.current;
    const a = avatar.current;
    if (endedRef.current) return;

    // input
    const q: string[] = input.current.cmds;
    while (q.length) {
      const c = q.shift();
      if (c === 'down') {
        if (s.phase === 'idle') startCharge();
        else if (s.phase === 'qte') qteTap();
      } else if (c === 'up') {
        if (s.phase === 'charge') release();
      }
    }
    if (input.current.style) setStyle(input.current.style);

    const gp = gamepad;
    if (gp) {
      const aBtn = !!gp.a;
      if (aBtn && !prevGpA.current) { if (s.phase === 'idle') startCharge(); else if (s.phase === 'qte') qteTap(); }
      if (!aBtn && prevGpA.current) { if (s.phase === 'charge') release(); }
      prevGpA.current = aBtn;
      if (gp.up) setStyle('POWER');
      else if (gp.left || gp.right) setStyle('FLASHY');
      else if (gp.down) setStyle('SIGNATURE');
    }

    if (s.msgT > 0) s.msgT -= dt;
    if (s.flashT > 0) s.flashT -= dt;

    // phase machine
    if (s.phase === 'charge') s.charge = Math.min(s.charge + dt * 0.9, 1);
    if (s.phase === 'rise' || s.phase === 'qte' || s.phase === 'fall') {
      s.airT += dt;
      const f = THREE.MathUtils.clamp(s.airT / s.airDur, 0, 1);
      s.y = 4 * s.apexH * f * (1 - f);
      const fwd = Math.min(f / 0.5, 1); const e = 1 - Math.pow(1 - fwd, 3);
      s.z = THREE.MathUtils.lerp(START_Z, CONTACT_Z, e);
      const nearApex = f > 0.36 && f < 0.64;
      if (nearApex) s.hangTime += dt + (gradeRef.current?.hangBonus ?? 0) * dt * 0.6;
      if (s.phase === 'rise' && f >= 0.4) { s.phase = 'qte'; s.qteT = 0; s.qteWindow = s.style === 'SIGNATURE' ? 0.34 : s.style === 'FLASHY' ? 0.42 : 0.55; }
      if (s.phase === 'qte') { s.qteT += dt; if (s.qteT > s.qteWindow) { s.qteResult = ''; s.phase = 'fall'; if (s.ball === 'hand') { s.ball = 'dunk'; s.ballT = 0; if (ballRef.current) s.ballFrom.copy(ballRef.current.position); } } }
      if (f >= 1) {
        s.y = 0; s.z = CONTACT_Z; s.phase = 'land'; s.landT = Date.now(); scoreDunk();
        setTimeout(() => {
          const ss = st.current; ss.z = START_Z; ss.y = 0; ss.hangTime = 0; ss.ball = 'hand';
          if (ss.pScore >= 21 || ss.aiScore >= 21) return;
          ss.turn = 'ai'; ss.phase = 'aiTurn'; ss.aiT = 1.3;
        }, 720);
      }
    }
    if (s.phase === 'aiTurn') {
      s.aiT -= dt;
      if (s.aiT <= 0) {
        const ai = Math.round((1.3 + Math.random() * 2.6) * 10) / 10;
        s.aiScore = Math.round((s.aiScore + ai) * 10) / 10;
        s.msg = `RIVAL SCORES +${ai.toFixed(1)}`; s.msgT = 1.5;
        s.turn = 'player'; s.phase = 'idle';
      }
    }

    // win check
    if ((s.pScore >= 21 || s.aiScore >= 21) && !endedRef.current && s.phase !== 'rise' && s.phase !== 'qte' && s.phase !== 'fall') {
      endedRef.current = true;
      const dur = Math.round((Date.now() - s.startTime) / 1000);
      onEndRef.current?.({
        score: Math.round(s.pScore), opponentScore: Math.round(s.aiScore),
        won: s.pScore > s.aiScore, duration: dur,
        headline: s.pScore > s.aiScore ? 'CONTEST WON' : 'CONTEST LOST',
      });
      return;
    }

    // character position
    if (a) {
      a.group.position.set(0, s.y, s.z);
      scrubForPhase();
      camTarget.current.set(0, s.y + 0.2, s.z);
    }

    // ball
    const ball = ballRef.current;
    if (ball && a) {
      const hand = a.bone('RightHand') || a.bone('LeftHand');
      if (s.ball === 'hand' && hand) { hand.getWorldPosition(ball.position); ball.visible = true; }
      else if (s.ball === 'dunk') {
        s.ballT += dt / 0.16; const t = Math.min(s.ballT, 1);
        ball.position.lerpVectors(s.ballFrom, RIM, t);
        if (t >= 1) { s.ball = 'net'; s.ballT = 0; }
      } else if (s.ball === 'net') {
        s.ballT += dt / 0.22; const t = Math.min(s.ballT, 1);
        ball.position.set(0, THREE.MathUtils.lerp(RIM.y, RIM.y - 0.9, t), 0);
        if (netRef.current) netRef.current.scale.y = 1 + Math.sin(t * Math.PI) * 0.6;
        if (t >= 1) { s.ball = 'done'; if (netRef.current) netRef.current.scale.y = 1; }
      } else if (s.ball === 'done') { ball.visible = false; }
    }

    // particles
    if (burst.current) {
      let any = false;
      particles.current.forEach((pt: any, i: number) => {
        if (pt.life > 0) {
          pt.life -= dt; pt.v.y -= 7 * dt; pt.p.addScaledVector(pt.v, dt);
          any = true;
          dummy.position.copy(pt.p);
          dummy.scale.setScalar(Math.max(pt.life * 2, 0.01));
        } else {
          dummy.scale.setScalar(0.0001); dummy.position.set(0, -100, 0);
        }
        dummy.updateMatrix(); burst.current.setMatrixAt(i, dummy.matrix);
      });
      burst.current.instanceMatrix.needsUpdate = true;
      burst.current.visible = any;
    }

    // HUD
    hudAcc.current += dt;
    if (hudAcc.current >= 0.06) {
      hudAcc.current = 0;
      onHud({
        pScore: s.pScore, aiScore: s.aiScore, style: s.style,
        msg: s.msgT > 0 ? s.msg : '', phase: s.phase, charge: s.charge,
        qteProg: s.phase === 'qte' ? s.qteT / s.qteWindow : 0,
        qteActive: s.phase === 'qte', turn: s.turn,
      });
    }
  });
}

// ---------------------------------------------------------------- Main Export
export default function DunkGame3D(props: GameProps) {
  const [started, setStarted] = useState(true);
  const orientation = useOrientation();
  const input = useRef<DunkInput>({ cmds: [], style: 'POWER' });
  const [hud, setHud] = useState<HudState>({ pScore: 0, aiScore: 0, style: 'POWER', msg: '', phase: 'idle', charge: 0, qteProg: 0, qteActive: false, turn: 'player' });
  const [perf, setPerf] = useState<PerfSample | null>(null);
  const [showPerf, setShowPerf] = useState(false);

  const push = useCallback((c: string) => { input.current.cmds.push(c); }, []);
  const pickStyle = useCallback((s: Style) => { input.current.style = s; }, []);

  useEffect(() => {
    if (!started) return;
    const down = (e: KeyboardEvent) => {
      const k = e.key;
      if (k === ' ') { e.preventDefault(); push('down'); }
      else if (k === 'ArrowUp') pickStyle('POWER');
      else if (k === 'ArrowLeft' || k === 'ArrowRight') pickStyle('FLASHY');
      else if (k === 'ArrowDown') pickStyle('SIGNATURE');
      else if (k.toLowerCase() === 'p') setShowPerf((v) => !v);
    };
    const up = (e: KeyboardEvent) => { if (e.key === ' ') push('up'); };
    window.addEventListener('keydown', down);
    window.addEventListener('keyup', up);
    return () => { window.removeEventListener('keydown', down); window.removeEventListener('keyup', up); };
  }, [started, push, pickStyle]);

  const perfGrade = perf ? gradePerf(perf) : null;
  const styleColor = hud.style === 'SIGNATURE' ? '#A855F7' : hud.style === 'FLASHY' ? '#FF3366' : '#00E5FF';

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
        {started && (
          <Canvas
            shadows
            dpr={[PERF_BUDGET.dprMin, PERF_BUDGET.dprMax]}
            gl={{ antialias: true, powerPreference: 'high-performance', alpha: false, toneMapping: THREE.ACESFilmicToneMapping, toneMappingExposure: 1.1 }}
            camera={{ fov: orientation === 'portrait' ? 50 : 44, near: 0.1, far: 60, position: [4.6, 2.6, 11] }}
          >
            <PerformanceMonitor onDecline={() => {}}>
              <DunkScene {...props} input={input} orientation={orientation} onHud={setHud} onPerf={setPerf} />
            </PerformanceMonitor>
          </Canvas>
        )}

        {/* ---- HUD overlay ---- */}
        {started && (
          <div className="pointer-events-none absolute inset-0">
            {/* scoreboard */}
            <div className="absolute left-1/2 top-3 -translate-x-1/2 rounded-lg border border-white/8 bg-black/70 px-5 py-2 text-center backdrop-blur-md">
              <div className="fel-heading text-[10px] tracking-[0.2em] text-white/50">DUNK CONTEST · FIRST TO 21</div>
              <div className="flex items-center justify-center gap-6 font-mono text-2xl font-bold">
                <span className="text-[#00E5FF] drop-shadow-[0_0_8px_rgba(0,229,255,0.5)]">{hud.pScore.toFixed(1)}</span>
                <span className="text-[10px] font-normal tracking-widest text-white/70">YOU · RIVAL</span>
                <span className="text-[#FF3366] drop-shadow-[0_0_8px_rgba(255,51,102,0.5)]">{hud.aiScore.toFixed(1)}</span>
              </div>
            </div>

            {/* PRQ badge */}
            <div className="absolute right-3 top-3 rounded-md bg-black/50 px-2.5 py-1 font-mono text-[10px] backdrop-blur-sm" style={{ color: props.grade?.color ?? '#00FF9D' }}>
              PRQ {Math.round(props.prq)} · {props.grade?.label} · HANG +{(props.grade?.hangBonus ?? 0).toFixed(2)}
            </div>

            {/* style selector */}
            <div className="absolute bottom-3 left-3">
              <div className="fel-heading text-base font-bold drop-shadow-[0_1px_6px_rgba(0,0,0,0.8)]" style={{ color: styleColor }}>
                STYLE: {hud.style}
              </div>
              <div className="font-mono text-[10px] text-white/45">
                {hud.turn === 'player'
                  ? (hud.phase === 'idle' ? 'HOLD SPACE / A TO CHARGE' : hud.phase === 'charge' ? 'RELEASE TO JUMP' : '')
                  : 'RIVAL TURN…'}
              </div>
            </div>

            {/* charge bar — glowing */}
            {hud.phase === 'charge' && (
              <div className="absolute bottom-[30%] left-1/2 -translate-x-1/2">
                <div className="relative h-3 w-44 overflow-hidden rounded-full bg-black/70 shadow-inner">
                  <div
                    className="h-full rounded-full transition-all duration-75"
                    style={{
                      width: `${hud.charge * 100}%`,
                      background: hud.charge > 0.75
                        ? 'linear-gradient(90deg, #00E5FF, #00FF9D)'
                        : 'linear-gradient(90deg, #00E5FF 60%, #00b8cc)',
                      boxShadow: hud.charge > 0.75
                        ? '0 0 16px rgba(0,255,157,0.6)'
                        : '0 0 8px rgba(0,229,255,0.4)',
                    }}
                  />
                </div>
                <div className="mt-1 text-center font-mono text-[10px] text-white/50">
                  {Math.round(hud.charge * 100)}%
                </div>
              </div>
            )}

            {/* QTE ring — animated */}
            {hud.qteActive && (
              <div className="absolute left-1/2 top-[36%] -translate-x-1/2 -translate-y-1/2">
                <svg width="96" height="96" viewBox="0 0 96 96" className="drop-shadow-[0_0_20px_rgba(0,229,255,0.4)]">
                  <circle cx="48" cy="48" r="38" fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="5" />
                  <circle
                    cx="48" cy="48" r="38" fill="none"
                    stroke={hud.qteProg > 0.3 && hud.qteProg < 0.7 ? '#FFD700' : '#00E5FF'}
                    strokeWidth="5" strokeLinecap="round"
                    strokeDasharray={`${hud.qteProg * 238.8} 238.8`}
                    transform="rotate(-90 48 48)"
                  />
                  <text x="48" y="53" textAnchor="middle" fill="#fff" fontSize="15" fontWeight="bold" fontFamily="Barlow Condensed">TAP!</text>
                </svg>
              </div>
            )}

            {/* center message */}
            {hud.msg && (
              <div className="fel-heading absolute left-1/2 top-[45%] -translate-x-1/2 -translate-y-1/2 text-3xl font-bold drop-shadow-[0_2px_12px_rgba(0,0,0,0.9)]" style={{ color: '#FFD700', textShadow: '0 0 20px rgba(255,215,0,0.4)' }}>
                {hud.msg}
              </div>
            )}

            {/* perf badge */}
            {showPerf && perf && (
              <div className="absolute left-3 top-14 rounded-md bg-black/80 px-2.5 py-1.5 font-mono text-[9px] leading-tight backdrop-blur-sm" style={{ color: perfGrade?.status === 'over' ? '#FF3366' : perfGrade?.status === 'warn' ? '#FFD700' : '#00FF9D' }}>
                <div>{perf.fps} FPS · {perf.calls} calls · {(perf.triangles / 1000).toFixed(0)}k tris</div>
                <div>tex {perf.textures} · geo {perf.geometries} · prog {perf.programs}</div>
                {perfGrade?.notes.map((n: string, i: number) => <div key={i}>⚠ {n}</div>)}
              </div>
            )}
          </div>
        )}

        {/* ---- start overlay ---- */}
        {!started && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-gradient-to-b from-black/80 via-black/60 to-black/80 backdrop-blur-sm">
            <div className="mb-2 rounded-full border border-[#00E5FF]/30 bg-[#00E5FF]/5 px-4 py-1 font-mono text-[10px] tracking-[0.15em] text-[#00E5FF]">
              REAL-TIME 3D · MOCAP DRIVEN
            </div>
            <h2 className="fel-heading text-5xl font-bold text-white drop-shadow-[0_2px_20px_rgba(0,229,255,0.2)]">DUNK CONTEST</h2>
            <p className="mt-3 max-w-md text-center text-sm leading-relaxed text-white/50">
              Charge the jump, tap the apex QTE, pick your style. First to 21 style points beats the rival.
            </p>
            <div className="mt-5 grid grid-cols-2 gap-x-10 gap-y-1.5 font-mono text-[11px] text-white/45">
              <span>HOLD SPACE / A — Charge</span><span>RELEASE — Jump</span>
              <span>TAP at apex — Trick QTE</span><span>↑ POWER · ↔ FLASHY · ↓ SIG</span>
            </div>
            <button
              onClick={() => setStarted(true)}
              className="fel-heading mt-8 rounded-lg bg-gradient-to-r from-[#00E5FF] to-[#00b8cc] px-12 py-3.5 text-xl font-bold text-black shadow-[0_0_30px_rgba(0,229,255,0.35)] transition-all hover:shadow-[0_0_50px_rgba(0,229,255,0.55)] hover:scale-[1.02] active:scale-[0.98]"
            >
              TIP OFF
            </button>
          </div>
        )}
      </div>

      {/* ---- mobile / touch controls ---- */}
      {started && (
        <div className="mx-auto mt-4 flex max-w-[960px] items-center justify-between gap-3 px-3 !hidden">
          <div className="flex gap-2">
            <button onClick={() => pickStyle('POWER')} className="rounded-lg border border-[#00E5FF]/40 bg-[#00E5FF]/8 px-3.5 py-2.5 text-xs font-bold text-[#00E5FF] transition-colors active:bg-[#00E5FF]/20">↑ POWER</button>
            <button onClick={() => pickStyle('FLASHY')} className="rounded-lg border border-[#FF3366]/40 bg-[#FF3366]/8 px-3.5 py-2.5 text-xs font-bold text-[#FF3366] transition-colors active:bg-[#FF3366]/20">↔ FLASHY</button>
            <button onClick={() => pickStyle('SIGNATURE')} className="rounded-lg border border-[#A855F7]/40 bg-[#A855F7]/8 px-3.5 py-2.5 text-xs font-bold text-[#A855F7] transition-colors active:bg-[#A855F7]/20">↓ SIG</button>
          </div>
          <button
            onTouchStart={(e) => { e.preventDefault(); push('down'); }}
            onTouchEnd={(e) => { e.preventDefault(); push('up'); }}
            onMouseDown={() => push('down')}
            onMouseUp={() => push('up')}
            className="h-16 w-28 rounded-xl border border-[#00E5FF]/50 bg-[#00E5FF]/10 text-sm font-bold text-[#00E5FF] shadow-[0_0_20px_rgba(0,229,255,0.15)] transition-all active:bg-[#00E5FF]/25 active:shadow-[0_0_30px_rgba(0,229,255,0.3)]"
          >JUMP / TAP</button>
        </div>
      )}
    </div>
  );
}
