// BasketballCore — the optimized movement, shooting, and defense systems
// shared by 1v1 Hoops and 3v3 Streetball. Three pieces:
//   DribbleController — momentum-based movement with a real crossover: a
//     quick direction reversal within a short window snaps your turn
//     instantly (instead of the usual smoothed turn-rate) and pops a burst
//     of speed, at the cost of a brief vulnerability window a defender can
//     read. This is the "movement feels good" system.
//   ShotMeter — a real green-window shot timer: hold to charge, a marker
//     rises through a bar, release inside the green zone for a make. A
//     defender's contest narrows the zone and speeds the marker up — this
//     is the "controls feel good, and defense matters" system.
//   Defender/Teammate AI brains — implement PlayerSlot's AIBehavior
//     interface; the exact same shape a real networked opponent will
//     implement later (see PlayerSlot.ts).

import { Vector3 } from '@babylonjs/core';
import type { AIBehavior, Intent } from './PlayerSlot';

// ── Movement ─────────────────────────────────────────────────────────────
export interface DribbleResult { crossover: boolean; speed01: number; facingRad: number }

export class DribbleController {
  vel = Vector3.Zero();
  facing = 0;
  private lastMoveX = 0; private lastMoveY = 0;
  private reverseWindowSec = 0;
  private crossoverCooldown = 0;

  constructor(private cfg = { maxSpeed: 5.4, accel: 16, decel: 10, turnRate: 9, crossoverBoost: 2.2 }) {}

  update(dt: number, moveX: number, moveY: number, sprint: boolean): DribbleResult {
    this.crossoverCooldown = Math.max(0, this.crossoverCooldown - dt);
    this.reverseWindowSec = Math.max(0, this.reverseWindowSec - dt);

    const mag = Math.hypot(moveX, moveY);
    let crossover = false;

    // crossover: stick reversed hard within the reaction window, and we
    // were already moving with some pace — reads as an intentional shake
    const dot = this.lastMoveX * moveX + this.lastMoveY * moveY;
    if (mag > 0.6 && this.vel.lengthSquared() > 1 && dot < -0.4 && this.crossoverCooldown === 0) {
      crossover = true;
      this.crossoverCooldown = 0.5;
      const dir = new Vector3(moveX, 0, -moveY).normalize();
      this.vel = dir.scale(Math.min(this.cfg.maxSpeed * 1.15, this.vel.length() + this.cfg.crossoverBoost));
      this.facing = Math.atan2(dir.x, dir.z);
    } else if (mag > 0.05) {
      const target = new Vector3(moveX, 0, -moveY).normalize().scale(this.cfg.maxSpeed * (sprint ? 1 : 0.7) * mag);
      const accel = this.cfg.accel * dt;
      this.vel.x += Math.max(-accel, Math.min(accel, target.x - this.vel.x));
      this.vel.z += Math.max(-accel, Math.min(accel, target.z - this.vel.z));
      const wantFacing = Math.atan2(moveX, -moveY);
      let dFace = wantFacing - this.facing;
      while (dFace > Math.PI) dFace -= 2 * Math.PI;
      while (dFace < -Math.PI) dFace += 2 * Math.PI;
      const maxStep = this.cfg.turnRate * dt;
      this.facing += Math.max(-maxStep, Math.min(maxStep, dFace));
    } else {
      const decel = this.cfg.decel * dt;
      const speed = this.vel.length();
      if (speed > 0) this.vel.scaleInPlace(Math.max(0, 1 - decel / Math.max(speed, 0.001)));
    }

    this.lastMoveX = moveX; this.lastMoveY = moveY;
    return { crossover, speed01: Math.min(1, this.vel.length() / this.cfg.maxSpeed), facingRad: this.facing };
  }
}

// ── Shooting ─────────────────────────────────────────────────────────────
export type ShotQuality = 'perfect' | 'good' | 'early' | 'late' | 'brick';

export class ShotMeter {
  active = false;
  t = 0;
  private duration = 0.72;
  private greenCenter = 0.62;
  private greenHalfWidth = 0.09;

