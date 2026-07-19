// LightRig — standard scene lighting for every mode + black-material rescue.
// Fixes: pitch-black skatepark, dark football field, mid-dunk sky collapse.
// Mount once inside each mode's <Canvas> scene graph.

import { useEffect } from 'react';
import { useThree } from '@react-three/fiber';
import {
  ACESFilmicToneMapping, Color, DirectionalLight, HemisphereLight,
  Mesh, MeshStandardMaterial, Object3D, SRGBColorSpace,
} from 'three';

export type VenueMood = 'goldenHour' | 'daylight' | 'dojoWarm' | 'nightGame';

const MOODS: Record<VenueMood, {
  sky: string; ground: string; hemi: number; sun: string; sunI: number;
  sunDir: [number, number, number]; exposure: number; background: string;
}> = {
  goldenHour: { sky: '#ffd9a0', ground: '#4a4038', hemi: 0.75, sun: '#ffb36b', sunI: 2.4, sunDir: [-0.6, -1, -0.35], exposure: 1.12, background: '#2a1e33' },
  daylight:   { sky: '#cfe8ff', ground: '#5a5a52', hemi: 0.85, sun: '#ffffff', sunI: 2.6, sunDir: [-0.5, -1, -0.3], exposure: 1.05, background: '#87b7dd' },
  dojoWarm:   { sky: '#ffcf9e', ground: '#3a2a22', hemi: 0.65, sun: '#ff9d5c', sunI: 1.9, sunDir: [-0.3, -1, -0.5], exposure: 1.1,  background: '#1d1210' },
  nightGame:  { sky: '#9fb7ff', ground: '#22262e', hemi: 0.55, sun: '#e8f0ff', sunI: 2.2, sunDir: [-0.35, -1, -0.2], exposure: 1.15, background: '#0b0e16' },
};

/**
 * Rescue pass for materials that render black: unlit-dark PBR params get an
 * ambient floor. Run once after a venue/model loads (and NEVER per-frame).
 */
export function liftBlackMaterials(root: Object3D): number {
  let fixed = 0;
  root.traverse((o) => {
    const mesh = o as Mesh;
    if (!mesh.isMesh) return;
    const mats = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    for (const m of mats as MeshStandardMaterial[]) {
      if (!m || !(m as any).isMeshStandardMaterial) continue;
      const c = m.color;
      const nearBlack = c && c.r < 0.04 && c.g < 0.04 && c.b < 0.04 && !m.map;
      const fullMetalDark = (m.metalness ?? 0) > 0.95 && !m.envMap && !m.map;
      if (nearBlack) { c.setRGB(0.22, 0.22, 0.25); fixed++; }
      if (fullMetalDark) { m.metalness = 0.25; m.roughness = Math.max(m.roughness ?? 1, 0.6); fixed++; }
      // Ambient floor: guarantee nothing renders below ~6% brightness
      if (m.emissive && m.emissive.getHex() === 0 && !m.emissiveMap) {
        m.emissive = new Color(c ?? '#ffffff').multiplyScalar(0.06);
        m.emissiveIntensity = 1;
      }
      m.needsUpdate = true;
    }
  });
  if (fixed > 0) console.warn(`[FEL-LIGHT] liftBlackMaterials fixed ${fixed} materials`);
  return fixed;
}

export function LightRig({ mood = 'goldenHour' }: { mood?: VenueMood }) {
  const { gl, scene } = useThree();
  const M = MOODS[mood];

  useEffect(() => {
    gl.toneMapping = ACESFilmicToneMapping;
    gl.toneMappingExposure = M.exposure;
    gl.outputColorSpace = SRGBColorSpace;
    scene.background = new Color(M.background);
    // Kill any fog that blacks out at distance/height (mid-dunk blackout cause):
    scene.fog = null;

    const hemi = new HemisphereLight(new Color(M.sky), new Color(M.ground), M.hemi);
    const sun = new DirectionalLight(new Color(M.sun), M.sunI);
    sun.position.set(-M.sunDir[0] * 30, -M.sunDir[1] * 30, -M.sunDir[2] * 30);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    sun.shadow.camera.near = 1; sun.shadow.camera.far = 90;
    (['left','right','top','bottom'] as const).forEach((k, i) => {
      (sun.shadow.camera as any)[k] = [ -25, 25, 25, -25 ][i];
    });
    scene.add(hemi, sun, sun.target);

    liftBlackMaterials(scene);           // rescue whatever loaded before mount
    return () => { scene.remove(hemi, sun, sun.target); };
  }, [gl, scene, mood]);

  return null;
}

// Suggested moods: dunk/1v1/3v3/skate/surf → 'goldenHour' · tennis/golf/baseball
// → 'daylight' · karate → 'dojoWarm' · football/penalty → 'nightGame'.
