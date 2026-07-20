// CharacterLibrary — the ONLY way modes create humanoids. Baked-clip GLBs,
// cached containers, per-spawn animator + tint/scale variance (mob variety).

import {
  Color3, PBRMaterial, SceneLoader, StandardMaterial, Vector3,
} from '@babylonjs/core';
import type {
  AbstractMesh, AssetContainer, Scene, Skeleton, TransformNode,
} from '@babylonjs/core';
import { CharacterAnimator } from '../../anim/CharacterAnimator';
import { registerAuthoredClips } from '../../anim/authored';

export interface SpawnedCharacter {
  id: string;
  root: TransformNode;
  meshes: AbstractMesh[];
  skeleton: Skeleton;
  animator: CharacterAnimator;
  dispose(): void;
}

export interface SpawnOpts {
  position?: Vector3;
  yawRad?: number;
  tint?: string;            // hex — mob/team variety
  scale?: number;           // 0.92–1.08 for mob variance
  startClip?: string;       // default 'idle_stand'
}

const containers = new Map<string, Promise<AssetContainer>>();
let spawnCounter = 0;

async function loadContainer(scene: Scene, url: string): Promise<AssetContainer> {
  let p = containers.get(url);
  if (!p) {
    p = SceneLoader.LoadAssetContainerAsync('', url, scene);
    containers.set(url, p);
  }
  return p;
}

export const CharacterLibrary = {
  /** Preload an asset (hero, enemy, defender…) into the cache. */
  async load(scene: Scene, url: string): Promise<void> {
    await loadContainer(scene, url);
  },

  /** Instantiate a character with its own animator + authored clips. */
  async spawn(scene: Scene, url: string, opts: SpawnOpts = {}): Promise<SpawnedCharacter> {
    const container = await loadContainer(scene, url);
    const inst = container.instantiateModelsToScene(
      (n) => `${n}_c${++spawnCounter}`, false, { doNotInstantiate: true },
    );
    const root = inst.rootNodes[0] as TransformNode;
    const skeleton = inst.skeletons[0];
    const meshes = root.getChildMeshes();

    if (!skeleton) throw new Error(`[FEL-CHAR] no skeleton in ${url}`);

    root.position = opts.position ?? Vector3.Zero();
    root.rotation = new Vector3(0, opts.yawRad ?? 0, 0);
    root.scaling.setAll(opts.scale ?? 1);

    if (opts.tint) applyTint(meshes, opts.tint);

    const animator = new CharacterAnimator(scene, inst.animationGroups);
    registerAuthoredClips(animator, scene, skeleton);
    animator.play(opts.startClip ?? 'idle_stand', { loop: true });

    return {
      id: `char_${spawnCounter}`,
      root, meshes, skeleton, animator,
      dispose() {
        animator.dispose();
        inst.dispose();
      },
    };
  },
};

/** Clothing-only tint: skips skin-toned materials so faces stay natural. */
function applyTint(meshes: AbstractMesh[], hex: string): void {
  const tint = Color3.FromHexString(hex);
  for (const mesh of meshes) {
    const m = mesh.material as (PBRMaterial & StandardMaterial) | null;
    if (!m) continue;
    const albedo = (m as PBRMaterial).albedoColor ?? (m as StandardMaterial).diffuseColor;
    if (!albedo) continue;
    const isSkinTone = albedo.r > 0.45 && albedo.g > 0.25 && albedo.b > 0.15
      && albedo.r > albedo.b && albedo.g > albedo.b * 0.9;
    if (isSkinTone) continue;
    const cloned = m.clone(`${m.name}_tint`);
    if ((cloned as PBRMaterial).albedoColor) (cloned as PBRMaterial).albedoColor = tint;
    else (cloned as StandardMaterial).diffuseColor = tint;
    mesh.material = cloned;
  }
}
