// CameraDirector v2 — REPLACES the M26 file. Fixes E9 (the whole-game framing
// failure): cameras aimed at feet/ground with no pitch cap, so heroes sat at
// the bottom edge or fully out of frame in every mode. v2 targets CHEST height,
// caps downward pitch, auto-fits two subjects (fight/court), and adds fixed
// presets for the precision sports. API is a superset of v1 — existing
// `update(subject, velocity, objective)` calls keep working, just framed right.

import { Ray, TargetCamera, Vector3 } from '@babylonjs/core';
import type { Scene, AbstractMesh } from '@babylonjs/core';

export type CamMode = 'follow' | 'fixed';

export interface FollowConfig {
  distance: number;         // spring-arm length
  height: number;           // above subject
  minHeight: number;        // never below (ground-visibility rule)
  pitchFloorDeg: number;    // MIN downward pitch (ground readable at speed)
  pitchCapDeg: number;      // MAX downward pitch (E9: stop staring at the floor)
  targetHeight: number;     // aim at chest, not feet — THE core E9 fix
  lag: number;              // 0..1 smoothing
  lookAhead: number;        // meters ahead of velocity
  fitTwo?: boolean;         // frame subject AND objective (fight, court)
}

export const FOLLOW_PRESETS: Record<string, FollowConfig> = {
  court:  { distance: 8.0, height: 2.6, minHeight: 1.5, pitchFloorDeg: 6,  pitchCapDeg: 16, targetHeight: 1.35, lag: 0.10, lookAhead: 1.0, fitTwo: true },
  runner: { distance: 7.5, height: 3.2, minHeight: 2.0, pitchFloorDeg: 10, pitchCapDeg: 22, targetHeight: 1.2,  lag: 0.08, lookAhead: 3.0 },
  board:  { distance: 6.5, height: 2.4, minHeight: 1.6, pitchFloorDeg: 10, pitchCapDeg: 24, targetHeight: 1.1,  lag: 0.12, lookAhead: 4.0 },
  fight:  { distance: 5.2, height: 1.9, minHeight: 1.4, pitchFloorDeg: 4,  pitchCapDeg: 12, targetHeight: 1.15, lag: 0.15, lookAhead: 0.3, fitTwo: true },
};

/** Fixed-camera framings for precision sports (aim → swing → flight). */
export const FIXED_PRESETS: Record<string, { offset: Vector3; targetHeight: number }> = {
  // behind and slightly above the athlete, looking downrange
  swing: { offset: new Vector3(0.9, 2.1, -4.2), targetHeight: 1.2 },
  // low behind the ball for golf/penalty flight
  flight: { offset: new Vector3(0, 1.6, -3.0), targetHeight: 0.6 },
};

export class CameraDirector {
  public mode: CamMode = 'follow';
  private cfg: FollowConfig;
  private fixedPos: Vector3 | null = null;
  private fixedTargetHeight = 1.2;
  public suspended = false;

  constructor(
    private scene: Scene,
    private camera: TargetCamera,
    preset: keyof typeof FOLLOW_PRESETS = 'court',
  ) {
    this.cfg = FOLLOW_PRESETS[preset] ?? FOLLOW_PRESETS.court;
  }

  setPreset(preset: keyof typeof FOLLOW_PRESETS): void {
    this.cfg = FOLLOW_PRESETS[preset] ?? this.cfg;
    this.mode = 'follow';
  }

  setFixed(position: Vector3, targetHeight = 1.2): void {
    this.mode = 'fixed';
    this.fixedPos = position.clone();
    this.fixedTargetHeight = targetHeight;
  }

  /** Fixed cam derived from a subject + facing direction (precision sports). */
  setFixedBehind(subject: Vector3, facingYaw: number, preset: keyof typeof FIXED_PRESETS = 'swing'): void {
    const p = FIXED_PRESETS[preset];
    const sin = Math.sin(facingYaw), cos = Math.cos(facingYaw);
    // rotate the offset into the subject's facing frame
    const off = new Vector3(
      p.offset.x * cos + p.offset.z * sin,
      p.offset.y,
      -p.offset.x * sin + p.offset.z * cos,
    );
    this.setFixed(subject.add(off), p.targetHeight);
  }

