// ModeHarness — every Babylon mode runs through this: scene boot, LightRig,
// InputBus, READY gate + 3-2-1, pause, update loop, SessionResult emit.

import { Engine, Scene, TargetCamera, Vector3 } from '@babylonjs/core';
import { mountLightRig, liftBlackMaterials, type LightRigHandle } from '../../scene/LightRig';
import type { VenueMood } from '../../scene/moods';
import { InputBus, type FelInput } from './InputBus';
import { CameraDirector, type FOLLOW_PRESETS } from './CameraDirector';
import { buildResult, defaultResultSink, type ResultSink, type SessionResult } from './sessionResult';

export type ModePhase = 'loading' | 'ready' | 'countdown' | 'playing' | 'paused' | 'ended';

export interface ModeContext {
  scene: Scene;
  camera: TargetCamera;
  camDirector: CameraDirector;
  input: InputBus;
  lights: LightRigHandle;
  /** current phase — modes may read, never write */
  phase(): ModePhase;
  end(outcome: string, score: number, stats: Record<string, number>): void;
  setHud(update: Record<string, string | number>): void;   // bezel HUD bridge
}

export interface ModeDefinition {
  modeId: string;
  mood: VenueMood;
  camPreset: keyof typeof FOLLOW_PRESETS;
  load(ctx: ModeContext): Promise<void>;        // spawn venue + characters
  onInput(ctx: ModeContext, e: FelInput): void;
  update(ctx: ModeContext, dt: number): void;   // called only while 'playing'
  dispose?(): void;
}

export interface HarnessOpts {
  canvas: HTMLCanvasElement;
  onPhase?: (p: ModePhase, countdown?: number) => void;   // drives READY/3-2-1 UI
  onHud?: (hud: Record<string, string | number>) => void;
  resultSink?: ResultSink;
}

export async function runMode(def: ModeDefinition, opts: HarnessOpts): Promise<() => void> {
  const engine = new Engine(opts.canvas, true, { adaptToDeviceRatio: true });
  const scene = new Scene(engine);
  const camera = new TargetCamera('cam', new Vector3(0, 3, -8), scene);
  const lights = mountLightRig(scene, def.mood);
  const input = new InputBus();
  const camDirector = new CameraDirector(scene, camera, def.camPreset);

  let phase: ModePhase = 'loading';
  let startedAt = 0;
  let unsub: (() => void) | null = null;
  const setPhase = (p: ModePhase, cd?: number) => { phase = p; opts.onPhase?.(p, cd); };

  const ctx: ModeContext = {
    scene, camera, camDirector, input, lights,
    phase: () => phase,
    end(outcome, score, stats) {
      if (phase === 'ended') return;
      setPhase('ended');
      const result: SessionResult = buildResult(def.modeId, outcome, score, stats, startedAt);
      (opts.resultSink ?? defaultResultSink)(result);
    },
    setHud(update) { opts.onHud?.(update); },
  };

  await def.load(ctx);
  liftBlackMaterials(scene);                     // rescue anything venue-load added
  setPhase('ready');

  input.start();
  unsub = input.on((e) => {
    // READY gate: only the first press starts; gameplay input ignored until GO
    if (phase === 'ready' && e.t === 'button' && e.pressed) { startCountdown(); return; }
    if (phase === 'playing' && e.t === 'button' && e.btn === 'START' && e.pressed) { setPhase('paused'); return; }
    if (phase === 'paused' && e.t === 'button' && e.pressed) { setPhase('playing'); return; }
    if (phase === 'playing' && e.t === 'button' && e.btn === 'SELECT' && e.pressed) { camDirector.toggle(); return; }
    if (phase === 'playing') def.onInput(ctx, e);
  });

  function startCountdown(): void {
    setPhase('countdown', 3);
    let n = 3;
    const tick = setInterval(() => {
      n--;
      if (n <= 0) {
        clearInterval(tick);
        startedAt = performance.now();
        setPhase('playing');
      } else {
        opts.onPhase?.('countdown', n);
      }
    }, 800);
  }

  engine.runRenderLoop(() => {
    const dt = engine.getDeltaTime() / 1000;
    if (phase === 'playing') def.update(ctx, dt);
    scene.render();
  });
  const onResize = () => engine.resize();
  window.addEventListener('resize', onResize);

  return () => {
    window.removeEventListener('resize', onResize);
    unsub?.();
    input.stop();
    def.dispose?.();
    lights.dispose();
    scene.dispose();
    engine.dispose();
  };
}
