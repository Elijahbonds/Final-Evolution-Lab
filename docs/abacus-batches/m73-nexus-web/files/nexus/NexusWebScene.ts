// NexusWebScene — Nexus, rebuilt for the web. Babylon, 3D, zero external assets.
//
// WHY THIS REPLACES THE SWIFT SCENE FORMAT
// The Swift descriptors (M72) describe a 2-D SwiftUI Canvas: positions are
// normalised {x, y} in 0–1 with no depth, and "sprite" means an SF Symbol.
// That format is correct for what it was built for and actively wrong for a
// 3-D Babylon game — force-fitting it would mean inventing a Z for every
// entity and pretending SF Symbols exist in a browser. So this is a
// web-native format that keeps what carried over (the 20-mode taxonomy, the
// venue/actor/prop split, per-mode palettes) and drops what did not.
//
// THE SCHEMA-DRIFT LESSON, APPLIED
// M72's descriptors shipped broken for months because hand-written JSON
// disagreed with what Swift's Codable actually decodes, and nothing checked.
// The fix there was to GENERATE the JSON from the types. On the web there is
// a better answer available: make the spec a TYPESCRIPT VALUE. There is no
// serialisation boundary to drift across — `tsc` is the validator, a typo is
// a compile error, and a renamed field breaks the build instead of a scene.
//
// ART DIRECTION
// Everything is procedural: MeshBuilder primitives, DynamicTexture-painted
// court lines, and a colour grade per venue. This is the same constraint the
// rest of FEL runs under — no downloads, no CDN, nothing to 404 — and it is
// what lets 20 venues cost a few kilobytes instead of a few hundred megabytes.

import {
  ArcRotateCamera, Color3, Color4, DirectionalLight, DynamicTexture, Engine,
  HemisphericLight, Mesh, MeshBuilder, PBRMaterial, Scene, ShadowGenerator,
  StandardMaterial, Texture, TransformNode, Vector3,
} from '@babylonjs/core';

// ── spec ──────────────────────────────────────────────────────────────────

export type GroundKind =
  | 'court' | 'pitch' | 'clay' | 'hardcourt' | 'sand' | 'mat'
  | 'water' | 'snow' | 'street' | 'stage' | 'diamond' | 'green';

export type PropKind =
  | 'hoop' | 'backboardPole' | 'goal' | 'net' | 'wall' | 'crowdTier'
  | 'palm' | 'lamp' | 'banner' | 'ramp' | 'beam' | 'podium' | 'tee' | 'flag';

export interface Grade {
  /** Camera exposure. >1 lifts the whole image; the anime grade sits ~1.15. */
  exposure: number;
  contrast: number;
  /** 0–1. Colour lift toward the accent, which is what reads as "stylised". */
  vignette: number;
}

export interface Environment {
  skyTop: string;
  skyBottom: string;
  fogColor: string;
  fogDensity: number;
  /** 0–1 ambient fill. Low values need a stronger key or the scene goes muddy. */
  ambient: number;
  sunDirection: [number, number, number];
  sunColor: string;
  grade: Grade;
}

export interface GroundSpec {
  kind: GroundKind;
  size: [number, number];
  color: string;
  lineColor?: string;
  /** Painted into a DynamicTexture — no image files. */
  markings?: 'basketball' | 'halfcourt' | 'tennis' | 'soccer' | 'volleyball' | 'none';
}

export interface PropSpec {
  kind: PropKind;
  position: [number, number, number];
  rotationY?: number;
  scale?: number;
  color?: string;
}

export interface ActorSpec {
  id: string;
  role: 'player' | 'ally' | 'foe' | 'crowd';
  position: [number, number, number];
  facing?: number;
  color?: string;
}

export interface CameraSpec {
  /** Radians. alpha = orbit, beta = pitch from +Y. */
  alpha: number;
  beta: number;
  radius: number;
  target: [number, number, number];
  fov?: number;
}

