// gameFeel v2 — REPLACES the M37 file. Only change: impact() now also plays
// a synthesized hit sound (SoundKit) so every hit-stop+shake moment across
// every mode gets audio for free — no per-mode wiring needed for the common
// case. Everything else (InputBuffer, Coyote, hitStop/timeScale, Shaker,
// haptic) is unchanged from M37.

import type { Scene, TargetCamera } from '@babylonjs/core';
import { Vector3 } from '@babylonjs/core';
import { SoundKit } from '../audio/SoundKit';

export class InputBuffer {
  private stamps = new Map<string, number>();
  constructor(private windowMs = 140) {}
  press(key: string): void { this.stamps.set(key, performance.now()); }
  consume(key: string): boolean {
    const t = this.stamps.get(key);
    if (t !== undefined && performance.now() - t <= this.windowMs) {
      this.stamps.delete(key);
      return true;
    }
    return false;
  }
  clear(): void { this.stamps.clear(); }
}

export class Coyote {
  private lastTrue = -Infinity;
  constructor(private graceMs = 110) {}
  update(condition: boolean): void { if (condition) this.lastTrue = performance.now(); }
  get ok(): boolean { return performance.now() - this.lastTrue <= this.graceMs; }
}

let stopUntil = 0;
export function hitStop(ms: number): void {
  stopUntil = Math.max(stopUntil, performance.now() + Math.min(ms, 120));
}
export function timeScale(): number {
  const now = performance.now();
  if (now >= stopUntil) return 1;
  const remain = stopUntil - now;
  return remain > 30 ? 0 : 1 - remain / 30;
}

export class Shaker {
  private amp = 0;
  private obs: ReturnType<Scene['onBeforeRenderObservable']['add']> | null = null;
  constructor(private scene: Scene, private camera: TargetCamera) {
    this.obs = scene.onBeforeRenderObservable.add(() => {
      if (this.amp < 0.001) return;
      this.camera.position.addInPlace(new Vector3(
        (Math.random() - 0.5) * this.amp,
        (Math.random() - 0.5) * this.amp * 0.6,
        (Math.random() - 0.5) * this.amp,
      ));
      this.amp *= 0.86;
    });
  }
  kick(strength: number): void { this.amp = Math.min(0.22, Math.max(this.amp, strength * 0.22)); }
  dispose(): void { if (this.obs) this.scene.onBeforeRenderObservable.remove(this.obs); }
}

export function haptic(pattern: number | number[]): void {
  try { navigator.vibrate?.(pattern); } catch { /* unsupported — fine */ }
}

/** Impact bundle: hit-stop + shake + haptic + SOUND, one call. */
export function impact(shaker: Shaker | null, strength: number): void {
  hitStop(30 + strength * 50);
  shaker?.kick(strength);
  haptic(Math.round(8 + strength * 22));
  SoundKit.play('impact', { volume: 0.5 + strength * 0.6, pitch: 0.9 + strength * 0.3 });
}
