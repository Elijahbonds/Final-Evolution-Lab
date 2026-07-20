// MobSteering v2 — REPLACES the M26 file. Fixes a universal, high-impact bug
// found auditing "mobs/npcs/opponents" directly: Mob.startPursuit() has been
// playing a clip named 'run_forward' since M26 — the same non-existent clip
// name fixed in DunkMode back in M42, except this copy lives in SHARED
// infrastructure every pursuing enemy in the game uses. Every karate
// opponent and every football defender has likely been T-posing while
// chasing the player this whole time; M42's audit never caught it because it
// only patched mode files, not this shared class. Routed through
// clipRegistry's SPORT_CLIP/installSafePlay so it can't happen again.
//
// Also adds real behavior variety (the "opponent behaviors" gap): a
// `flanker` preset that cuts off at an angle instead of pure-chasing, and a
// brief REACTION DELAY before a fresh mob starts pursuing (real opponents
// don't react to your position instantly — a 120-250ms delay reads as
// "aware," not "psychic," and gives evasions a fair window).

import { Vector3 } from '@babylonjs/core';
import type { SpawnedCharacter } from './CharacterLibrary';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';

export interface SteeringConfig {
  maxSpeed: number;
  turnRateRad: number;
  containmentBias: number;
  giveUpAfterSec?: number;
  reactionSec?: number;        // delay before pursuit actually starts moving
}

export const STEERING_PRESETS: Record<string, SteeringConfig> = {
  // football: cuts off the runner's lane hard — this is the preset football
  // was BUILT for and wasn't using (it was reusing karate's striker/rusher)
  defender: { maxSpeed: 5.2, turnRateRad: 6.0, containmentBias: 0.45, reactionSec: 0.12 },
  rusher:   { maxSpeed: 4.2, turnRateRad: 5.0, containmentBias: 0.1, reactionSec: 0.1 },
  striker:  { maxSpeed: 2.8, turnRateRad: 4.0, containmentBias: 0.0, reactionSec: 0.15 },
  // new: attacks from an angle rather than a straight line — mixed in with
  // straight chasers, a group reads as coordinated instead of a single-file
  // conga line
  flanker:  { maxSpeed: 3.4, turnRateRad: 4.5, containmentBias: 0.65, reactionSec: 0.2 },
  yeti:     { maxSpeed: 7.5, turnRateRad: 3.5, containmentBias: 0.2, giveUpAfterSec: 12, reactionSec: 0.1 },
};

export class Mob {
  public state: 'idle' | 'pursuing' | 'gaveUp' | 'downed' = 'idle';
  private chaseTime = 0;
  private reactionLeft = 0;
  private yaw: number;

  constructor(
    public char: SpawnedCharacter,
    private cfg: SteeringConfig,
  ) {
    this.yaw = char.root.rotation.y;
    installSafePlay(char.animator, 'mob');
    char.animator.play(SPORT_CLIP.idle, { loop: true });
  }

  startPursuit(): void {
    if (this.state === 'downed') return;
    this.state = 'pursuing';
    this.chaseTime = 0;
    this.reactionLeft = this.cfg.reactionSec ?? 0;
    // stay in idle during the reaction beat — the "notices you" delay;
    // switches to the real chase clip once movement actually starts
  }

  /** call every frame with target pos+vel; returns true on CONTACT this frame */
  update(dt: number, targetPos: Vector3, targetVel: Vector3, contactRadius = 0.9): boolean {
    if (this.state !== 'pursuing') return false;

    if (this.reactionLeft > 0) {
      this.reactionLeft -= dt;
      return false;
    }
    if (this.chaseTime === 0) this.char.animator.play(SPORT_CLIP.moveLoop, { loop: true });

    this.chaseTime += dt;
    if (this.cfg.giveUpAfterSec && this.chaseTime > this.cfg.giveUpAfterSec) {
      this.state = 'gaveUp';
      this.char.animator.play(SPORT_CLIP.idle, { loop: true });
      return false;
    }

    const me = this.char.root.position;
    const lead = Vector3.Distance(me, targetPos) / Math.max(this.cfg.maxSpeed, 0.1);
    const predicted = targetPos.add(targetVel.scale(Math.min(lead, 0.6)));
    const toTarget = predicted.subtract(me);
    if (this.cfg.containmentBias > 0) {
      toTarget.x += (targetPos.x - me.x) * this.cfg.containmentBias;
    }
    toTarget.y = 0;
    const dist = toTarget.length();
    if (dist < contactRadius) return true;

    const wantYaw = Math.atan2(toTarget.x, toTarget.z);
    let dYaw = wantYaw - this.yaw;
    while (dYaw > Math.PI) dYaw -= 2 * Math.PI;
    while (dYaw < -Math.PI) dYaw += 2 * Math.PI;
    const maxStep = this.cfg.turnRateRad * dt;
    this.yaw += Math.max(-maxStep, Math.min(maxStep, dYaw));
    this.char.root.rotation.y = this.yaw;

    const speed = Math.min(this.cfg.maxSpeed, dist / dt);
    me.x += Math.sin(this.yaw) * speed * dt;
    me.z += Math.cos(this.yaw) * speed * dt;
    return false;
  }

  onContactResolved(): void {
    this.char.animator.play(SPORT_CLIP.idle, { loop: true, fadeSec: 0.3 });
    this.state = 'idle';
  }

  down(): void {
    this.state = 'downed';
    this.char.animator.play(SPORT_CLIP.karateKnockdown, { fadeSec: 0.1 });
  }
}

/** Staggered updater: spreads N mobs across frames (¼ per frame at 4+ mobs). */
export class MobPool {
  private mobs: Mob[] = [];
  private cursor = 0;
  add(m: Mob): void { this.mobs.push(m); }
  all(): Mob[] { return this.mobs; }
  update(dt: number, targetPos: Vector3, targetVel: Vector3): Mob[] {
    const contacts: Mob[] = [];
    const slice = Math.max(1, Math.ceil(this.mobs.length / 4));
    for (let i = 0; i < slice; i++) {
      const m = this.mobs[(this.cursor + i) % Math.max(this.mobs.length, 1)];
      if (m && m.update(dt * Math.min(4, this.mobs.length), targetPos, targetVel)) contacts.push(m);
    }
    this.cursor = (this.cursor + slice) % Math.max(this.mobs.length, 1);
    return contacts;
  }
  dispose(): void { this.mobs.forEach((m) => m.char.dispose()); this.mobs = []; }
}