export interface NexusWebSpec {
  modeId: string;
  name: string;
  venue: string;
  environment: Environment;
  ground: GroundSpec;
  props: PropSpec[];
  actors: ActorSpec[];
  camera: CameraSpec;
}

// ── helpers ───────────────────────────────────────────────────────────────

const c3 = (hex: string): Color3 => Color3.FromHexString(hex);
const v3 = (t: [number, number, number]): Vector3 => new Vector3(t[0], t[1], t[2]);

/** PBR with sane defaults. Metallic 0 / rough 0.7 is the "painted surface"
 *  look this art direction wants; specular highlights on everything read as
 *  plastic and fight the flat anime grade. */
function surface(scene: Scene, name: string, hex: string, rough = 0.7, metal = 0): PBRMaterial {
  const m = new PBRMaterial(name, scene);
  m.albedoColor = c3(hex);
  m.roughness = rough;
  m.metallic = metal;
  m.environmentIntensity = 0.35;
  return m;
}

function emissive(scene: Scene, name: string, hex: string, strength = 0.6): PBRMaterial {
  const m = surface(scene, name, hex, 0.5);
  m.emissiveColor = c3(hex).scale(strength);
  return m;
}

// ── ground ────────────────────────────────────────────────────────────────

/** Paint court markings into a texture instead of shipping one. 1024² is the
 *  sweet spot: lines stay crisp at grazing angles without a 4 MB upload. */
function paintMarkings(
  scene: Scene, kind: NonNullable<GroundSpec['markings']>, base: string, line: string,
): DynamicTexture {
  const S = 1024;
  const tex = new DynamicTexture('groundTex', { width: S, height: S }, scene, false);
  const ctx = tex.getContext() as unknown as CanvasRenderingContext2D;
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, S, S);
  ctx.strokeStyle = line;
  ctx.lineWidth = 6;
  ctx.lineCap = 'round';

  const box = (x: number, y: number, w: number, h: number) => ctx.strokeRect(x, y, w, h);
  const arc = (x: number, y: number, r: number, a0 = 0, a1 = Math.PI * 2) => {
    ctx.beginPath(); ctx.arc(x, y, r, a0, a1); ctx.stroke();
  };
  const line2 = (x0: number, y0: number, x1: number, y1: number) => {
    ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.stroke();
  };

  switch (kind) {
    case 'basketball':
      box(40, 40, S - 80, S - 80);
      line2(S / 2, 40, S / 2, S - 40);
      arc(S / 2, S / 2, 110);
      box(40, S / 2 - 150, 190, 300);
      box(S - 230, S / 2 - 150, 190, 300);
      arc(230, S / 2, 150, -Math.PI / 2, Math.PI / 2);
      arc(S - 230, S / 2, 150, Math.PI / 2, (3 * Math.PI) / 2);
      break;
    case 'halfcourt':
      box(40, 40, S - 80, S - 80);
      box(S / 2 - 150, 40, 300, 190);
      arc(S / 2, 230, 150, 0, Math.PI);
      arc(S / 2, 40, 380, 0.35, Math.PI - 0.35);
      break;
    case 'tennis':
      box(60, 40, S - 120, S - 80);
      line2(60, S / 2, S - 60, S / 2);
      box(150, 250, S - 300, S - 500);
      line2(S / 2, 250, S / 2, S - 250);
      break;
    case 'soccer':
      box(40, 40, S - 80, S - 80);
      line2(40, S / 2, S - 40, S / 2);
      arc(S / 2, S / 2, 120);
      box(S / 2 - 200, 40, 400, 130);
      box(S / 2 - 200, S - 170, 400, 130);
      break;
    case 'volleyball':
      box(60, 60, S - 120, S - 120);
      line2(60, S / 2, S - 60, S / 2);
      line2(60, S / 2 - 160, S - 60, S / 2 - 160);
      line2(60, S / 2 + 160, S - 60, S / 2 + 160);
      break;
    default:
      break;
  }
  tex.update(false);
  return tex;
}

