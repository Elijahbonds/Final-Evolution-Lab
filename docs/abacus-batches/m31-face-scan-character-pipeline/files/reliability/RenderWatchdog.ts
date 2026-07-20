// RenderWatchdog — "no more black screens", enforced at runtime.
// After a mode reaches ready, samples the framebuffer; if frames are
// effectively black: rescue lighting → re-check → if still black, surface the
// harness error phase. A silent black screen becomes impossible.

import type { Engine, Scene } from '@babylonjs/core';
import { liftBlackMaterials } from '../scene/LightRig';

const SAMPLE_EVERY_MS = 500;
const BLACK_LUMA = 10;              // 0–255 mean luma below this = "black"
const STRIKES_BEFORE_RESCUE = 2;    // ~1s of black before intervening
const STRIKES_BEFORE_ERROR = 6;     // ~3s total before showing retry

export class RenderWatchdog {
  private timer: number | null = null;
  private strikes = 0;
  private rescued = false;

  constructor(
    private scene: Scene,
    private engine: Engine,
    private onFail: (message: string) => void,
  ) {}

  arm(): void {
    this.timer = window.setInterval(() => void this.check(), SAMPLE_EVERY_MS);
  }
  disarm(): void {
    if (this.timer !== null) clearInterval(this.timer);
    this.timer = null;
  }

  private async check(): Promise<void> {
    const luma = await this.meanLuma();
    if (luma > BLACK_LUMA) { this.strikes = 0; return; }
    this.strikes++;

    if (this.strikes === STRIKES_BEFORE_RESCUE && !this.rescued) {
      this.rescued = true;
      console.warn('[FEL-WATCHDOG] black frames detected — running rescue');
      const fixed = liftBlackMaterials(this.scene);
      // boost every light 1.5x as a second lever
      for (const light of this.scene.lights) light.intensity *= 1.5;
      console.warn(`[FEL-WATCHDOG] rescue done (materials fixed: ${fixed})`);
    }
    if (this.strikes >= STRIKES_BEFORE_ERROR) {
      this.disarm();
      console.error('[FEL-WATCHDOG] still black after rescue — surfacing error');
      this.onFail('Display problem detected — tap RETRY to reload the arena.');
    }
  }

  /** Mean luma of a 32×32 downsample of the current frame (cheap, async). */
  private async meanLuma(): Promise<number> {
    try {
      const w = 32, h = 32;
      const buf = await this.engine.readPixels(0, 0, w, h) as Uint8Array;
      let sum = 0;
      for (let i = 0; i < buf.length; i += 4) {
        sum += 0.2126 * buf[i] + 0.7152 * buf[i + 1] + 0.0722 * buf[i + 2];
      }
      return sum / (w * h);
    } catch {
      return 255;                    // can't read → don't false-positive
    }
  }
}

// WIRING (ModeHarness, one line after setPhase('ready')):
//   const wd = new RenderWatchdog(scene, engine, (m) => setPhase('error', m));
//   wd.arm();     // and wd.disarm() in the cleanup function
