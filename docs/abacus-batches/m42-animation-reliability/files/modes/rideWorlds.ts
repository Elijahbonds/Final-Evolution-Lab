// rideWorlds v2 — REPLACES the M39 file. Only the surf builder changes: the
// live audit flagged `[FEL-SPAWN] surf: only 6 visible meshes (< 8)` — the
// world was real but too sparse to read as a place, and the rider's forward
// push (2.8 + carve*2.2 m/s²) let them rocket 50-80m downfield in seconds,
// repeatedly outrunning the camera (two FrameGuard off-screen recoveries in
// one short sweep). This version adds a horizon backdrop + a second distant
// swell line (more meshes, more depth cues) and the mode-side speed/lookAhead
// tuning is in the M42 SurfBreakMode.ts that ships alongside this file.
// Skatepark and slope builders are UNCHANGED from M39 — included here only
// so the batch is drag-and-drop complete without cross-referencing M39.

import { Color3, DynamicTexture, MeshBuilder, StandardMaterial, Vector3 } from '@babylonjs/core';
import type { AbstractMesh, Scene } from '@babylonjs/core';
import type { GrindLine } from '../core/GroundRide';

export interface RideWorld {
  ground: AbstractMesh[];
  grindLines: GrindLine[];
  markers: Vector3[];
  dispose(): void;
}

function mat(scene: Scene, name: string, hex: string): StandardMaterial {
  const m = new StandardMaterial(name, scene);
  m.diffuseColor = Color3.FromHexString(hex);
  m.specularColor = Color3.Black();
  return m;
}

function paintGround(scene: Scene, w: number, h: number, painter: (g: CanvasRenderingContext2D, W: number, H: number) => void): StandardMaterial {
  const tex = new DynamicTexture('groundTex', { width: 1024, height: 1024 }, scene, false);
  const g = tex.getContext() as unknown as CanvasRenderingContext2D;
  painter(g, 1024, 1024);
  tex.update();
  const m = new StandardMaterial('groundMat', scene);
  m.diffuseTexture = tex;
  m.specularColor = Color3.Black();
  return m;
}

// ── SKATEPARK (unchanged from M39) ──────────────────────────────────────────
export function buildSkatepark(scene: Scene): RideWorld {
  const all: AbstractMesh[] = [];
  const ground = MeshBuilder.CreateGround('park_floor', { width: 46, height: 46 }, scene);
  ground.checkCollisions = true;
  ground.isPickable = true;
  ground.material = paintGround(scene, 46, 46, (g, W, H) => {
    g.fillStyle = '#8d8496'; g.fillRect(0, 0, W, H);
    g.strokeStyle = 'rgba(255,255,255,0.08)'; g.lineWidth = 3;
    for (let i = 0; i < 10; i++) { g.beginPath(); g.moveTo((i / 10) * W, 0); g.lineTo((i / 10) * W, H); g.stroke(); }
    g.fillStyle = 'rgba(34,211,238,0.5)'; g.font = 'bold 90px sans-serif';
    g.fillText('FEL', W * 0.42, H * 0.52);
  });
  all.push(ground);

  for (const [x, z, ry] of [[-14, -18, 0], [14, -18, 0], [0, 18, Math.PI]] as const) {
    const ramp = MeshBuilder.CreateBox('ramp', { width: 10, height: 0.6, depth: 6 }, scene);
    ramp.position.set(x, 1.15, z);
    ramp.rotation.set(-0.42, ry, 0);
    ramp.material = mat(scene, 'rampM', '#6f6680');
    ramp.checkCollisions = true;
    all.push(ramp);
  }
  const box = MeshBuilder.CreateBox('funbox', { width: 6, height: 1.1, depth: 4 }, scene);
  box.position.set(0, 0.55, -2);
  box.material = mat(scene, 'funM', '#5a5266');
  all.push(box);

  const grindLines: GrindLine[] = [];
  for (const [x1, z1, x2, z2] of [[-6, 4, -6, 12], [6, -4, 6, -12]] as const) {
    const a = new Vector3(x1, 0.8, z1), b = new Vector3(x2, 0.8, z2);
    const rail = MeshBuilder.CreateCylinder('rail', { diameter: 0.09, height: Vector3.Distance(a, b) }, scene);
    rail.position = Vector3.Center(a, b);
    rail.rotation.x = Math.PI / 2;
    rail.rotation.y = Math.atan2(b.x - a.x, b.z - a.z);
    rail.material = mat(scene, 'railM', '#d8dce2');
    all.push(rail);
    grindLines.push({ a, b, bonus: 180 });
  }
  // ground is the only mesh Rider's raycast needs; keep it first in the array
  return { ground: [ground], grindLines, markers: [], dispose: () => all.forEach((m) => m.dispose()) };
}