/** Water/snow get a painted swell pattern so a flat plane still reads as a
 *  surface with depth — the M64 ocean court, generalised. */
function paintOrganic(scene: Scene, kind: 'water' | 'snow' | 'sand', base: string): DynamicTexture {
  const S = 1024;
  const tex = new DynamicTexture('organicTex', { width: S, height: S }, scene, false);
  const ctx = tex.getContext() as unknown as CanvasRenderingContext2D;
  ctx.fillStyle = base;
  ctx.fillRect(0, 0, S, S);
  const light = kind === 'water' ? 'rgba(255,255,255,0.16)'
    : kind === 'snow' ? 'rgba(255,255,255,0.55)' : 'rgba(255,255,255,0.10)';
  ctx.strokeStyle = light;
  ctx.lineWidth = kind === 'water' ? 5 : 3;
  for (let i = 0; i < 46; i++) {
    const y = (i / 46) * S;
    ctx.beginPath();
    ctx.moveTo(0, y);
    for (let x = 0; x <= S; x += 32) {
      ctx.lineTo(x, y + Math.sin((x / S) * Math.PI * 4 + i * 0.7) * (kind === 'water' ? 14 : 6));
    }
    ctx.stroke();
  }
  tex.update(false);
  return tex;
}

function buildGround(scene: Scene, g: GroundSpec, root: TransformNode): Mesh {
  // NAME MATTERS. M64's CameraDirector occlusion probe recognises venue shell
  // by name — /^(venue_ground|venue_box|wall_|...)/ — because VenueKit builds
  // these without collision flags. A ground called 'nexus_ground' would be
  // invisible to that probe, and the camera would sink through the floor
  // exactly as it did in E26. Keep the prefix.
  const mesh = MeshBuilder.CreateGround(
    'venue_ground', { width: g.size[0], height: g.size[1], subdivisions: 2 }, scene);
  mesh.parent = root;
  mesh.receiveShadows = true;
  // Named so the M64 CameraDirector occlusion probe recognises it as venue
  // shell even though it carries no collision flag.
  mesh.isPickable = true;

  const mat = surface(scene, 'nexus_groundMat', g.color, g.kind === 'water' ? 0.25 : 0.85);
  if (g.markings && g.markings !== 'none') {
    mat.albedoTexture = paintMarkings(scene, g.markings, g.color, g.lineColor ?? '#FFFFFF');
  } else if (g.kind === 'water' || g.kind === 'snow' || g.kind === 'sand') {
    mat.albedoTexture = paintOrganic(scene, g.kind, g.color);
  }
  if (mat.albedoTexture) {
    (mat.albedoTexture as Texture).wrapU = Texture.CLAMP_ADDRESSMODE;
    (mat.albedoTexture as Texture).wrapV = Texture.CLAMP_ADDRESSMODE;
  }
  if (g.kind === 'water') { mat.metallic = 0.15; mat.roughness = 0.2; }
  mesh.material = mat;
  return mesh;
}

// ── props ─────────────────────────────────────────────────────────────────

