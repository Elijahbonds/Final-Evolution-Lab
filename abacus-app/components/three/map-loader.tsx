'use client';

import { useMemo } from 'react';
import * as THREE from 'three';
import { useGLTFAsset } from './gltf-loader';
import type { MapConfig } from '@/lib/map-data';

/**
 * Loads a Meshy environment GLB and renders it at the correct world scale.
 * Handles Draco + WebP textures via the shared GLTFLoader.
 * Applies the premium dark aesthetic: emissive boost, subtle environment mapping.
 */
export function MapMesh({ config }: { config: MapConfig }) {
  const gltf = useGLTFAsset(config.glb);

  const scene = useMemo(() => {
    const s = gltf.scene.clone(true);
    // Boost materials for premium dark look
    s.traverse((child) => {
      if ((child as THREE.Mesh).isMesh) {
        const mesh = child as THREE.Mesh;
        mesh.receiveShadow = true;
        mesh.castShadow = false; // environments receive, don't cast
        const mat = mesh.material as THREE.MeshStandardMaterial;
        if (mat?.isMeshStandardMaterial) {
          // Boost emissive slightly for glow in dark scenes
          if (mat.emissiveMap) {
            mat.emissiveIntensity = Math.max(mat.emissiveIntensity, 0.6);
          }
          // Slightly increase roughness for grounded look
          mat.roughness = Math.max(mat.roughness, 0.4);
          mat.envMapIntensity = 0.5;
          mat.needsUpdate = true;
        }
      }
    });
    return s;
  }, [gltf]);

  return (
    <primitive
      object={scene}
      scale={[config.scale, config.scale, config.scale]}
      position={[0, 0, 0]}
    />
  );
}