  /** SNAP (no lerp) — call once right after spawn so frame ONE is correct.
   *  This is the load-order guarantee FrameGuard verifies. */
  snapTo(subject: Vector3, objective: Vector3 | null): void {
    const cfg = this.cfg;
    const back = objective
      ? subject.subtract(objective).normalize()
      : new Vector3(0, 0, 1);
    back.y = 0;
    if (back.lengthSquared() < 0.01) back.set(0, 0, 1); else back.normalize();
    this.camera.position = subject.add(back.scale(cfg.distance)).add(new Vector3(0, cfg.height, 0));
    this.aim(subject, objective);
  }

  /** Call every frame. objective = ball/rim/gate/opponent — kept in frame. */
  update(subject: Vector3, velocity: Vector3, objective: Vector3 | null): void {
    if (this.suspended) return;

    if (this.mode === 'fixed' && this.fixedPos) {
      this.camera.position = Vector3.Lerp(this.camera.position, this.fixedPos, 0.1);
      const t = objective
        ? Vector3.Lerp(subject.add(new Vector3(0, this.fixedTargetHeight, 0)), objective, 0.4)
        : subject.add(new Vector3(0, this.fixedTargetHeight, 0));
      this.camera.setTarget(t);
      return;
    }

    const cfg = this.cfg;
    let back: Vector3;
    if (cfg.fitTwo && objective) {
      // stand behind the subject, opposite the objective — both stay in frame
      back = subject.subtract(objective);
      back.y = 0;
      if (back.lengthSquared() < 0.01) back.set(0, 0, 1); else back.normalize();
    } else if (velocity.lengthSquared() > 0.01) {
      back = velocity.normalizeToNew().scaleInPlace(-1);
      back.y = 0; back.normalize();
    } else {
      back = this.camera.position.subtract(subject);
      back.y = 0;
      if (back.lengthSquared() < 0.01) back.set(0, 0, 1); else back.normalize();
    }

    // fitTwo: widen with separation so both subjects stay ≥25% frame height
    const separation = cfg.fitTwo && objective ? Vector3.Distance(subject, objective) : 0;
    const dist = cfg.distance + Math.max(0, separation - 3) * 0.55;

    const desired = subject.add(back.scale(dist)).add(new Vector3(0, cfg.height, 0));
    desired.y = Math.max(desired.y, subject.y + cfg.minHeight);

    // occlusion probe (dojo pillars, ramps)
    const toCam = desired.subtract(subject);
    const ray = new Ray(subject.add(new Vector3(0, 1.2, 0)), toCam.normalizeToNew(), toCam.length());
    const hit = this.scene.pickWithRay(ray, (m: AbstractMesh) => m.isPickable && m.checkCollisions);
    const finalPos = hit?.hit && hit.pickedPoint
      ? hit.pickedPoint.subtract(toCam.normalizeToNew().scale(0.3))
      : desired;

    this.camera.position = Vector3.Lerp(this.camera.position, finalPos, cfg.lag);
    this.aim(subject, objective, velocity);
  }

  private aim(subject: Vector3, objective: Vector3 | null, velocity?: Vector3): void {
    const cfg = this.cfg;
    // E9 FIX 1: aim at chest height, never feet
    const chest = subject.add(new Vector3(0, cfg.targetHeight, 0));
    const ahead = velocity && velocity.lengthSquared() > 0.01
      ? chest.add(velocity.normalizeToNew().scale(cfg.lookAhead)) : chest;
    const target = objective
      ? Vector3.Lerp(ahead, objective.add(new Vector3(0, cfg.targetHeight * 0.5, 0)), cfg.fitTwo ? 0.5 : 0.35)
      : ahead;
    this.camera.setTarget(target);

    // E9 FIX 2: pitch clamped into [floor, cap] — never stare at the floor
    const flat = Vector3.Distance(
      new Vector3(this.camera.position.x, 0, this.camera.position.z),
      new Vector3(target.x, 0, target.z),
    );
    const pitch = Math.atan2(this.camera.position.y - target.y, Math.max(flat, 0.001));
    const floor = (cfg.pitchFloorDeg * Math.PI) / 180;
    const cap = (cfg.pitchCapDeg * Math.PI) / 180;
    if (pitch < floor) this.camera.position.y = target.y + Math.tan(floor) * flat;
    if (pitch > cap) this.camera.position.y = target.y + Math.tan(cap) * flat;
    if (pitch < floor || pitch > cap) this.camera.setTarget(target);   // re-aim after clamp
  }
}
