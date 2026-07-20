// MobSteering — pursuit/containment steering for defenders, karate mobs, and
// the yeti chase. Kinematic (no physics engine dependency), staggered updates.

import { Vector3 } from '@babylonjs/core';
import type { SpawnedCharacter } from './CharacterLibrary';

export interface SteeringConfig {
  maxSpeed: number;          // m/s
  turnRateRad: number;       // max yaw change /s (M13-01 slew)
  containmentBias: number;   // 0..1 — lateral cut-off tendency (football defenders)
  giveUpAfterSec?: number;   // chase timeout (yeti ~12)
}

export const STEERING_PRESETS: Record<string, SteeringConfig> = {
  defender: { maxSpeed: 5.2, turnRateRad: 6.0, containmentBias: 0.45 },
  rusher:   { maxSpeed: 4.2, turnRateRad: 5.0, containmentBias: 0.1 },
  striker:  { maxSpeed: 2.8, turnRateRad: 4.0, containmentBias: 0.0 },
  yeti:     { maxSpeed: 7.5, turnRateRad: 3.5, containmentBias: 0.2, giveUpAfterSec: 12 },
};

export class Mob {
  public state: 'idle' | 'pursuing' | 'gaveUp' | 'downed' = 'idle';
  private chaseTime = 0;
  private yaw: number;

  constructor(
    public char: SpawnedCharacter,
    private cfg: SteeringConfig,
  ) {
    this.yaw = char.root.rotation.y;
    char.animator.play('idle_stand', { loop: true });
  }

  startPursuit(): void {
    if (this.state === 'downed') return;
    this.state = 'pursuing';
    this.chaseTime = 0;
    this.char.animator.play('run_forward', { loop: true });
  }

  /** call every frame with target pos+vel; returns true on CONTACT this frame */
  update(dt: number, targetPos: Vector3, targetVel: Vector3, contactRadius = 0.9): boolean {
    if (this.state !== 'pursuing') return false;

    this.chaseTime += dt;
    if (this.cfg.giveUpAfterSec && this.chaseTime > this.cfg.giveUpAfterSec) {
      this.state = 'gaveUp';
      this.char.animator.play('idle_stand', { loop: true });
      return false;
    }

    const me = this.char.root.position;
    // Pursue predicted position; containment biases toward the target's lane
    const lead = Vector3.Distance(me, targetPos) / Math.max(this.cfg.maxSpeed, 0.1);
    const predicted = targetPos.add(targetVel.scale(Math.min(lead, 0.6)));
    const toTarget = predicted.subtract(me);
    if (this.cfg.containmentBias > 0) {
      toTarget.x += (targetPos.x - me.x) * this.cfg.containmentBias;
    }
    toTarget.y = 0;
    const dist = toTarget.length();
    if (dist < contactRadius) return true;         // caller plays tackle/knockdown

    // Yaw slew toward the pursuit direction, then move along facing
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

  /** e.g. yeti swipe or defender wrap landed — play reaction and stand down */
  onContactResolved(): void {
    this.char.animator.play('idle_stand', { loop: true, fadeSec: 0.3 });
    this.state = 'idle';
  }

  down(): void {
    this.state = 'downed';
    this.char.animator.play('karate_knockdown', { fadeSec: 0.1 });
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