function buildProp(scene: Scene, p: PropSpec, root: TransformNode, shadows: ShadowGenerator): void {
  const s = p.scale ?? 1;
  const at = v3(p.position);
  const node = new TransformNode(`prop_${p.kind}_${at.x}_${at.z}`, scene);
  node.parent = root;
  node.position = at;
  node.rotation.y = p.rotationY ?? 0;

  const add = (m: Mesh, castShadow = true) => {
    m.parent = node;
    if (castShadow) shadows.addShadowCaster(m);
    return m;
  };

  switch (p.kind) {
    case 'hoop': {
      const pole = MeshBuilder.CreateCylinder('pole', { height: 3.05 * s, diameter: 0.16 * s }, scene);
      pole.position.y = (3.05 * s) / 2;
      pole.material = surface(scene, 'poleMat', '#2A2E37', 0.5, 0.4);
      add(pole);
      const board = MeshBuilder.CreateBox('board', { width: 1.8 * s, height: 1.05 * s, depth: 0.06 * s }, scene);
      board.position.set(0, 3.0 * s, 0.3 * s);
      board.material = surface(scene, 'boardMat', '#F4F1E8', 0.4);
      add(board);
      const rim = MeshBuilder.CreateTorus('rim', { diameter: 0.90 * s, thickness: 0.055 * s, tessellation: 24 }, scene);
      rim.position.set(0, 2.70 * s, 0.72 * s);
      rim.material = emissive(scene, 'rimMat', p.color ?? '#FF6B00', 0.5);
      add(rim);
      break;
    }
    case 'backboardPole': {
      const m = MeshBuilder.CreateCylinder('p', { height: 3.2 * s, diameter: 0.14 * s }, scene);
      m.position.y = 1.6 * s;
      m.material = surface(scene, 'bpMat', p.color ?? '#2A2E37', 0.5, 0.3);
      add(m);
      break;
    }
    case 'goal': {
      const w = 3.6 * s, h = 2.0 * s;
      for (const [x, y, hh, dd] of [[-w / 2, h / 2, h, 0.12], [w / 2, h / 2, h, 0.12]] as const) {
        const post = MeshBuilder.CreateCylinder('post', { height: hh, diameter: dd * s }, scene);
        post.position.set(x, y, 0);
        post.material = surface(scene, 'goalMat', '#FFFFFF', 0.5);
        add(post);
      }
      const bar = MeshBuilder.CreateCylinder('bar', { height: w, diameter: 0.12 * s }, scene);
      bar.rotation.z = Math.PI / 2; bar.position.y = h;
      bar.material = surface(scene, 'goalMat2', '#FFFFFF', 0.5);
      add(bar);
      break;
    }
    case 'net': {
      const m = MeshBuilder.CreateBox('net', { width: 9 * s, height: 1.0 * s, depth: 0.05 }, scene);
      m.position.y = 0.9 * s;
      const mat = surface(scene, 'netMat', p.color ?? '#FFFFFF', 0.9);
      mat.alpha = 0.35;
      m.material = mat;
      add(m, false);
      break;
    }
    case 'wall': {
      // 'wall_' prefix so the CameraDirector occlusion probe sees it (see the
      // note on the ground mesh above).
      const m = MeshBuilder.CreateBox('wall_nexus', { width: 24 * s, height: 6 * s, depth: 0.4 }, scene);
      m.position.y = 3 * s;
      m.material = surface(scene, 'wallMat', p.color ?? '#12151F', 0.9);
      add(m, false);
      break;
    }
    case 'crowdTier': {
      // Three stepped rows of blocks. Cheap, and at distance it reads as a
      // stand full of people far better than a flat painted plane does.
      for (let r = 0; r < 3; r++) {
        const row = MeshBuilder.CreateBox('tier', { width: 22 * s, height: 0.9 * s, depth: 1.6 * s }, scene);
        row.position.set(0, 0.45 * s + r * 0.85 * s, r * 1.5 * s);
        row.material = surface(scene, `tierMat${r}`, r % 2 ? '#1B2030' : '#232A3D', 0.95);
        add(row, false);
      }
      break;
    }
    case 'palm': {
      const trunk = MeshBuilder.CreateCylinder('trunk', { height: 4.2 * s, diameterTop: 0.16 * s, diameterBottom: 0.26 * s }, scene);
      trunk.position.y = 2.1 * s;
      trunk.material = surface(scene, 'trunkMat', '#6B4A2F', 0.9);
      add(trunk);
      const crown = MeshBuilder.CreateCylinder('crown', { height: 1.1 * s, diameterTop: 0, diameterBottom: 2.6 * s, tessellation: 6 }, scene);
      crown.position.y = 4.6 * s;
      crown.material = surface(scene, 'crownMat', '#2FBF5B', 0.85);
      add(crown);
      break;
    }
    case 'lamp': {
      const post = MeshBuilder.CreateCylinder('lpost', { height: 5 * s, diameter: 0.12 * s }, scene);
      post.position.y = 2.5 * s;
      post.material = surface(scene, 'lampPost', '#2A2E37', 0.6, 0.3);
      add(post);
      const head = MeshBuilder.CreateSphere('lhead', { diameter: 0.5 * s }, scene);
      head.position.y = 5.1 * s;
      head.material = emissive(scene, 'lampHead', p.color ?? '#FFE9A8', 1.4);
      add(head, false);
      break;
    }
    case 'banner': {
      const m = MeshBuilder.CreateBox('banner', { width: 6 * s, height: 1.4 * s, depth: 0.08 }, scene);
      m.position.y = 4 * s;
      m.material = emissive(scene, 'bannerMat', p.color ?? '#FF2D55', 0.35);
      add(m, false);
      break;
    }
    case 'ramp': {
      const m = MeshBuilder.CreateBox('ramp', { width: 6 * s, height: 0.3, depth: 4 * s }, scene);
      m.rotation.x = -0.42; m.position.y = 0.9 * s;
      m.material = surface(scene, 'rampMat', p.color ?? '#4A4F5C', 0.8);
      add(m);
      break;
    }
    case 'beam': {
      const m = MeshBuilder.CreateBox('beam', { width: 5 * s, height: 0.16 * s, depth: 0.5 * s }, scene);
      m.position.y = 1.25 * s;
      m.material = surface(scene, 'beamMat', p.color ?? '#C8A15A', 0.6);
      add(m);
      break;
    }
    case 'podium': {
      const m = MeshBuilder.CreateCylinder('podium', { height: 0.5 * s, diameter: 3 * s, tessellation: 24 }, scene);
      m.position.y = 0.25 * s;
      m.material = emissive(scene, 'podiumMat', p.color ?? '#5E5CE6', 0.25);
      add(m);
      break;
    }
    case 'tee': {
      const m = MeshBuilder.CreateCylinder('tee', { height: 0.12, diameter: 2.2 * s, tessellation: 20 }, scene);
      m.position.y = 0.06;
      m.material = surface(scene, 'teeMat', p.color ?? '#3FA45B', 0.9);
      add(m, false);
      break;
    }
    case 'flag': {
      const pole = MeshBuilder.CreateCylinder('fpole', { height: 2.2 * s, diameter: 0.05 }, scene);
      pole.position.y = 1.1 * s;
      pole.material = surface(scene, 'fpoleMat', '#EEEEEE', 0.5);
      add(pole);
      const cloth = MeshBuilder.CreateBox('flag', { width: 0.7 * s, height: 0.45 * s, depth: 0.02 }, scene);
      cloth.position.set(0.35 * s, 1.9 * s, 0);
      cloth.material = emissive(scene, 'flagMat', p.color ?? '#FF3B30', 0.4);
      add(cloth);
      break;
    }
  }
}