// ── SLOPE (unchanged from M39) ──────────────────────────────────────────────
export function buildSlopeRun(scene: Scene): RideWorld {
  const all: AbstractMesh[] = [];
  const PITCH = 0.22;
  const piste = MeshBuilder.CreateGround('piste', { width: 34, height: 220 }, scene);
  piste.rotation.x = PITCH;
  piste.position.set(0, 0, 0);
  piste.checkCollisions = true;
  piste.isPickable = true;
  piste.material = paintGround(scene, 34, 220, (g, W, H) => {
    g.fillStyle = '#eef3f7'; g.fillRect(0, 0, W, H);
    g.strokeStyle = 'rgba(120,150,175,0.25)'; g.lineWidth = 5;
    for (let i = 0; i < 14; i++) { g.beginPath(); g.moveTo((i / 14) * W, 0); g.lineTo((i / 14) * W + 30, H); g.stroke(); }
  });
  all.push(piste);

  const onPiste = (x: number, dist: number): Vector3 =>
    new Vector3(x, -Math.sin(PITCH) * dist, Math.cos(PITCH) * dist);

  const markers: Vector3[] = [];
  const gateMatL = mat(scene, 'gateL', '#e23c50'), gateMatR = mat(scene, 'gateR', '#2c6fe2');
  for (let i = 0; i < 12; i++) {
    const dist = 18 + i * 15;
    const cx = Math.sin(i * 1.7) * 9;
    markers.push(onPiste(cx, dist));
    for (const side of [-1, 1]) {
      const pole = MeshBuilder.CreateCylinder('gate', { diameter: 0.12, height: 1.6 }, scene);
      pole.position = onPiste(cx + side * 1.7, dist).add(new Vector3(0, 0.8, 0));
      pole.material = side < 0 ? gateMatL : gateMatR;
      all.push(pole);
    }
  }
  const trunkM = mat(scene, 'trunk', '#5a3d26'), leafM = mat(scene, 'leaf', '#1d4d2b');
  for (let i = 0; i < 22; i++) {
    const dist = 10 + i * 9.5;
    const x = (i % 2 ? 1 : -1) * (15 + (i * 7) % 4);
    const p = onPiste(x, dist);
    const trunk = MeshBuilder.CreateCylinder('trunk', { diameter: 0.3, height: 1.4 }, scene);
    trunk.position = p.add(new Vector3(0, 0.7, 0)); trunk.material = trunkM;
    const leaf = MeshBuilder.CreateCylinder('leaf', { diameterTop: 0, diameterBottom: 1.9, height: 3.2 }, scene);
    leaf.position = p.add(new Vector3(0, 3, 0)); leaf.material = leafM;
    all.push(trunk, leaf);
  }
  return { ground: [piste], grindLines: [], markers, dispose: () => all.forEach((m) => m.dispose()) };
}

// ── SURF BREAK v2 — richer, more legible world ──────────────────────────────
export function buildSurfBreak(scene: Scene): { world: RideWorld; waveLipAt(tSec: number): Vector3 } {
  const all: AbstractMesh[] = [];
  const water = MeshBuilder.CreateGround('water', { width: 90, height: 220 }, scene);
  water.checkCollisions = true;
  water.isPickable = true;
  water.material = paintGround(scene, 90, 220, (g, W, H) => {
    const grad = g.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, '#1a7fae'); grad.addColorStop(1, '#0c4a72');
    g.fillStyle = grad; g.fillRect(0, 0, W, H);
    g.strokeStyle = 'rgba(255,255,255,0.14)'; g.lineWidth = 3;
    for (let i = 0; i < 34; i++) {
      g.beginPath(); g.moveTo(Math.random() * W, Math.random() * H);
      g.bezierCurveTo(Math.random() * W, Math.random() * H, Math.random() * W, Math.random() * H, Math.random() * W, Math.random() * H);
      g.stroke();
    }
  });
  all.push(water);

  // horizon backdrop — a tall distant plane so surf never reads as a void
  const sky = MeshBuilder.CreatePlane('surfSky', { width: 200, height: 60 }, scene);
  sky.position.set(0, 28, -95);
  const skyMat = mat(scene, 'surfSkyM', '#2a6f92');
  skyMat.backFaceCulling = false;
  sky.material = skyMat;
  all.push(sky);

  // primary wave the mode rides
  const lip = MeshBuilder.CreateCylinder('waveLip', { diameter: 3.4, height: 70, tessellation: 12 }, scene);
  lip.rotation.z = Math.PI / 2;
  lip.position.set(0, 0.9, -30);
  const lipM = mat(scene, 'lipM', '#37b6d9'); lipM.alpha = 0.85;
  lip.material = lipM;
  all.push(lip);

  // a second, distant swell line purely for depth/scale cues
  const farSwell = MeshBuilder.CreateCylinder('farSwell', { diameter: 1.6, height: 70, tessellation: 8 }, scene);
  farSwell.rotation.z = Math.PI / 2;
  farSwell.position.set(0, 0.5, -70);
  const farM = mat(scene, 'farSwellM', '#1e5c82'); farM.alpha = 0.6;
  farSwell.material = farM;
  all.push(farSwell);

  const shore = MeshBuilder.CreateGround('shore', { width: 90, height: 18 }, scene);
  shore.position.set(0, 0.02, 96);
  shore.material = mat(scene, 'sand', '#d9c28f');
  all.push(shore);

  const world: RideWorld = {
    ground: [water], grindLines: [], markers: [],
    dispose: () => all.forEach((m) => m.dispose()),
  };
  const waveLipAt = (tSec: number): Vector3 => {
    const z = -50 + ((tSec * 4.5) % 140);
    lip.position.z = z;
    lip.position.y = 0.9 + Math.sin(tSec * 2.2) * 0.15;
    return lip.position;
  };
  return { world, waveLipAt };
}
