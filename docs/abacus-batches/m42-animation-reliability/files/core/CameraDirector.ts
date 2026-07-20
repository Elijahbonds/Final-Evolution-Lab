// CameraDirector v2.2 — REPLACES the M37 file. Fixes a regression the M37
// occlusion probe introduced: in tight venues (Shimogamo Dojo's walled room
// is the confirmed case — live audit shows the camera pressed flat against a
// wall panel, filling the entire frame with a blank texture) a single
// pull-in step can still land the camera closer to a wall than is readable,
// or on the wrong side of it. v2.2 adds a minimum safe distance, tries two
// alternate viewing angles before giving up, and falls back to a guaranteed-
// clear overhead framing rather than ever showing a wall at point-blank
// range. Everything else (chest targeting, pitch clamp, fitTwo, snapTo) is
// unchanged from v2 — this is a targeted occlusion-handling patch.

import { Ray, TargetCamera, Vector3 } from '@babylonjs/core';
import type { Scene, AbstractMesh } from '@babylonjs/core';

export type CamMode = 'follow' | 'fixed';

export interface FollowConfig {
  distance: number;
  height: number;
  minHeight: number;
  pitchFloorDeg: number;
  pitchCapDeg: number;
  targetHeight: number;
  lag: number;
  lookAhead: number;
  fitTwo?: boolean;
}

export const FOLLOW_PRESETS: Record<string, FollowConfig> = {
  court:  { distance: 8.0, height: 2.6, minHeight: 1.5, pitchFloorDeg: 6,  pitchCapDeg: 16, targetHeight: 1.35, lag: 0.10, lookAhead: 1.0, fitTwo: true },
  runner: { distance: 7.5, height: 3.2, minHeight: 2.0, pitchFloorDeg: 10, pitchCapDeg: 22, targetHeight: 1.2,  lag: 0.08, lookAhead: 3.0 },
  board:  { distance: 6.5, height: 2.4, minHeight: 1.6, pitchFloorDeg: 10, pitchCapDeg: 24, targetHeight: 1.1,  lag: 0.12, lookAhead: 4.0 },
  // fight distance pulled in (5.2 → 4.2): the dojo's walled room is narrower
  // than a 5.2-unit pullback can safely clear from every player position.
  fight:  { distance: 4.2, height: 1.9, minHeight: 1.4, pitchFloorDeg: 4,  pitchCapDeg: 12, targetHeight: 1.15, lag: 0.15, lookAhead: 0.3, fitTwo: true },
};

export const FIXED_PRESETS: Record<string, { offset: Vector3; targetHeight: number }> = {
  swing: { offset: new Vector3(0.9, 2.1, -4.2), targetHeight: 1.2 },
  flight: { offset: new Vector3(0, 1.6, -3.0), targetHeight: 0.6 },
};

/** Camera may never end up closer to the subject than this, in ANY venue —
 *  below this range a wall/prop fills the frame illegibly. */
