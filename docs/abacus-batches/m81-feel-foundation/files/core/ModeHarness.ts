// ModeHarness v3 — REPLACES M26/M29.
//
// THE BUG THIS FIXES: "you need to refresh the page for the games to load."
//
// v1 and v2 both look like this:
//
//     export async function runMode(def, opts): Promise<() => void> {
//       const engine = new Engine(opts.canvas, ...);   // context allocated HERE
//       ...
//       await def.load(ctx);                            // 2-5 seconds, or 20 with
//                                                       // M29's watchdog
//       ...
//       return () => { ... engine.dispose(); };         // disposer arrives LAST
//     }
//
// The WebGL context is allocated on the first line and the only way to free it
// is returned on the last. In between there is a multi-second window in which
// the caller has NO WAY to clean up. If the component unmounts in that window
// — a route change, a back button, React 18 StrictMode's deliberate
// double-invoke — the engine, its render loop and its context leak. Nothing
// can ever reclaim them.
//
// Browsers cap live WebGL contexts (Chrome ~16, Safari ~8). Past the cap they
// drop the oldest or refuse the new one, and `new Engine(canvas)` yields a
// black canvas with NO exception. A full page reload is the only thing that
// frees them. That is the reported symptom exactly, including "each time",
// because the count only grows within a session.
//
// v3 changes three things:
//   1. runMode returns a handle SYNCHRONOUSLY. The caller can always dispose,
//      including one millisecond in.
//   2. Loading is cancellable. Disposing mid-load abandons the result instead
//      of mounting into a dead scene.
//   3. Teardown is ordered, complete, idempotent, and survives a throwing
//      step (see Teardown.ts). Previously one bad disposer stranded every
//      step after it — and `engine.dispose()` was last.
//
// It also keeps M29's error phase and load watchdog. An infinite spinner is
// still impossible.

import { Engine, Scene, TargetCamera, Vector3 } from '@babylonjs/core';
import { mountLightRig, liftBlackMaterials, type LightRigHandle } from '../scene/LightRig';
import type { VenueMood } from '../scene/moods';
import { InputBus, type FelInput } from './InputBus';
import { CameraDirector, type FOLLOW_PRESETS } from './CameraDirector';
import { buildResult, defaultResultSink, type ResultSink, type SessionResult } from './sessionResult';
import { Teardown, engineCount } from './Teardown';

export type ModePhase = 'loading' | 'ready' | 'countdown' | 'playing' | 'paused' | 'ended' | 'error';

