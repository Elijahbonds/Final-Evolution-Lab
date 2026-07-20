// GroundRide v3 — REPLACES the M26 file. Fixes a confirmed live regression:
// on Skate Run, the raycast-based ground snap failed to find the skatepark
// floor and the rider fell forever (observed falling from y=0 to y=-151 and
// still dropping when the sweep ended) — FrameGuard caught it and recentered
// the camera, but the rider kept falling underneath. Root cause is a fragile
// single-point downward raycast: if the rider is ever laterally off every
// ground mesh for one frame (a fast carve, a spawn-frame timing gap, a mesh
// that hasn't finished its bounding-info refresh), gravity has nothing to
// stop it and there is no floor. v3 keeps the same raycast (it's the correct
// primary signal) but adds a HARD FLOOR CLAMP as a last-resort safety net,
// identical in spirit to M35's GroundLock for humanoid characters: the rider
// can never end up below a known-safe floor plane, full stop, regardless of
// what the raycast does on any given frame.

import { Ray, Vector3 } from '@babylonjs/core';
import type { AbstractMesh, Scene, TransformNode } from '@babylonjs/core';

export interface GrindLine {
  a: Vector3; b: Vector3;
  minApproachHeight?: number;
  bonus: number;
}

export class Rider {
  public vel = Vector3.Zero();
  public grounded = true;
  public grinding: GrindLine | null = null;
  private grindT = 0;
  private down = new Vector3(0, -1, 0);
  /** frames since the raycast last found ground — drives the hard-clamp fallback */
  private missedRaycasts = 0;

  constructor(
    private scene: Scene,
    public root: TransformNode,
    private groundMeshes: AbstractMesh[],
    private cfg = {
      gravity: -14, carveAccel: 9, maxSpeed: 16, drag: 0.35, snapHeight: 0.05,
      /** absolute floor — the rider is NEVER allowed below this, raycast or not */
      hardFloorY: 0,
      /** consecutive missed raycasts before the hard clamp takes over */
      missThreshold: 6,
    },
  ) {
    if (!groundMeshes.length) {
      console.error('[FEL-SPAWN] Rider: constructed with zero ground meshes — hard floor clamp is the only thing that will hold the rider up');
    }
  }

  update(dt: number, steer: number, pump: number): void {
    if (this.grinding) { this.updateGrind(dt); return; }

    const yaw = this.root.rotation.y;
    const fwd = new Vector3(Math.sin(yaw), 0, Math.cos(yaw));
    this.vel.addInPlace(fwd.scale((this.cfg.carveAccel * (0.55 + 0.45 * pump)) * dt));
    this.root.rotation.y += steer * 1.9 * dt * (this.grounded ? 1 : 0.5);
    this.root.rotation.z = -steer * 0.28;

    this.vel.scaleInPlace(1 - this.cfg.drag * dt);
    const hSpeed = Math.hypot(this.vel.x, this.vel.z);
    if (hSpeed > this.cfg.maxSpeed) {
      const s = this.cfg.maxSpeed / hSpeed;
      this.vel.x *= s; this.vel.z *= s;
    }

    this.vel.y += this.cfg.gravity * dt;
    this.root.position.addInPlace(this.vel.scale(dt));

    // primary signal: raycast against real ground meshes
    const ray = new Ray(this.root.position.add(new Vector3(0, 1.5, 0)), this.down, 6);
    const hit = this.scene.pickWithRay(ray, (m) => this.groundMeshes.includes(m as AbstractMesh));
    if (hit?.hit && hit.pickedPoint) {
      this.missedRaycasts = 0;
      const groundY = hit.pickedPoint.y;
      if (this.root.position.y <= groundY + this.cfg.snapHeight) {
        this.root.position.y = groundY;
        this.vel.y = 0;
        this.grounded = true;
      } else {
        this.grounded = false;
      }
    } else {
      this.missedRaycasts++;
      this.grounded = false;
    }

    // HARD FLOOR CLAMP — the fix. Once the raycast has failed for several
    // consecutive frames (or at any point the rider is below the absolute
    // floor), stop trusting it and clamp directly. This makes "falling
    // through the world forever" categorically impossible.
    const belowHardFloor = this.root.position.y < this.cfg.hardFloorY - 0.5;
    if (this.missedRaycasts >= this.cfg.missThreshold || belowHardFloor) {
      if (belowHardFloor || this.missedRaycasts >= this.cfg.missThreshold) {
        console.warn(`[FEL-SPAWN] Rider: ${this.missedRaycasts} missed raycasts (y=${this.root.position.y.toFixed(2)}) — hard-clamping to floor`);
      }
      this.root.position.y = this.cfg.hardFloorY;
      this.vel.y = 0;
      this.grounded = true;
      this.missedRaycasts = 0;
    }
  }

  jump(power: number): void {
    if (!this.grounded) return;
    this.vel.y = 5 + power * 5.5;
    this.grounded = false;
  }

  tryGrind(lines: GrindLine[]): GrindLine | null {
    if (this.grounded || this.grinding) return null;
    for (const line of lines) {
      if (line.minApproachHeight && this.root.position.y < line.minApproachHeight) continue;
      const t = closestT(line.a, line.b, this.root.position);
      const point = Vector3.Lerp(line.a, line.b, t);
      if (Vector3.Distance(point, this.root.position) < 1.1) {
        this.grinding = line;
        this.grindT = t;
        this.vel.y = 0;
        return line;
      }
    }
    return null;
  }

  private updateGrind(dt: number): void {
    const line = this.grinding!;
    const len = Vector3.Distance(line.a, line.b);
    const dir = Math.hypot(this.vel.x, this.vel.z) >= 0.5 ? Math.sign(
      Vector3.Dot(line.b.subtract(line.a), this.vel)) || 1 : 1;
    this.grindT += (dir * Math.max(6, Math.hypot(this.vel.x, this.vel.z)) * dt) / len;
    if (this.grindT <= 0 || this.grindT >= 1) { this.dismount(); return; }
    const p = Vector3.Lerp(line.a, line.b, this.grindT);
    this.root.position.copyFrom(p);
    const along = line.b.subtract(line.a).normalize();
    this.root.rotation.y = Math.atan2(along.x, along.z);
    this.root.rotation.z = Math.sin(performance.now() / 180) * 0.06;
  }

  dismount(): void {
    if (!this.grinding) return;
    this.grinding = null;
    this.vel.y = 2.5;
    this.grounded = false;
  }
}

function closestT(a: Vector3, b: Vector3, p: Vector3): number {
  const ab = b.subtract(a);
  const t = Vector3.Dot(p.subtract(a), ab) / Math.max(ab.lengthSquared(), 1e-9);
  return Math.min(1, Math.max(0, t));
}
