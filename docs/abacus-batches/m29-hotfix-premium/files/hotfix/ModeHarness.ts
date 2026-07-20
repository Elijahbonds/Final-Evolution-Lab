// HOTFIX drop-in for M26 ModeHarness: adds the 'error' phase + retry + a 20s
// load watchdog. An infinite spinner is now impossible: load either resolves,
// throws (error screen), or the watchdog fires (error screen).

import { Engine, Scene, TargetCamera, Vector3 } from '@babylonjs/core';
import { mountLightRig, liftBlackMaterials, type LightRigHandle } from '../scene/LightRig';
import type { VenueMood } from '../scene/moods';
import { InputBus, type FelInput } from '../core/InputBus';
import { CameraDirector, type FOLLOW_PRESETS } from '../core/CameraDirector';
import { buildResult, defaultResultSink, type ResultSink, type SessionResult } from '../core/sessionResult';

export type ModePhase = 'loading' | 'ready' | 'countdown' | 'playing' | 'paused' | 'ended' | 'error';

export interface ModeContext {
  scene: Scene; camera: TargetCamera; camDirector: CameraDirector;
  input: InputBus; lights: LightRigHandle;
  phase(): ModePhase;
  end(outcome: string, score: number, stats: Record<string, number>): void;
  setHud(update: Record<string, string | number>): void;
}
export interface ModeDefinition {
  modeId: string; mood: VenueMood; camPreset: keyof typeof FOLLOW_PRESETS;
  load(ctx: ModeContext): Promise<void>;
  onInput(ctx: ModeContext, e: FelInput): void;
  update(ctx: ModeContext, dt: number): void;
  dispose?(): void;
}
export interface HarnessOpts {
  canvas: HTMLCanvasElement;
  onPhase?: (p: ModePhase, detail?: number | string) => void;
  onHud?: (hud: Record<string, string | number>) => void;
  resultSink?: ResultSink;
}

const LOAD_WATCHDOG_MS = 20_000;

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
  const setPhase = (p: ModePhase, detail?: number | string) => { phase = p; opts.onPhase?.(p, detail); };

  const ctx: ModeContext = {
    scene, camera, camDirector, input, lights,
    phase: () => phase,
    end(outcome, score, stats) {
      if (phase === 'ended') return;
      setPhase('ended');
      const result: SessionResult = buildResult(def.modeId, outcome, score, stats, startedAt);
      void (opts.resultSink ?? defaultResultSink)(result);
    },
    setHud(update) { opts.onHud?.(update); },
  };

  // ── Load with watchdog + error phase (the anti-infinite-spinner guarantee) ──
  const attemptLoad = async (): Promise<boolean> => {
    setPhase('loading');
    let timedOut = false;
    const watchdog = setTimeout(() => {
      timedOut = true;
      setPhase('error', 'Load timed out — check connection and retry.');
    }, LOAD_WATCHDOG_MS);
    try {
      await def.load(ctx);
      clearTimeout(watchdog);
      if (timedOut) return false;               // late resolve after watchdog: stay on error
      liftBlackMaterials(scene);
      setPhase('ready');
      return true;
    } catch (e) {
      clearTimeout(watchdog);
      console.error(`[FEL-MODE] ${def.modeId} load failed:`, e);
      setPhase('error', e instanceof Error ? e.message : 'Failed to load the arena.');
      return false;
    }
  };
  await attemptLoad();

  input.start();
  unsub = input.on((e) => {
    // Error phase: any press retries the load (the UI shows a RETRY button too)
    if (phase === 'error' && e.t === 'button' && e.pressed) { void attemptLoad(); return; }
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
      if (n <= 0) { clearInterval(tick); startedAt = performance.now(); setPhase('playing'); }
      else opts.onPhase?.('countdown', n);
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
