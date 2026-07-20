// GhostSystem — record your run as a compact ghost; play a rival's ghost as a
// translucent shadow in the same arena. This is what makes the contest "head
// to head": you dunk WITH the other competitor's actual run beside you.

import { Vector3 } from '@babylonjs/core';
import type { Scene } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { neverBindPose } from '../anim/importSanitizer';

// Frame: [tMs, x, y, z, yawRad, clipIndex] — 10 Hz ⇒ a 30 s run ≈ 6 KB JSON.
type GhostFrame = [number, number, number, number, number, number];
export interface GhostData { v: 1; clips: string[]; frames: GhostFrame[] }

const HZ = 10;
const r3 = (n: number) => Math.round(n * 1000) / 1000;

// ── Recorder ───────────────────────────────────────────────────────────────
export class GhostRecorder {
  private frames: GhostFrame[] = [];
  private clips: string[] = [];
  private t0 = 0;
  private lastSample = -1;

  start(): void { this.frames = []; this.clips = []; this.t0 = performance.now(); this.lastSample = -1; }

  /** Call every update() with the live character. */
  sample(char: SpawnedCharacter): void {
    const tMs = performance.now() - this.t0;
    if (tMs - this.lastSample < 1000 / HZ) return;
    this.lastSample = tMs;
    const clip = char.animator.currentClip ?? 'idle_stand';
    let ci = this.clips.indexOf(clip);
    if (ci < 0) { this.clips.push(clip); ci = this.clips.length - 1; }
    const p = char.root.position;
    this.frames.push([Math.round(tMs), r3(p.x), r3(p.y), r3(p.z), r3(char.root.rotation.y), ci]);
  }

  serialize(): string {
    return JSON.stringify({ v: 1, clips: this.clips, frames: this.frames } satisfies GhostData);
  }
}

// ── Playback ───────────────────────────────────────────────────────────────
export class GhostPlayback {
  private char: SpawnedCharacter | null = null;
  private data: GhostData;
  private t0 = 0;
  private clipNow = '';
  private obs: ReturnType<Scene['onBeforeRenderObservable']['add']> | null = null;

  constructor(private scene: Scene, serialized: string) {
    this.data = JSON.parse(serialized) as GhostData;
    if (this.data.v !== 1 || !Array.isArray(this.data.frames)) throw new Error('bad ghost data');
  }

  async spawn(heroUrl: string): Promise<void> {
    this.char = await CharacterLibrary.spawn(this.scene, heroUrl, {
      position: new Vector3(...this.firstPos()), tint: '#22d3ee',
      startClip: 'idle_stand',
    });
    neverBindPose(this.char.animator, 'idle_stand');
    // shadow look: translucent, no shadows cast
    for (const m of this.char.meshes) {
      m.visibility = 0.42;
      m.receiveShadows = false;
    }
  }
  private firstPos(): [number, number, number] {
    const f = this.data.frames[0];
    return f ? [f[1], f[2], f[3]] : [2.5, 0, 8.5];
  }

  /** Start replaying alongside the live run. */
  play(): void {
    if (!this.char) return;
    this.t0 = performance.now();
    this.obs = this.scene.onBeforeRenderObservable.add(() => this.tick());
  }

  private tick(): void {
    if (!this.char) return;
    const t = performance.now() - this.t0;
    const fr = this.data.frames;
    if (!fr.length) return;
    // find bracketing frames, interpolate
    let i = fr.findIndex((f) => f[0] > t);
    if (i < 0) i = fr.length - 1;                        // ghost finished — hold last
    const b = fr[Math.max(0, i)], a = fr[Math.max(0, i - 1)];
    const span = Math.max(1, b[0] - a[0]);
    const k = Math.max(0, Math.min(1, (t - a[0]) / span));
    this.char.root.position.set(
      a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k,
    );
    this.char.root.rotation.y = a[4] + (b[4] - a[4]) * k;
    const clip = this.data.clips[b[5]] ?? 'idle_stand';
    if (clip !== this.clipNow) {
      this.clipNow = clip;
      this.char.animator.play(clip, { loop: clip.includes('idle') || clip.includes('run'), fadeSec: 0.1 });
    }
  }

  dispose(): void {
    if (this.obs) this.scene.onBeforeRenderObservable.remove(this.obs);
    this.char?.dispose();
    this.char = null;
  }
}

// NOTE: SpawnedCharacter needs `meshes` (the instantiated meshes array — the
// M30 CharacterLibrary already collects it; expose it on the return object)
// and CharacterAnimator needs `currentClip: string | null` (set it inside
// play() — one line). Both marked in those files' comments.