  start(contestLevel01: number): void {
    this.active = true; this.t = 0;
    // a tight defender narrows the window and speeds the rise up
    this.duration = 0.72 - contestLevel01 * 0.22;
    this.greenHalfWidth = Math.max(0.035, 0.09 - contestLevel01 * 0.05);
  }
  update(dt: number): number {
    if (!this.active) return 0;
    this.t = Math.min(1, this.t + dt / this.duration);
    return this.t;
  }
  /** Release NOW — call on the actionEdge; returns the quality band. */
  release(): ShotQuality {
    this.active = false;
    const d = this.t - this.greenCenter;
    if (Math.abs(d) <= this.greenHalfWidth * 0.35) return 'perfect';
    if (Math.abs(d) <= this.greenHalfWidth) return 'good';
    if (d < 0) return 'early';
    if (this.t >= 1) return 'brick';
    return 'late';
  }
}
export const SHOT_QUALITY_PCT: Record<ShotQuality, number> = {
  perfect: 0.97, good: 0.8, early: 0.35, late: 0.3, brick: 0.04,
};

// ── AI: defender ─────────────────────────────────────────────────────────
export class DefenderBrain implements AIBehavior {
  constructor(private aggression = 0.6) {}
  decide(_dt: number, self: Vector3, ball: Vector3, hoop: Vector3): Intent {
    // stay between the ball-handler and the hoop, biased toward the ball
    const toHoop = hoop.subtract(self);
    const denyPoint = Vector3.Lerp(ball, hoop, 0.35);
    const toDeny = denyPoint.subtract(self);
    toDeny.y = 0;
    const dist = toDeny.length();
    const closeEnough = dist < 1.4;
    return {
      moveX: closeEnough ? 0 : Math.max(-1, Math.min(1, toDeny.normalize().x)),
      moveY: closeEnough ? 0 : Math.max(-1, Math.min(1, -toDeny.normalize().z)),
      sprint: dist > 3,
      action: false, actionHeld: 0,
      pass: false,
      steal: dist < 1.1 && Math.random() < this.aggression * 0.02,   // occasional steal poke, cheap per-frame odds
    };
  }
}

/** How contested is `ballHandler` right now, 0..1 — feeds ShotMeter.start(). */
export function contestLevel(ballHandler: Vector3, defender: Vector3 | null): number {
  if (!defender) return 0;
  const d = Vector3.Distance(ballHandler, defender);
  return Math.max(0, Math.min(1, 1 - d / 2.2));
}

// ── AI: teammate (3v3) ──────────────────────────────────────────────────
/** Simple spacing: hold a lane away from the ball-handler and defenders,
 *  cut to the hoop when a lane opens. Good enough to read as "playing team
 *  ball" without needing a full playbook system. */
export class TeammateBrain implements AIBehavior {
  constructor(private slotAngle: number, private holdRadius = 5.5) {}
  decide(_dt: number, self: Vector3, ball: Vector3, hoop: Vector3, _allies: Vector3[], foes: Vector3[]): Intent {
    const spot = hoop.add(new Vector3(Math.sin(this.slotAngle) * this.holdRadius, 0, Math.cos(this.slotAngle) * this.holdRadius));
    // if the passing lane to the hoop is clear (no defender within 2u of
    // the cut line), cut hard to the rim instead of holding the spot
    const nearestFoe = foes.reduce<number>((m, f) => Math.min(m, Vector3.Distance(f, self)), 99);
    const cutting = nearestFoe > 3.2 && Vector3.Distance(self, ball) < 8;
    const target = cutting ? hoop : spot;
    const to = target.subtract(self); to.y = 0;
    const dist = to.length();
    if (dist < 0.6) return { moveX: 0, moveY: 0, sprint: false, action: false, actionHeld: 0, pass: false, steal: false };
    const dir = to.normalize();
    return { moveX: dir.x, moveY: -dir.z, sprint: cutting, action: false, actionHeld: 0, pass: false, steal: false };
  }
}

// ── Court helpers ────────────────────────────────────────────────────────
export function clampToHalfCourt(pos: Vector3, halfWidth: number, depth: number): void {
  pos.x = Math.max(-halfWidth, Math.min(halfWidth, pos.x));
  pos.z = Math.max(0.5, Math.min(depth, pos.z));
}
