// boardCore v2 — REPLACES the M39 file. Wires installSafePlay (clipRegistry)
// into every spawned rider so no board-sport character can ever end up in
// bind pose, and points the trick machine's grab clip at a real clip via
// SPORT_CLIP instead of the placeholder name 'board_grab' (which doesn't
// exist on the live rig and was silently no-opping to a T-pose mid-grab).

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh, Scene } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Rider, type GrindLine } from '../core/GroundRide';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import type { ModeContext } from '../core/ModeHarness';

export interface BoardRig {
  char: SpawnedCharacter;
  rider: Rider;
  board: AbstractMesh;
  dispose(): void;
}

export async function buildRig(
  ctx: ModeContext, heroUrl: string, start: Vector3, yaw: number,
  ground: AbstractMesh[], boardColor: string,
): Promise<BoardRig> {
  if (!ground.length) throw new Error('[FEL-SPAWN] buildRig: no ground meshes — world must be built first');
  const char = await CharacterLibrary.spawn(ctx.scene, heroUrl, {
    position: start, yawRad: yaw, startClip: SPORT_CLIP.boardIdle,
  });
  neverBindPose(char.animator, SPORT_CLIP.boardIdle);
  installSafePlay(char.animator, 'boardCore');
  const board = MeshBuilder.CreateBox('board', { width: 0.26, height: 0.06, depth: 0.84 }, ctx.scene);
  board.parent = char.root;
  board.position.y = 0.03;
  const mat = ctx.makeMat?.(boardColor) ?? null;
  if (mat) board.material = mat;
  const rider = new Rider(ctx.scene, char.root, ground);
  ctx.heroRef = () => char.root;
  ctx.camDirector.setPreset('board');
  ctx.camDirector.snapTo(start, start.add(new Vector3(Math.sin(yaw) * 8, 0, Math.cos(yaw) * 8)));
  return { char, rider, board, dispose: () => { board.dispose(); char.dispose(); } };
}

// ── Trick machine ──────────────────────────────────────────────────────────
export interface TrickDef { name: string; pts: number; spinAxis: 'y' | 'z' | 'x'; turns: number; clip?: string }

export const TRICKS: Record<string, TrickDef> = {
  pop:   { name: 'OLLIE',     pts: 50,  spinAxis: 'y', turns: 0 },
  flipA: { name: 'KICKFLIP',  pts: 120, spinAxis: 'z', turns: 1 },
  flipB: { name: 'HEELFLIP',  pts: 120, spinAxis: 'z', turns: -1 },
  spin:  { name: '360',       pts: 140, spinAxis: 'y', turns: 1 },
  grab:  { name: 'GRAB',      pts: 90,  spinAxis: 'x', turns: 0, clip: SPORT_CLIP.boardGrab },
};

export class TrickMachine {
  score = 0; combo = 0; comboPts = 0;
  private active: TrickDef | null = null;
  private spun = 0;
  private grabbing = false;

  constructor(private rig: BoardRig, private onHud: (h: Record<string, unknown>) => void) {}

  start(t: TrickDef): void {
    if (this.rig.rider.grounded && t.turns === 0 && t.name === 'OLLIE') this.rig.rider.jump(0.6);
    if (this.rig.rider.grounded) return;
    this.active = t;
    this.spun = 0;
    if (t.clip) { this.grabbing = true; this.rig.char.animator.play(t.clip, { loop: true }); }
  }
  endGrab(): void {
    if (this.grabbing) {
      this.grabbing = false;
      this.rig.char.animator.play(SPORT_CLIP.boardIdle, { loop: true });
    }
  }

  update(dt: number): string | null {
    const r = this.rig.rider;
    if (this.active && !r.grounded) {
      const t = this.active;
      const rate = 2 * Math.PI * 2.2 * dt * (t.turns >= 0 ? 1 : -1);
      if (t.turns !== 0) {
        this.spun += Math.abs(rate);
        if (t.spinAxis === 'y') this.rig.char.root.rotation.y += rate;
        if (t.spinAxis === 'z') this.rig.char.root.rotation.z += rate;
      }
      if (this.grabbing) { this.spun += dt * 4; }
      return null;
    }
    if (this.active && r.grounded) {
      const t = this.active;
      this.active = null;
      const needed = Math.abs(t.turns) * 2 * Math.PI * 0.8;
      const clean = t.turns === 0 || this.spun >= needed;
      this.rig.char.root.rotation.z = 0;
      if (clean) {
        this.combo++;
        this.comboPts += t.pts * this.combo;
        this.rig.char.animator.play(SPORT_CLIP.jumpLand, {});
        this.onHud({ combo: `${this.combo}x` });
        return `${t.name} +${t.pts * this.combo}`;
      }
      this.bail();
      return 'BAILED';
    }
    if (!this.active && r.grounded && this.comboPts > 0) {
      this.score += this.comboPts;
      this.onHud({ score: this.score, combo: '' });
      this.comboPts = 0; this.combo = 0;
    }
    return null;
  }

  bail(): void {
    this.active = null; this.grabbing = false;
    this.comboPts = 0; this.combo = 0;
    this.rig.rider.vel.scaleInPlace(0.25);
    this.rig.char.animator.play(SPORT_CLIP.boardBail, {});
    this.onHud({ combo: '' });
  }

  bankGrind(line: GrindLine): void {
    this.combo++;
    this.comboPts += line.bonus * this.combo;
  }
}