// ── actors ────────────────────────────────────────────────────────────────

/** A stylised stand-in body. Deliberately NOT a character rig: real avatars
 *  come from CharacterLibrary. This exists so a venue can be composed,
 *  framed and reviewed before any rig is loaded — and so a mode that fails to
 *  spawn characters still shows a readable scene instead of an empty court. */
function buildActor(scene: Scene, a: ActorSpec, root: TransformNode, shadows: ShadowGenerator): TransformNode {
  const node = new TransformNode(`actor_${a.id}`, scene);
  node.parent = root;
  node.position = v3(a.position);
  node.rotation.y = a.facing ?? 0;

  const tint = a.color ?? (a.role === 'player' ? '#FF6B00' : a.role === 'ally' ? '#4FC3F7' : '#E5484D');
  const mat = surface(scene, `actorMat_${a.id}`, tint, 0.65);

  const torso = MeshBuilder.CreateCapsule('torso', { height: 0.95, radius: 0.22 }, scene);
  torso.position.y = 1.12; torso.parent = node; torso.material = mat;
  shadows.addShadowCaster(torso);

  const head = MeshBuilder.CreateSphere('head', { diameter: 0.34 }, scene);
  head.position.y = 1.78; head.parent = node;
  head.material = surface(scene, `headMat_${a.id}`, '#F0C9A0', 0.75);
  shadows.addShadowCaster(head);

  for (const side of [-1, 1]) {
    const leg = MeshBuilder.CreateCapsule('leg', { height: 0.78, radius: 0.11 }, scene);
    leg.position.set(side * 0.13, 0.42, 0); leg.parent = node;
    leg.material = surface(scene, `legMat_${a.id}`, '#23262F', 0.8);
    shadows.addShadowCaster(leg);

    const arm = MeshBuilder.CreateCapsule('arm', { height: 0.7, radius: 0.085 }, scene);
    // Arms DOWN at the sides — the E25 lesson: a default pose that looks like
    // a T-pose is read as a broken rig, even on a placeholder.
    arm.position.set(side * 0.33, 1.15, 0); arm.parent = node;
    arm.material = mat;
    shadows.addShadowCaster(arm);
  }
  return node;
}

