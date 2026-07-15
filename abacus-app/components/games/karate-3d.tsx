'use client';

import { Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { PerformanceMonitor } from '@react-three/drei';
import * as THREE from 'three';
import type { GameProps } from '@/components/games/game-shell';
import { Avatar, type AvatarHandle } from '@/components/three/avatar';
import { DojoLighting, IncenseEmbers } from '@/components/three/dojo-scene';
import { RimGlowPulse } from '@/components/three/effects';
import { PerfSampler } from '@/components/three/perf-hud';
import { MapMesh } from '@/components/three/map-loader';
import { SceneBackdrop } from '@/components/three/scene-backdrop';
import { useOrientation } from '@/components/three/orientation';
import { PERF_BUDGET, gradePerf, type PerfSample } from '@/lib/three-budget';
import { MAPS } from '@/lib/map-data';

const HERO_URL = '/models/elijah-hero.glb';
const LEGACY_URL = '/models/elijah.glb';
const STRIKE_CLIPS: Record<string, string> = { jab: 'jab', kick: 'high_kick', special: 'roundhouse' };
const ALT_STRIKES = ['hook', 'uppercut'];
const MAP = MAPS['dojo'];
const FIGHT_Z = 0;
// Raised temple veranda deck height (model origin/stilts at y=0).
const DECK_Y = 1.25;
const ARENA_MIN = -6;
const ARENA_MAX = 6;
const MAX_FOES = 3;

interface FoeState {
  x: number; hp: number; maxHp: number; alive: boolean;
  attackCd: number; staggered: number; attacking: number; flinch: number;
}

interface HudState {
  score: number; wave: number; php: number; neural: number;
  combo: number; mult: number; burst: number; counter: number;
  aggr: number; spd: number; msg: string; msgColor: string; msgT: number;
}

function makeFoe(): FoeState {
  return { x: ARENA_MAX, hp: 1, maxHp: 1, alive: false, attackCd: 1, staggered: 0, attacking: 0, flinch: 0 };
}

// Camera that trails the player along X for a beat-em-up feel.
function TrackCamera({ playerX }: { playerX: React.MutableRefObject<number> }) {
  const camera = useThree((s) => s.camera);
  const tgt = useRef(new THREE.Vector3(0, DECK_Y + 0.7, FIGHT_Z));
  useFrame(() => {
    const px = playerX.current;
    camera.position.x += ((px + 0.6) - camera.position.x) * 0.08;
    camera.position.y += (2.85 - camera.position.y) * 0.05;
    camera.position.z += (6.8 - camera.position.z) * 0.05;
    tgt.current.set(px, DECK_Y + 0.7, FIGHT_Z);
    camera.lookAt(tgt.current);
  });
  return null;
}

function KarateScene({
  grade, prq, onEnd, gamepad, onHud, onPerf,
}: GameProps & { onHud: (h: HudState) => void; onPerf: (p: PerfSample) => void }) {
  const playerRef = useRef<AvatarHandle | null>(null);
  const foeRefs = useRef<(AvatarHandle | null)[]>([null, null, null]);
  const playerX = useRef(-2);
  const onEndRef = useRef(onEnd); onEndRef.current = onEnd;
  const gradeRef = useRef(grade); gradeRef.current = grade;
  const endedRef = useRef(false);

  const st = useRef({
    t: 0, score: 0, wave: 1, combo: 0, comboT: 0, mult: 1,
    neural: 0, burst: 0, php: 100, pface: 1,
    attack: 0, block: false, counterT: 0,
    keys: {} as Record<string, boolean>,
    foes: [makeFoe(), makeFoe(), makeFoe()],
    msg: '', msgColor: '#FFF', msgT: 0,
    startTime: Date.now(),
  });

  const showMsg = useCallback((text: string, color: string) => {
    const s = st.current; s.msg = text; s.msgColor = color; s.msgT = 0.8;
  }, []);

  const spawnWave = useCallback((w: number) => {
    const s = st.current;
    const count = w >= 13 ? 3 : w >= 7 ? 2 : 1;
    for (let i = 0; i < MAX_FOES; i++) {
      const f = s.foes[i];
      if (i < count) {
        const hp = 40 + w * 8;
        f.hp = hp; f.maxHp = hp; f.alive = true;
        f.x = 3.5 + i * 1.6; f.attackCd = 1.2 + Math.random(); f.staggered = 0; f.attacking = 0; f.flinch = 0;
      } else { f.alive = false; }
    }
  }, []);

  const strikeCount = useRef(0);

  const doStrike = useCallback((type: 'jab' | 'kick' | 'special') => {
    const s = st.current;
    if (endedRef.current || s.attack > 0 || s.block) return;
    const pts = type === 'jab' ? 1 : type === 'kick' ? 2 : 3;
    const range = type === 'jab' ? 1.6 : type === 'kick' ? 2.1 : 2.5;
    const dmg = (type === 'jab' ? 10 : type === 'kick' ? 16 : 26) * (s.counterT > 0 ? 1.6 : 1);
    s.attack = type === 'jab' ? 0.22 : type === 'kick' ? 0.34 : 0.5;

    // Play strike animation on player avatar
    const p = playerRef.current;
    if (p && p.clipNames.length >= 1) {
      // Vary strikes: alternate between primary and alt strikes
      let clipName = STRIKE_CLIPS[type] ?? 'jab';
      if (type === 'special') {
        strikeCount.current++;
        if (strikeCount.current % 3 === 0) clipName = ALT_STRIKES[0];
        else if (strikeCount.current % 3 === 1) clipName = ALT_STRIKES[1];
      }
      p.play(clipName, { loop: false, timeScale: 1.3, fadeIn: 0.08, onFinish: () => {
        p.play('guard', { loop: true, timeScale: 1, fadeIn: 0.15 });
      }});
    }
    let hit = false;
    for (const f of s.foes) {
      if (!f.alive) continue;
      if (Math.abs(f.x - playerX.current) < range && (f.x - playerX.current) * s.pface > -0.5) {
        f.hp -= dmg; f.staggered = 0.45; f.flinch = 0.3; hit = true;
        if (f.hp <= 0) { f.alive = false; s.score += 15; }
      }
    }
    if (hit) {
      s.combo += 1; s.comboT = 0.5;
      s.mult = (1 + Math.min(s.combo, 10) * 0.1) * (s.burst > 0 ? 1.5 : 1);
      s.score += Math.round(pts * s.mult * (s.counterT > 0 ? 2 : 1));
      s.neural = Math.min(100, s.neural + (type === 'special' ? 10 : 6));
      if (s.neural >= 80 && s.burst <= 0) s.burst = 6;
      s.counterT = 0;
      if (type === 'special') showMsg('DRAGON PALM!', '#A855F7');
    } else { s.combo = 0; s.mult = s.burst > 0 ? 1.5 : 1; }
  }, [showMsg]);

  useEffect(() => {
    const act = (a: string, down: boolean) => {
      const s = st.current;
      if (a === 'jab' && down) doStrike('jab');
      if (a === 'kick' && down) doStrike('kick');
      if (a === 'special' && down) doStrike('special');
      if (a === 'block') { if (down) s.block = true; else { s.block = false; s.counterT = 0.15; } }
      if (a === 'left') s.keys['a'] = down;
      if (a === 'right') s.keys['d'] = down;
    };
    const kd = (e: KeyboardEvent) => {
      const k = e.key?.toLowerCase?.() ?? '';
      st.current.keys[k] = true;
      if (k === 'j') doStrike('jab');
      if (k === 'k') doStrike('kick');
      if (k === ';') doStrike('special');
      if (k === 'l') st.current.block = true;
      if (['j', 'k', 'l', ';', 'a', 'd'].includes(k)) e.preventDefault?.();
    };
    const ku = (e: KeyboardEvent) => {
      const k = e.key?.toLowerCase?.() ?? '';
      st.current.keys[k] = false;
      if (k === 'l') { st.current.block = false; st.current.counterT = 0.15; }
    };
    window.addEventListener('keydown', kd);
    window.addEventListener('keyup', ku);
    (window as any).__felKarate3D = { act };
    spawnWave(1);
    return () => {
      window.removeEventListener('keydown', kd);
      window.removeEventListener('keyup', ku);
      delete (window as any).__felKarate3D;
    };
  }, [doStrike, spawnWave]);

  useFrame((_, dtRaw) => {
    const dt = Math.min(dtRaw, 0.05);
    const s = st.current;
    if (endedRef.current) return;
    s.t += dt;
    if (s.msgT > 0) s.msgT -= dt;
    if (s.burst > 0) { s.burst -= dt; if (s.burst <= 0) { s.neural = 0; s.mult = 1 + Math.min(s.combo, 10) * 0.1; } }
    if (s.attack > 0) s.attack -= dt;
    if (s.counterT > 0) s.counterT -= dt;
    if (s.comboT > 0) { s.comboT -= dt; if (s.comboT <= 0) { s.combo = 0; s.mult = s.burst > 0 ? 1.5 : 1; } }

    // gamepad
    if (gamepad) {
      s.keys['a'] = !!gamepad.left; s.keys['d'] = !!gamepad.right;
      if (gamepad.x) doStrike('jab');
      if (gamepad.y) doStrike('kick');
      if (gamepad.b) doStrike('special');
      if (gamepad.lb || gamepad.rb) s.block = true; else if (s.block && !s.keys['l']) { s.block = false; s.counterT = 0.15; }
    }

    // movement
    const mv = 4.2 * (gradeRef.current?.speedMult ?? 1);
    if (s.keys['a']) playerX.current -= mv * dt;
    if (s.keys['d']) playerX.current += mv * dt;
    playerX.current = Math.max(ARENA_MIN, Math.min(ARENA_MAX, playerX.current));

    // face nearest alive foe
    let nearest: FoeState | null = null; let nd = Infinity;
    for (const f of s.foes) { if (f.alive) { const d = Math.abs(f.x - playerX.current); if (d < nd) { nd = d; nearest = f; } } }
    if (nearest) s.pface = nearest.x >= playerX.current ? 1 : -1;

    // foe AI
    const w = s.wave;
    const aggr = Math.min(0.6 + (w - 1) * 0.08, 1.4);
    const spd = (w >= 13 ? 1.15 : 1 + (w - 1) * 0.012) * (gradeRef.current?.speedMult ?? 1);
    let aliveCount = 0;
    for (const f of s.foes) {
      if (!f.alive) continue;
      aliveCount++;
      if (f.flinch > 0) f.flinch = Math.max(0, f.flinch - dt * 3);
      if (f.staggered > 0) { f.staggered -= dt; continue; }
      const dx = playerX.current - f.x;
      if (Math.abs(dx) > 1.7) f.x += Math.sign(dx) * 1.9 * spd * dt;
      f.attackCd -= dt * aggr;
      if (f.attacking > 0) {
        f.attacking -= dt;
        if (f.attacking <= 0 && Math.abs(dx) < 2.0) {
          const facingFoe = (f.x - playerX.current) * s.pface > 0;
          if (s.block && facingFoe) { s.counterT = 0.15; }
          else { s.php -= 7 + w; }
        }
      } else if (f.attackCd <= 0 && Math.abs(dx) < 2.1) {
        f.attacking = 0.3; f.attackCd = Math.max(0.6, 1.6 - aggr * 0.6) + Math.random() * 0.5;
      }
    }
    if (aliveCount === 0) { s.wave += 1; s.score += 5 * s.wave; showMsg(`WAVE ${s.wave}`, '#00E5FF'); spawnWave(s.wave); }

    if (s.php <= 0 && !endedRef.current) {
      endedRef.current = true;
      onEndRef.current?.({ score: s.score, won: s.wave >= 5, duration: Math.round((Date.now() - s.startTime) / 1000), headline: `WAVE ${s.wave} · KO` });
      return;
    }

    // drive avatars — mixer.update is now handled by Avatar's useFrame
    if (playerRef.current) {
      const lunge = s.attack > 0 ? 0.4 : 0;
      playerRef.current.group.position.set(playerX.current + s.pface * lunge, DECK_Y, FIGHT_Z);
      playerRef.current.group.rotation.y = s.pface > 0 ? -Math.PI / 2 : Math.PI / 2;
    }
    for (let i = 0; i < MAX_FOES; i++) {
      const ref = foeRefs.current[i];
      const f = s.foes[i];
      if (!ref) continue;
      ref.group.visible = f.alive;
      if (f.alive) {
        // Foe attack animation
        if (f.attacking > 0 && f.attacking > 0.28) {
          ref.play?.('jab', { loop: false, timeScale: 1.5, fadeIn: 0.05, onFinish: () => {
            ref.play?.('guard', { loop: true, timeScale: 0.85 });
          }});
        }
        const lunge = f.attacking > 0 ? -0.35 : 0;
        ref.group.position.set(f.x + lunge, DECK_Y, FIGHT_Z);
        ref.group.rotation.y = f.x >= playerX.current ? Math.PI / 2 : -Math.PI / 2;
      }
    }

    onHud({
      score: s.score, wave: s.wave, php: s.php, neural: s.neural,
      combo: s.combo, mult: s.mult, burst: s.burst, counter: s.counterT,
      aggr, spd, msg: s.msg, msgColor: s.msgColor, msgT: s.msgT,
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
            playerRef.current = h;
            h.group.rotation.y = -Math.PI / 2;
            h.group.position.set(playerX.current, DECK_Y, FIGHT_Z);
            // Start in guard stance (animated idle)
            h.play('guard', { loop: true, timeScale: 1 });
          }}
        />
      </Suspense>
      {[0, 1, 2].map((i) => (
        <Suspense key={i} fallback={null}>
          <Avatar
            url={HERO_URL}
            tint="#ff5a6e"
            onReady={(h) => {
              foeRefs.current[i] = h;
              h.group.visible = false;
              h.group.rotation.y = Math.PI / 2;
              h.group.position.set(4 + i * 1.6, DECK_Y, FIGHT_Z);
              // Foes loop guard stance with slight speed variation
              h.play('guard', { loop: true, timeScale: 0.85 + i * 0.1 });
            }}
          />
        </Suspense>
      ))}
      <TrackCamera playerX={playerX} />
      <PerfSampler onSample={onPerf} />
    </>
  );
}

export default function Karate3D(props: GameProps) {
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
  const act = (a: string, down: boolean) => (window as any).__felKarate3D?.act(a, down);

  if (!started) {
    return (
      <div className="relative w-full h-full flex flex-col items-center justify-center gap-4 p-6 text-center" style={{ background: '#080604', minHeight: '60vh' }}>
        <h2 className="fel-heading text-4xl text-white">KARATE ENDLESS</h2>
        <p className="max-w-md text-sm text-gray-300">
          Survive escalating waves in the dojo. Chain strikes inside the 0.5s window to build your multiplier and charge Neural Burst.
        </p>
        <div className="grid grid-cols-2 gap-x-8 gap-y-1 font-mono text-xs text-white/55">
          <span>J — Jab (1pt)</span><span>K — Kick (2pt)</span>
          <span>L — Block (hold)</span><span>; — Special (3pt)</span>
          <span>A / D — Move</span><span>Block → 0.15s counter</span>
        </div>
        <button onClick={() => setStarted(true)} className="rounded-lg bg-[#00E5FF] px-8 py-3 font-bold text-black transition hover:bg-[#00c9e0]">FIGHT</button>
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
        camera={{ fov: orient === 'portrait' ? 64 : 54, near: 0.1, far: 200, position: [-1.4, 2.85, 6.8] }}
        scene={{ fog: new THREE.Fog(new THREE.Color(MAP.fogColor), MAP.fogNear, MAP.fogFar) }}
      >
        <PerformanceMonitor
          onIncline={() => setDpr((d) => Math.min(d + 0.25, PERF_BUDGET.dprMax))}
          onDecline={() => setDpr((d) => Math.max(d - 0.25, PERF_BUDGET.dprMin))}
        >
          <DojoLighting />
          <KarateScene {...props} onHud={setHud} onPerf={setPerf} />
        </PerformanceMonitor>
      </Canvas>

      {hud && (
        <div className="absolute inset-0 pointer-events-none" style={{ fontFamily: 'var(--font-display), sans-serif' }}>
          {/* top scoreboard */}
          <div className="absolute top-3 left-1/2 -translate-x-1/2 flex flex-col items-center gap-1">
            <div className="flex items-center gap-4 px-5 py-1.5 rounded-xl" style={{ background: 'rgba(5,5,8,0.75)', backdropFilter: 'blur(12px)', border: '1px solid rgba(0,229,255,0.2)' }}>
              <span className="text-xs text-[#00E5FF] font-mono">WAVE {hud.wave}</span>
              <span className="text-2xl font-bold text-white">{hud.score}</span>
            </div>
            {/* health */}
            <div className="w-60 h-2.5 rounded-full bg-black/60 overflow-hidden mt-0.5">
              <div className="h-full rounded-full transition-all" style={{ width: `${Math.max(0, hud.php)}%`, background: hud.php > 50 ? '#00FF9D' : hud.php > 25 ? '#FFD700' : '#FF3366' }} />
            </div>
          </div>

          {/* PRQ ticker */}
          <div className="absolute top-3 right-3 text-right font-mono text-[11px]">
            <div style={{ color: props.grade?.color ?? '#00FF9D' }}>AGGR {hud.aggr.toFixed(2)} · SPD ×{hud.spd.toFixed(2)}</div>
          </div>

          {/* neural burst bar (left edge) */}
          <div className="absolute left-3 top-1/3 h-1/3 w-2.5 rounded-full bg-black/60 overflow-hidden flex flex-col justify-end">
            <div className="w-full rounded-full transition-all" style={{ height: `${hud.neural}%`, background: hud.burst > 0 ? '#A855F7' : 'linear-gradient(to top,#00E5FF,#A855F7)' }} />
          </div>
          {hud.burst > 0 && <div className="absolute left-7 top-1/2 text-xs font-bold text-[#A855F7] font-mono">NEURAL BURST</div>}

          {/* combo */}
          {hud.combo > 1 && (
            <div className="absolute right-6 top-1/2 -translate-y-1/2 text-center">
              <div className="text-3xl font-bold" style={{ color: hud.burst > 0 ? '#A855F7' : '#00E5FF' }}>×{hud.mult.toFixed(1)}</div>
              <div className="text-xs text-white/70">{hud.combo} CHAIN</div>
            </div>
          )}
          {hud.counter > 0 && <div className="absolute top-2/3 left-1/2 -translate-x-1/2 text-sm font-bold text-[#00FF9D]">COUNTER WINDOW</div>}

          {/* message */}
          {hud.msg && hud.msgT > 0 && (
            <div className="absolute top-[38%] left-1/2 -translate-x-1/2">
              <div className="text-3xl font-bold" style={{ color: hud.msgColor, textShadow: `0 0 20px ${hud.msgColor}55` }}>{hud.msg}</div>
            </div>
          )}

          {/* touch controls */}
          <div className="absolute bottom-3 left-0 right-0 flex items-center justify-between px-3 !hidden pointer-events-auto">
            <div className="flex gap-2">
              <button onClick={() => {}} onTouchStart={() => act('left', true)} onTouchEnd={() => act('left', false)} onMouseDown={() => act('left', true)} onMouseUp={() => act('left', false)} className="h-14 w-14 rounded-full border border-white/20 bg-black/50 text-xl text-white">◀</button>
              <button onTouchStart={() => act('right', true)} onTouchEnd={() => act('right', false)} onMouseDown={() => act('right', true)} onMouseUp={() => act('right', false)} className="h-14 w-14 rounded-full border border-white/20 bg-black/50 text-xl text-white">▶</button>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <button onClick={() => act('kick', true)} className="h-12 w-12 rounded-full border border-[#00FF9D]/50 bg-black/50 text-sm font-bold text-[#00FF9D]">KICK</button>
              <button onClick={() => act('special', true)} className="h-12 w-12 rounded-full border border-[#A855F7]/50 bg-black/50 text-[10px] font-bold text-[#A855F7]">SPCL</button>
              <button onClick={() => act('jab', true)} className="h-12 w-12 rounded-full border border-[#00E5FF]/50 bg-black/50 text-sm font-bold text-[#00E5FF]">JAB</button>
              <button onPointerDown={() => act('block', true)} onPointerUp={() => act('block', false)} onPointerLeave={() => act('block', false)} className="h-12 w-12 rounded-full border border-[#FFD700]/50 bg-black/50 text-[10px] font-bold text-[#FFD700]">BLOCK</button>
            </div>
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
