// LightRig — the fix for the flattest thing about every live screenshot:
// characters and props read as flat cutouts pasted onto the court, not as
// objects standing IN a lit 3D space. There is no directional light, no
// shadow, no falloff — everything is uniformly bright regardless of angle.
// One light rig per scene, mood-matched to VenueKit's existing mood presets
// (goldenHour / dojoWarm / alpineNoon / stadiumNight), with a real shadow-
// casting key light. Auto-classifies casters/receivers by name so this ships
// without touching any mode file — see the heuristic + escape hatch below.

import {
  Color3, DirectionalLight, HemisphericLight, ShadowGenerator, Vector3,
} from '@babylonjs/core';
import type { AbstractMesh, Scene } from '@babylonjs/core';

export interface MoodLight {
  keyDir: Vector3;          // direction the key light travels (normalized)
  keyColor: Color3;
  keyIntensity: number;
  fillColor: Color3;        // hemispheric ambient
  fillIntensity: number;
  groundColor: Color3;      // hemispheric "bounce" tint from below
}

export const MOOD_LIGHT: Record<string, MoodLight> = {
  goldenHour: {
    keyDir: new Vector3(-0.55, -0.65, 0.35), keyColor: new Color3(1, 0.78, 0.55), keyIntensity: 1.15,
    fillColor: new Color3(0.55, 0.62, 0.75), fillIntensity: 0.45, groundColor: new Color3(0.25, 0.2, 0.22),
  },
  dojoWarm: {
    keyDir: new Vector3(-0.3, -0.8, -0.2), keyColor: new Color3(1, 0.85, 0.62), keyIntensity: 0.95,
    fillColor: new Color3(0.5, 0.4, 0.32), fillIntensity: 0.55, groundColor: new Color3(0.2, 0.14, 0.08),
  },
  alpineNoon: {
    keyDir: new Vector3(-0.4, -0.9, 0.2), keyColor: new Color3(1, 1, 0.98), keyIntensity: 1.3,
    fillColor: new Color3(0.75, 0.82, 0.95), fillIntensity: 0.65, groundColor: new Color3(0.7, 0.75, 0.8),
  },
  stadiumNight: {
    keyDir: new Vector3(-0.35, -0.85, -0.4), keyColor: new Color3(0.85, 0.9, 1), keyIntensity: 1.4,
    fillColor: new Color3(0.25, 0.28, 0.4), fillIntensity: 0.35, groundColor: new Color3(0.08, 0.09, 0.12),
  },
  default: {
    keyDir: new Vector3(-0.4, -0.8, 0.3), keyColor: new Color3(1, 1, 1), keyIntensity: 1.1,
    fillColor: new Color3(0.55, 0.58, 0.65), fillIntensity: 0.5, groundColor: new Color3(0.2, 0.2, 0.22),
  },
};

/** Names that read as ground/floor — auto-receivers, never auto-casters. */
const RECEIVER_HINTS = /floor|ground|piste|water|court|pitch|green|plate|mound|shore|park_floor/i;

export class LightRig {
  private key: DirectionalLight;
  private fill: HemisphericLight;
  private shadows: ShadowGenerator;
  private autoObserver: ReturnType<Scene['onNewMeshAddedObservable']['add']> | null = null;

  constructor(private scene: Scene, mood: keyof typeof MOOD_LIGHT | string = 'default') {
    const cfg = MOOD_LIGHT[mood] ?? MOOD_LIGHT.default;

    this.fill = new HemisphericLight('fillLight', new Vector3(0, 1, 0), scene);
    this.fill.diffuse = cfg.fillColor;
    this.fill.groundColor = cfg.groundColor;
    this.fill.intensity = cfg.fillIntensity;

    this.key = new DirectionalLight('keyLight', cfg.keyDir, scene);
    this.key.diffuse = cfg.keyColor;
    this.key.intensity = cfg.keyIntensity;
    this.key.position = cfg.keyDir.scale(-40);

    // soft, cheap shadows — 1024 map + blur, good enough at arcade camera
    // distances without the cost of PCSS/cascade shadow maps
    this.shadows = new ShadowGenerator(1024, this.key);
    this.shadows.useBlurExponentialShadowMap = true;
    this.shadows.blurKernel = 24;
    this.shadows.darkness = 0.35;             // shadows read, never go pitch black

    this.classifyExisting();
    this.autoObserver = scene.onNewMeshAddedObservable.add((m) => this.classify(m));
  }

  private classify(mesh: AbstractMesh): void {
    if (!mesh.name || mesh.name.startsWith('__')) return;
    if (RECEIVER_HINTS.test(mesh.name)) {
      mesh.receiveShadows = true;
    } else {
      this.shadows.addShadowCaster(mesh, true);
    }
  }
  private classifyExisting(): void {
    for (const m of this.scene.meshes) this.classify(m);
  }

  /** Escape hatch for a mode that wants precise control instead of the
   *  name-heuristic (e.g. a mesh named oddly, or one that should be both). */
  registerCaster(mesh: AbstractMesh): void { this.shadows.addShadowCaster(mesh, true); }
  registerReceiver(mesh: AbstractMesh): void { mesh.receiveShadows = true; }

  setMood(mood: keyof typeof MOOD_LIGHT | string): void {
    const cfg = MOOD_LIGHT[mood] ?? MOOD_LIGHT.default;
    this.key.direction = cfg.keyDir;
    this.key.diffuse = cfg.keyColor;
    this.key.intensity = cfg.keyIntensity;
    this.key.position = cfg.keyDir.scale(-40);
    this.fill.diffuse = cfg.fillColor;
    this.fill.groundColor = cfg.groundColor;
    this.fill.intensity = cfg.fillIntensity;
  }

  dispose(): void {
    if (this.autoObserver) this.scene.onNewMeshAddedObservable.remove(this.autoObserver);
    this.shadows.dispose();
    this.key.dispose();
    this.fill.dispose();
  }
}

// WIRING (ModeHarness, once per mode load — AFTER the venue is built so the
// name-based classification sees the real ground mesh):
//   const lightRig = new LightRig(scene, modeConfig.mood);   // mood string already exists per mode
//   ... on mode dispose: lightRig.dispose();
// No mode files need to change — casters/receivers are classified by name
// automatically. If a venue mesh is misclassified (rare), call
// lightRig.registerReceiver(mesh) / registerCaster(mesh) once, from that
// mode's load(), right after building the world.