// ── build ─────────────────────────────────────────────────────────────────

export interface BuiltScene {
  root: TransformNode;
  camera: ArcRotateCamera;
  ground: Mesh;
  actors: TransformNode[];
  shadows: ShadowGenerator;
  dispose(): void;
}

/**
 * Build a complete venue from a spec. Idempotent and self-contained: every
 * mesh is parented to one root, so `dispose()` removes the whole venue
 * without touching anything else in the scene.
 */
export function buildNexusScene(scene: Scene, spec: NexusWebSpec, canvas?: HTMLCanvasElement): BuiltScene {
  const env = spec.environment;
  const root = new TransformNode(`nexus_${spec.modeId}`, scene);

  // sky + fog
  scene.clearColor = Color4.FromColor3(c3(env.skyBottom), 1);
  scene.fogMode = Scene.FOGMODE_EXP2;
  scene.fogColor = c3(env.fogColor);
  scene.fogDensity = env.fogDensity;

  // A gradient dome rather than a flat clear colour. It is one extra mesh and
  // it is most of why a scene reads as a place instead of a background.
  const sky = MeshBuilder.CreateSphere('nexus_sky', { diameter: 400, segments: 16, sideOrientation: Mesh.BACKSIDE }, scene);
  sky.parent = root;
  sky.isPickable = false;
  sky.applyFog = false;
  {
    const S = 256;
    const tex = new DynamicTexture('skyTex', { width: 4, height: S }, scene, false);
    const ctx = tex.getContext() as unknown as CanvasRenderingContext2D;
    const grad = ctx.createLinearGradient(0, 0, 0, S);
    grad.addColorStop(0, env.skyTop);
    grad.addColorStop(1, env.skyBottom);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 4, S);
    tex.update(false);
    const m = new StandardMaterial('skyMat', scene);
    m.emissiveTexture = tex;
    m.disableLighting = true;
    m.backFaceCulling = false;
    sky.material = m;
  }

  // lighting: hemispheric fill + directional key with shadows
  const fill = new HemisphericLight('nexus_fill', new Vector3(0, 1, 0), scene);
  fill.intensity = env.ambient;
  fill.diffuse = c3(env.skyTop);
  fill.groundColor = c3(env.fogColor).scale(0.6);

  const sun = new DirectionalLight('nexus_sun', v3(env.sunDirection).normalize(), scene);
  sun.position = v3(env.sunDirection).normalize().scale(-40);
  sun.intensity = 1.5 - env.ambient * 0.4;
  sun.diffuse = c3(env.sunColor);

  const shadows = new ShadowGenerator(1024, sun);
  shadows.useExponentialShadowMap = true;
  shadows.darkness = 0.45;

  const ground = buildGround(scene, spec.ground, root);
  for (const p of spec.props) buildProp(scene, p, root, shadows);
  const actors = spec.actors.map((a) => buildActor(scene, a, root, shadows));

  // camera
  const cam = new ArcRotateCamera(
    `nexus_cam_${spec.modeId}`, spec.camera.alpha, spec.camera.beta, spec.camera.radius,
    v3(spec.camera.target), scene);
  cam.fov = spec.camera.fov ?? 0.9;
  cam.minZ = 0.1;
  cam.maxZ = 500;
  cam.lowerBetaLimit = 0.15;
  cam.upperBetaLimit = Math.PI / 2 - 0.05;   // never dip under the floor (E26)
  cam.lowerRadiusLimit = 3;
  cam.upperRadiusLimit = spec.camera.radius * 2.2;
  if (canvas) cam.attachControl(canvas, true);
  scene.activeCamera = cam;

  // FRAMING GUARD — is the camera behind its own scenery?
  //
  // This is E26, the bug that cost three cycles on the live FEL build: the
  // camera resolved to a position on the far side of a venue wall and filled
  // the frame with flat paint. It reproduced immediately here (karate_h2h
  // rendered as a solid maroon rectangle), which is the whole argument for a
  // renderer you can actually run in CI.
  //
  // The check is exact rather than heuristic: a wall is a plane, so compare
  // which SIDE of it the camera and the target are on. Different sides means
  // the wall is between them, and nothing else needs to be guessed.
  cam.position;   // force Babylon to compute it from alpha/beta/radius
  for (const p of spec.props) {
    if (p.kind !== 'wall') continue;
    const ry = p.rotationY ?? 0;
    const normal = new Vector3(Math.sin(ry), 0, Math.cos(ry));
    const wallPos = v3(p.position);
    const dCam = Vector3.Dot(cam.position.subtract(wallPos), normal);
    const dTarget = Vector3.Dot(v3(spec.camera.target).subtract(wallPos), normal);
    if (dCam * dTarget < 0 && Math.abs(dCam) > 0.1) {
      console.warn(
        `[NEXUS] framing: camera for "${spec.modeId}" sits behind the wall at `
        + `[${p.position.join(', ')}] — it will fill the frame with flat colour. `
        + `Reduce camera.radius (${spec.camera.radius}), raise camera.beta, or move the wall out.`);
    }
  }

  // grade — the single biggest quality lever, and it is nearly free
  const ip = scene.imageProcessingConfiguration;
  ip.toneMappingEnabled = true;
  ip.exposure = env.grade.exposure;
  ip.contrast = env.grade.contrast;
  ip.vignetteEnabled = env.grade.vignette > 0;
  ip.vignetteWeight = env.grade.vignette * 4;
  ip.vignetteColor = Color4.FromColor3(c3(env.fogColor), 1);

  return {
    root, camera: cam, ground, actors, shadows,
    dispose() {
      shadows.dispose();
      sun.dispose();
      fill.dispose();
      cam.dispose();
      root.getDescendants().forEach((n) => n.dispose());
      root.dispose();
    },
  };
}

/** Convenience for a standalone page or a render harness. */
export function mountNexus(canvas: HTMLCanvasElement, spec: NexusWebSpec): { engine: Engine; scene: Scene; built: BuiltScene } {
  const engine = new Engine(canvas, true, { preserveDrawingBuffer: true, stencil: true });
  const scene = new Scene(engine);
  const built = buildNexusScene(scene, spec, canvas);
  engine.runRenderLoop(() => scene.render());
  window.addEventListener('resize', () => engine.resize());
  return { engine, scene, built };
}
