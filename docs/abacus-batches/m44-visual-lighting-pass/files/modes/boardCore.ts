// boardCore v3 — REPLACES the M42 file. Adds the Tony-Hawk-style MANUAL: a
// combo no longer banks the instant you touch down. There's a grace window
// (1.4s) after landing to start another trick before the combo banks — ride
// clean through the gap and the multiplier keeps growing across MULTIPLE
// separate airs, not just one. Wait too long, or bail, and it banks/resets.
// This is what turns "land tricks" into "chain a run," the actual skill
// expression these games are built around. Also wires SoundKit: a rising
// chime on every clean landing (pitch scales with combo), a whoosh on grabs,
// a thud on bails, a click as the manual window ticks down under 0.4s left
// (so the player FEELS the window closing, not just sees a number).

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh, Scene } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Rider, type GrindLine } from '../core/GroundRide';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
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

const MANUAL_WINDOW_SEC = 1.4;

export class TrickMachine {
  score = 0; combo = 0; comboPts = 0;
  private active: TrickDef | null = null;
  private spun = 0;
  private grabbing = false;
  private manualSec = 0;                    // counts DOWN while grounded+idle with a live combo
  private clickedUnder = false;

  constructor(private rig: BoardRig, private onHud: (h: Record<string, unknown>) => void) {}

  start(t: TrickDef): void {
    if (this.rig.rider.grounded && t.turns === 0 && t.name === 'OLLIE') this.rig.rider.jump(0.6);
    if (this.rig.rider.grounded) return;
    this.active = t;
    this.spun = 0;
    this.manualSec = 0;
    if (t.clip) {
      this.grabbing = true;
      SoundKit.play('whoosh', { pitch: 1.2, volume: 0.5 });
      this.rig.char.animator.play(t.clip, { loop: true });
    }
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
        this.manualSec = MANUAL_WINDOW_SEC;              // THE FIX: open the manual window
        this.clickedUnder = false;
        this.rig.char.animator.play(SPORT_CLIP.jumpLand, {});
        SoundKit.play('score', { pitch: 0.85 + this.combo * 0.06, volume: 0.5 });
        const scene = this.rig.char.root.getScene();
        if (scene) EffectsKit.burst(scene, this.rig.char.root.position.clone(), 'dust');
        this.onHud({ combo: `${this.combo}x`, manual: true });
        return `${t.name} +${t.pts * this.combo}`;
      }
      this.bail();
      return 'BAILED';
    }

    // MANUAL WINDOW — combo stays alive on the ground for a beat
    if (!this.active && r.grounded && this.manualSec > 0) {
      this.manualSec -= dt;
      if (this.manualSec <= 0.4 && !this.clickedUnder) {
        this.clickedUnder = true;
        SoundKit.play('uiTick', { pitch: 1.6 });
      }
      if (this.manualSec <= 0) this.bank();
      return null;
    }

    if (!this.active && r.grounded && this.comboPts > 0 && this.manualSec <= 0) {
      this.bank();
    }
    return null;
  }

  private bank(): void {
    this.score += this.comboPts;
    this.onHud({ score: this.score, combo: '', manual: false });
    this.comboPts = 0; this.combo = 0; this.manualSec = 0;
  }

  bail(): void {
    this.active = null; this.grabbing = false;
    this.comboPts = 0; this.combo = 0; this.manualSec = 0;
    this.rig.rider.vel.scaleInPlace(0.25);
    SoundKit.play('impact', { pitch: 0.7, volume: 0.4 });
    const scene = this.rig.char.root.getScene();
    if (scene) EffectsKit.burst(scene, this.rig.char.root.position.clone(), 'dust');
    this.rig.char.animator.play(SPORT_CLIP.boardBail, {});
    this.onHud({ combo: '', manual: false });
  }

  bankGrind(line: GrindLine): void {
    this.combo++;
    this.comboPts += line.bonus * this.combo;
    this.manualSec = MANUAL_WINDOW_SEC;
    const scene = this.rig.char.root.getScene();
    if (scene) EffectsKit.burst(scene, this.rig.char.root.position.clone(), 'sparks');
  }
}