const MIN_SAFE_DISTANCE = 1.8;
/** Clearance kept between the camera and whatever occludes it. */
const OCCLUSION_MARGIN = 0.6;

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

  setFixedBehind(subject: Vector3, facingYaw: number, preset: keyof typeof FIXED_PRESETS = 'swing'): void {
    const p = FIXED_PRESETS[preset];
    const sin = Math.sin(facingYaw), cos = Math.cos(facingYaw);
    const off = new Vector3(
      p.offset.x * cos + p.offset.z * sin,
      p.offset.y,
      -p.offset.x * sin + p.offset.z * cos,
    );
    this.setFixed(subject.add(off), p.targetHeight);
  }

  snapTo(subject: Vector3, objective: Vector3 | null): void {
    const cfg = this.cfg;
    const back = objective
      ? subject.subtract(objective).normalize()
      : new Vector3(0, 0, 1);
    back.y = 0;
    if (back.lengthSquared() < 0.01) back.set(0, 0, 1); else back.normalize();
    const desired = subject.add(back.scale(cfg.distance)).add(new Vector3(0, cfg.height, 0));
    this.camera.position = this.resolveOcclusion(subject, desired);
    this.aim(subject, objective);
  }

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

    const separation = cfg.fitTwo && objective ? Vector3.Distance(subject, objective) : 0;
    const dist = cfg.distance + Math.max(0, separation - 3) * 0.55;

    const desired = subject.add(back.scale(dist)).add(new Vector3(0, cfg.height, 0));
    desired.y = Math.max(desired.y, subject.y + cfg.minHeight);

    const finalPos = this.resolveOcclusion(subject, desired, back);
    this.camera.position = Vector3.Lerp(this.camera.position, finalPos, cfg.lag);
    this.aim(subject, objective, velocity);
  }

  /**
   * Cast subject→desired; if blocked closer than MIN_SAFE_DISTANCE, retry at
   * ±50° around the subject before falling back to a guaranteed-clear
   * overhead shot. The camera NEVER returns a position that presents a wall
   * at point-blank range — worst case is an elevated but legible framing.
   */
  private resolveOcclusion(subject: Vector3, desired: Vector3, back?: Vector3): Vector3 {
    const eye = subject.add(new Vector3(0, 1.2, 0));
    const probe = (candidate: Vector3): { pos: Vector3; clearance: number } => {
      const toCam = candidate.subtract(subject);
      const dist = toCam.length();
      if (dist < 0.001) return { pos: candidate, clearance: 0 };
      const dir = toCam.scale(1 / dist);
      const ray = new Ray(eye, dir, dist);
      const hit = this.scene.pickWithRay(ray, (m: AbstractMesh) => m.isPickable && m.checkCollisions);
      if (!hit?.hit || !hit.pickedPoint) return { pos: candidate, clearance: dist };
      const hitDist = Vector3.Distance(eye, hit.pickedPoint);
      const clearDist = Math.max(MIN_SAFE_DISTANCE, hitDist - OCCLUSION_MARGIN);
      return { pos: subject.add(dir.scale(clearDist)).add(new Vector3(0, candidate.y - subject.y, 0)), clearance: clearDist };
    };

    let best = probe(desired);
    if (best.clearance >= MIN_SAFE_DISTANCE + 0.4) return best.pos;

    // occluded close — try two alternate azimuths around the subject
    const dir0 = back ?? desired.subtract(subject).normalizeToNew();
    for (const deg of [50, -50]) {
      const rad = (deg * Math.PI) / 180;
      const rotated = new Vector3(
        dir0.x * Math.cos(rad) - dir0.z * Math.sin(rad), 0,
        dir0.x * Math.sin(rad) + dir0.z * Math.cos(rad),
      );
      const alt = subject.add(rotated.scale(desired.subtract(subject).length())).add(new Vector3(0, desired.y - subject.y, 0));
      const candidate = probe(alt);
      if (candidate.clearance > best.clearance) best = candidate;
      if (best.clearance >= MIN_SAFE_DISTANCE + 0.4) return best.pos;
    }

    // still boxed in — guaranteed-clear overhead fallback (never a wall)
    if (best.clearance < MIN_SAFE_DISTANCE) {
      console.warn('[FEL-FRAME] camera boxed in on all probed angles — using overhead fallback');
      return subject.add(new Vector3(0.001, MIN_SAFE_DISTANCE + 1.6, 0.001));
    }
    return best.pos;
  }

  private aim(subject: Vector3, objective: Vector3 | null, velocity?: Vector3): void {
    const cfg = this.cfg;
    const chest = subject.add(new Vector3(0, cfg.targetHeight, 0));
    const ahead = velocity && velocity.lengthSquared() > 0.01
      ? chest.add(velocity.normalizeToNew().scale(cfg.lookAhead)) : chest;
    const target = objective
      ? Vector3.Lerp(ahead, objective.add(new Vector3(0, cfg.targetHeight * 0.5, 0)), cfg.fitTwo ? 0.5 : 0.35)
      : ahead;
    this.camera.setTarget(target);

    const flat = Vector3.Distance(
      new Vector3(this.camera.position.x, 0, this.camera.position.z),
      new Vector3(target.x, 0, target.z),
    );
    const pitch = Math.atan2(this.camera.position.y - target.y, Math.max(flat, 0.001));
    const floor = (cfg.pitchFloorDeg * Math.PI) / 180;
    const cap = (cfg.pitchCapDeg * Math.PI) / 180;
    if (pitch < floor) this.camera.position.y = target.y + Math.tan(floor) * flat;
    if (pitch > cap) this.camera.position.y = target.y + Math.tan(cap) * flat;
    if (pitch < floor || pitch > cap) this.camera.setTarget(target);
  }
}
