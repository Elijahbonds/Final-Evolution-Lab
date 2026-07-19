// LightRig (Babylon) — standard lighting per venue mood + black-material rescue.
// Fixes: black skatepark, dark football field, mid-dunk sky collapse.

import {
  Color3, Color4, DefaultRenderingPipeline, DirectionalLight,
  HemisphericLight, ImageProcessingConfiguration, Scene, ShadowGenerator, Vector3,
} from '@babylonjs/core';
import type { AbstractMesh, PBRMaterial, StandardMaterial } from '@babylonjs/core';
import { MOODS, type VenueMood } from './moods';

export interface LightRigHandle {
  hemi: HemisphericLight; sun: DirectionalLight;
  shadows: ShadowGenerator; dispose(): void;
}

export function mountLightRig(scene: Scene, mood: VenueMood): LightRigHandle {
  const M = MOODS[mood];

  scene.clearColor = Color4.FromHexString(M.clearColor + 'ff');
  scene.fogMode = Scene.FOGMODE_NONE;          // fog was blacking out high cameras

  const hemi = new HemisphericLight('fel_hemi', Vector3.Up(), scene);
  hemi.intensity = M.hemiIntensity;
  hemi.diffuse = Color3.FromHexString(M.sky);
  hemi.groundColor = Color3.FromHexString(M.ground);

  const sun = new DirectionalLight('fel_sun', new Vector3(...M.sunDir).normalize(), scene);
  sun.intensity = M.sunIntensity;
  sun.diffuse = Color3.FromHexString(M.sun);
  sun.position = new Vector3(-M.sunDir[0], -M.sunDir[1], -M.sunDir[2]).scale(30);

  const shadows = new ShadowGenerator(1024, sun);
  shadows.usePercentageCloserFiltering = true;
  shadows.filteringQuality = ShadowGenerator.QUALITY_MEDIUM;

  const pipeline = new DefaultRenderingPipeline('fel_pipeline', true, scene, scene.cameras);
  pipeline.imageProcessing.toneMappingEnabled = true;
  pipeline.imageProcessing.toneMappingType = ImageProcessingConfiguration.TONEMAPPING_ACES;
  pipeline.imageProcessing.exposure = M.exposure;

  liftBlackMaterials(scene);

  return {
    hemi, sun, shadows,
    dispose() { hemi.dispose(); sun.dispose(); shadows.dispose(); pipeline.dispose(); },
  };
}

/** Floor materials that would render black. Run once after each model load. */
export function liftBlackMaterials(scene: Scene): number {
  let fixed = 0;
  for (const mesh of scene.meshes as AbstractMesh[]) {
    const m = mesh.material as (PBRMaterial & StandardMaterial) | null;
    if (!m) continue;
    const albedo: Color3 | undefined = (m as PBRMaterial).albedoColor ?? (m as StandardMaterial).diffuseColor;
    const hasTex = !!((m as PBRMaterial).albedoTexture ?? (m as StandardMaterial).diffuseTexture);
    if (albedo && !hasTex && albedo.r < 0.04 && albedo.g < 0.04 && albedo.b < 0.04) {
      albedo.set(0.22, 0.22, 0.25); fixed++;
    }
    const metallic = (m as PBRMaterial).metallic;
    if (typeof metallic === 'number' && metallic > 0.95 && !hasTex && !(m as PBRMaterial).reflectionTexture) {
      (m as PBRMaterial).metallic = 0.25;
      (m as PBRMaterial).roughness = Math.max((m as PBRMaterial).roughness ?? 1, 0.6);
      fixed++;
    }
    // ambient floor: nothing may render below ~6% brightness
    const emissive: Color3 | undefined = (m as PBRMaterial).emissiveColor;
    if (emissive && emissive.r === 0 && emissive.g === 0 && emissive.b === 0 && albedo) {
      emissive.copyFrom(albedo).scaleInPlace(0.06);
    }
  }
  if (fixed) console.warn(`[FEL-LIGHT] liftBlackMaterials fixed ${fixed} materials`);
  return fixed;
}

/** Register a character/venue root's meshes as shadow casters. */
export function addShadowCasters(handle: LightRigHandle, meshes: AbstractMesh[]): void {
  for (const m of meshes) handle.shadows.addShadowCaster(m, true);
}
