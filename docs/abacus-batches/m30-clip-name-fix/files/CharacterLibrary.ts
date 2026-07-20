// CharacterLibrary v3 — supersedes M29 hotfix version.
// FIX (live-verified): instantiateModelsToScene's rename suffixed AnimationGroup
// names (guard → guard_c58), breaking every alias lookup in every mode. Node
// renames stay (collision safety); animation groups get their ORIGINAL names
// restored — each spawn owns its group objects, so this cannot cross-target.

import '@babylonjs/loaders/glTF';
import {
  Color3, PBRMaterial, SceneLoader, StandardMaterial, Vector3,
} from '@babylonjs/core';
import type {
  AbstractMesh, AssetContainer, Scene, Skeleton, TransformNode,
} from '@babylonjs/core';
import { CharacterAnimator } from '../anim/CharacterAnimator';
import { registerAuthoredClips } from '../anim/authored';

export interface SpawnedCharacter {
  id: string;
  root: TransformNode;
  meshes: AbstractMesh[];
  skeleton: Skeleton;
  animator: CharacterAnimator;
  dispose(): void;
}
export interface SpawnOpts {
  position?: Vector3; yawRad?: number; tint?: string; scale?: number; startClip?: string;
}

const SUFFIX = /_c\d+$/;
const containers = new Map<string, Promise<AssetContainer>>();
let spawnCounter = 0;

function splitUrl(url: string): { rootUrl: string; filename: string } {
  const i = url.lastIndexOf('/');
  if (i < 0) return { rootUrl: './', filename: url };
  return { rootUrl: url.slice(0, i + 1), filename: url.slice(i + 1) };
}

async function loadContainer(scene: Scene, url: string): Promise<AssetContainer> {
  let p = containers.get(url);
  if (!p) {
    const { rootUrl, filename } = splitUrl(url);
    p = SceneLoader.LoadAssetContainerAsync(rootUrl, filename, scene)
      .catch((e) => {
        containers.delete(url);
        throw new Error(`[FEL-CHAR] failed to load "${url}": ${e?.message ?? e}`);
      });
    containers.set(url, p);
  }
  return p;
}

export const CharacterLibrary = {
  async load(scene: Scene, url: string): Promise<void> {
    await loadContainer(scene, url);
  },

  async spawn(scene: Scene, url: string, opts: SpawnOpts = {}): Promise<SpawnedCharacter> {
    const container = await loadContainer(scene, url);
    const inst = container.instantiateModelsToScene(
      (n) => `${n}_c${++spawnCounter}`, false, { doNotInstantiate: true },
    );
    const root = inst.rootNodes[0] as TransformNode;
    const skeleton = inst.skeletons[0];
    if (!skeleton) throw new Error(`[FEL-CHAR] no skeleton in ${url}`);
    const meshes = root.getChildMeshes();

    // ── THE FIX: restore original clip names on this spawn's animation groups.
    // 'guard_c58' → 'guard' so aliases (karate_punch_light→jab, run_forward→run)
    // resolve again. Groups are per-instance objects; renaming is spawn-local.
    for (const g of inst.animationGroups) {
      const original = g.name.replace(SUFFIX, '');
      if (original !== g.name) g.name = original;
    }

    root.position = opts.position ?? Vector3.Zero();
    root.rotation = new Vector3(0, opts.yawRad ?? 0, 0);
    root.scaling.setAll(opts.scale ?? 1);
    if (opts.tint) applyTint(meshes, opts.tint);

    const animator = new CharacterAnimator(scene, inst.animationGroups);
    registerAuthoredClips(animator, scene, skeleton);
    animator.play(opts.startClip ?? 'idle_stand', { loop: true });

    return {
      id: `char_${spawnCounter}`, root, meshes, skeleton, animator,
      dispose() { animator.dispose(); inst.dispose(); },
    };
  },
};

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