export interface ModeContext {
  scene: Scene; camera: TargetCamera; camDirector: CameraDirector;
  input: InputBus; lights: LightRigHandle;
  phase(): ModePhase;
  end(outcome: string, score: number, stats: Record<string, number>): void;
  setHud(update: Record<string, string | number>): void;
  /** Register mode-owned cleanup. Runs before the scene is disposed. */
  onDispose(label: string, fn: () => void): void;
  /** True once teardown has begun — check this after any `await` in load(). */
  cancelled(): boolean;
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

export interface ModeHandle {
  /** Idempotent. Safe at any time, including during load. */
  dispose(): void;
  /** Resolves true if the mode loaded, false if it failed or was cancelled. */
  ready: Promise<boolean>;
  /** Re-attempt after an error. No-op once disposed. */
  retry(): void;
  phase(): ModePhase;
}

const LOAD_WATCHDOG_MS = 20_000;
/** Cap the backing buffer. A 3× phone otherwise renders 9× the pixels for no
 *  visible gain and a third of the framerate. */
const MAX_DEVICE_PIXEL_RATIO = 2;

/**
 * One engine per canvas, enforced.
 *
 * React 18 StrictMode mounts, unmounts and remounts every effect in dev. Even
 * with correct cleanup that is two engines on one canvas for a moment; with a
 * missed cleanup it is two forever. Anything already on this canvas gets
 * disposed before we build on it.
 */
const CANVAS_OWNER = new WeakMap<HTMLCanvasElement, ModeHandle>();

export function runMode(def: ModeDefinition, opts: HarnessOpts): ModeHandle {
  CANVAS_OWNER.get(opts.canvas)?.dispose();

  const teardown = new Teardown();
  let disposed = false;
  let phase: ModePhase = 'loading';
  let startedAt = 0;
  let countdownTimer: ReturnType<typeof setInterval> | null = null;
  let watchdog: ReturnType<typeof setTimeout> | null = null;

  const setPhase = (p: ModePhase, detail?: number | string) => {
    if (disposed) return;                       // never narrate a dead mode
    phase = p;
    opts.onPhase?.(p, detail);
  };

  const engine = new Engine(opts.canvas, true, { adaptToDeviceRatio: true });
  engine.setHardwareScalingLevel(1 / Math.min(window.devicePixelRatio || 1, MAX_DEVICE_PIXEL_RATIO));
  engineCount.open();
  // Registered FIRST so it runs LAST — the context is the most expensive
  // thing to leak and must be freed even if everything above it fails.
  teardown.add('engine', () => { engine.stopRenderLoop(); engine.dispose(); engineCount.close(); });

  const scene = new Scene(engine);
  teardown.add('scene', () => scene.dispose());

  const camera = new TargetCamera('cam', new Vector3(0, 3, -8), scene);
  const lights = mountLightRig(scene, def.mood);
  teardown.add('lights', () => lights.dispose());

  const input = new InputBus();
  teardown.add('input', () => input.stop());

  const camDirector = new CameraDirector(scene, camera, def.camPreset);

  const onResize = () => engine.resize();
  window.addEventListener('resize', onResize);
  teardown.add('resize listener', () => window.removeEventListener('resize', onResize));
  teardown.add('timers', () => {
    if (countdownTimer) clearInterval(countdownTimer);
    if (watchdog) clearTimeout(watchdog);
  });

  const ctx: ModeContext = {
    scene, camera, camDirector, input, lights,
    phase: () => phase,
    cancelled: () => disposed,
    onDispose: (label, fn) => teardown.add(`mode:${label}`, fn),
    end(outcome, score, stats) {
      if (phase === 'ended' || disposed) return;
      setPhase('ended');
      const result: SessionResult = buildResult(def.modeId, outcome, score, stats, startedAt);
      void (opts.resultSink ?? defaultResultSink)(result);
    },
    setHud(update) { if (!disposed) opts.onHud?.(update); },
  };
  teardown.add('mode', () => def.dispose?.());

  // ── loading, cancellable ──────────────────────────────────────────────
  async function attemptLoad(): Promise<boolean> {
    if (disposed) return false;
    setPhase('loading');
    let timedOut = false;
    watchdog = setTimeout(() => {
      timedOut = true;
      setPhase('error', 'Load timed out — check your connection and retry.');
    }, LOAD_WATCHDOG_MS);

    try {
      await def.load(ctx);
      if (watchdog) { clearTimeout(watchdog); watchdog = null; }
      // Two distinct ways this can be stale by the time it resolves.
      if (disposed) return false;
      if (timedOut) return false;
      liftBlackMaterials(scene);
      setPhase('ready');
      return true;
    } catch (e) {
      if (watchdog) { clearTimeout(watchdog); watchdog = null; }
      if (disposed) return false;
      console.error(`[FEL-MODE] ${def.modeId} load failed:`, e);
      setPhase('error', e instanceof Error ? e.message : 'Failed to load the arena.');
      return false;
    }
  }

  function startCountdown(): void {
    setPhase('countdown', 3);
    let n = 3;
    countdownTimer = setInterval(() => {
      if (disposed) { if (countdownTimer) clearInterval(countdownTimer); return; }
      n--;
      if (n <= 0) {
        if (countdownTimer) clearInterval(countdownTimer);
        countdownTimer = null;
        startedAt = performance.now();
        setPhase('playing');
      } else {
        opts.onPhase?.('countdown', n);
      }
    }, 800);
  }

  input.start();
  const unsub = input.on((e) => {
    if (disposed) return;
    if (phase === 'error' && e.t === 'button' && e.pressed) { void attemptLoad(); return; }
    if (phase === 'ready' && e.t === 'button' && e.pressed) { startCountdown(); return; }
    if (phase === 'playing' && e.t === 'button' && e.btn === 'START' && e.pressed) { setPhase('paused'); return; }
    if (phase === 'paused' && e.t === 'button' && e.pressed) { setPhase('playing'); return; }
    if (phase === 'playing' && e.t === 'button' && e.btn === 'SELECT' && e.pressed) { camDirector.toggle(); return; }
    if (phase === 'playing') def.onInput(ctx, e);
  });
  teardown.add('input subscription', unsub);

  // The render loop starts NOW, before load resolves. The scene is empty, but
  // it is a live, resizing, disposable surface — and starting it here means
  // there is never a window where a running engine has no owner.
  engine.runRenderLoop(() => {
    if (disposed) return;
    const dt = engine.getDeltaTime() / 1000;
    if (phase === 'playing') def.update(ctx, dt);
    scene.render();
  });

  const handle: ModeHandle = {
    phase: () => phase,
    dispose() {
      if (disposed) return;
      disposed = true;
      teardown.run();
      if (CANVAS_OWNER.get(opts.canvas) === handle) CANVAS_OWNER.delete(opts.canvas);
    },
    retry() { if (!disposed) void attemptLoad(); },
    // Kicked off AFTER the handle exists, so `dispose()` is reachable from the
    // very first millisecond. This ordering is the whole fix.
    ready: Promise.resolve().then(attemptLoad),
  };

  CANVAS_OWNER.set(opts.canvas, handle);
  return handle;
}

/**
 * Back-compat shim for callers still doing `const stop = await runMode(...)`.
 *
 * It restores the exact old signature — and the exact old bug, because the
 * disposer is still unreachable until load resolves. It exists so a migration
 * can be staged rather than big-bang, and it warns every time it is used.
 * Delete it once every call site is on `runMode`.
 */
export async function runModeLegacy(def: ModeDefinition, opts: HarnessOpts): Promise<() => void> {
  console.warn('[FEL-MODE] runModeLegacy: the disposer is unreachable until load resolves, '
    + 'which is the WebGL-context leak behind "refresh to load". Migrate to runMode().');
  const h = runMode(def, opts);
  await h.ready;
  return () => h.dispose();
}
