// CameraDirector — Follow / Fixed cams with the M13-03 constraints: subject +
// objective framed, ground visible, occlusion pull-in, no autonomous switching.
// (Cinematic tracks are owned by MovieEvents/DunkReplayCam.)

import { Ray, TargetCamera, Vector3 } from '@babylonjs/core';
import type { Scene, AbstractMesh } from '@babylonjs/core';

export type CamMode = 'follow' | 'fixed';

export interface FollowConfig {
  distance: number;        // spring-arm length
  height: number;          // above subject
  minHeight: number;       // NEVER below (ground-visibility rule)
  pitchFloorDeg: number;   // min downward pitch on fast modes
  lag: number;             // 0..1 smoothing
  lookAhead: number;       // meters ahead of velocity
}

export const FOLLOW_PRESETS: Record<string, FollowConfig> = {
  court:  { distance: 7.5, height: 3.2, minHeight: 1.6, pitchFloorDeg: 10, lag: 0.10, lookAhead: 1.5 },
  runner: { distance: 8.5, height: 4.2, minHeight: 2.2, pitchFloorDeg: 14, lag: 0.08, lookAhead: 3.0 },
  board:  { distance: 6.5, height: 3.0, minHeight: 2.0, pitchFloorDeg: 16, lag: 0.12, lookAhead: 4.0 },
  fight:  { distance: 6.0, height: 2.6, minHeight: 1.8, pitchFloorDeg: 8,  lag: 0.15, lookAhead: 0.5 },
};

export class CameraDirector {
  public mode: CamMode = 'follow';
  private cfg: FollowConfig;
  private fixedPos: Vector3 | null = null;
  private lastSubject = Vector3.Zero();
  /** while true (movie events / replay own the camera) the director is idle */
  public suspended = false;

  constructor(
    private scene: Scene,
    private camera: TargetCamera,
    preset: keyof typeof FOLLOW_PRESETS = 'court',
  ) {
    this.cfg = FOLLOW_PRESETS[preset];
  }

  setPreset(preset: keyof typeof FOLLOW_PRESETS): void { this.cfg = FOLLOW_PRESETS[preset]; }
  setFixed(position: Vector3): void { this.mode = 'fixed'; this.fixedPos = position.clone(); }
  toggle(): void { this.mode = this.mode === 'follow' ? 'fixed' : 'follow'; }

  /** Call every frame. objective = ball/rim/target/gate — kept in frame. */
  update(subject: Vector3, velocity: Vector3, objective: Vector3 | null): void {
    if (this.suspended) return;
    this.lastSubject.copyFrom(subject);

    if (this.mode === 'fixed' && this.fixedPos) {
      this.camera.position = Vector3.Lerp(this.camera.position, this.fixedPos, 0.1);
      this.camera.setTarget(objective ? Vector3.Lerp(subject, objective, 0.35) : subject);
      return;
    }

    const cfg = this.cfg;
    const back = velocity.lengthSquared() > 0.01
      ? velocity.normalizeToNew().scaleInPlace(-1)
      : this.camera.position.subtract(subject).normalize();
    back.y = 0; back.normalize();

    const desired = subject
      .add(back.scale(cfg.distance))
      .add(new Vector3(0, cfg.height, 0));

    // Ground rule: never below minHeight above the subject's ground plane
    desired.y = Math.max(desired.y, subject.y + cfg.minHeight);

    // Occlusion probe: pull in if static geometry blocks the view (dojo pillar)
    const toCam = desired.subtract(subject);
    const ray = new Ray(subject.add(new Vector3(0, 1.2, 0)), toCam.normalizeToNew(), toCam.length());
    const hit = this.scene.pickWithRay(ray, (m: AbstractMesh) => m.isPickable && m.checkCollisions);
    const finalPos = hit?.hit && hit.pickedPoint
      ? hit.pickedPoint.subtract(toCam.normalizeToNew().scale(0.3))
      : desired;

    this.camera.position = Vector3.Lerp(this.camera.position, finalPos, 1 - Math.pow(1 - cfg.lag, 1));

    const ahead = subject.add(velocity.normalizeToNew().scale(cfg.lookAhead));
    const target = objective ? Vector3.Lerp(ahead, objective, 0.35) : ahead;
    this.camera.setTarget(target);

    // Pitch floor: guarantee the ground is readable at speed
    const pitch = Math.atan2(this.camera.position.y - target.y,
      Vector3.Distance(new Vector3(this.camera.position.x, 0, this.camera.position.z), new Vector3(target.x, 0, target.z)));
    const floor = (this.cfg.pitchFloorDeg * Math.PI) / 180;
    if (pitch < floor) {
      this.camera.position.y = target.y + Math.tan(floor) *
        Vector3.Distance(new Vector3(this.camera.position.x, 0, this.camera.position.z), new Vector3(target.x, 0, target.z));
    }
  }
}
