// applyArtCard v2 — REPLACES M28's.
//
// TWO BUGS IN v1, both of which meant an art card silently did nothing.
//
// 1. IT LOOKED FOR MESHES THAT DO NOT EXIST.
//    v1's mapping was `court: ['court_floor', 'ground']`. No venue has ever
//    built a mesh with either name — VenueKit uses `venue_ground`, and the
//    M73 Nexus venues deliberately match that prefix so the M64 camera
//    occlusion probe can see them. So `applyArtCard(scene, url, 'court')`
//    logged "no mesh" and returned false, every time. This is the same class
//    of failure as the M74 naming bug: a lookup by string that nothing
//    validates until it silently misses.
//
// 2. IT REPLACED A PBR MATERIAL WITH A STANDARD ONE.
//    v1 built a StandardMaterial. Every M73 venue surface is PBRMaterial, and
//    swapping one for the other throws away roughness/metallic and drops the
//    surface out of the scene's lighting model — the painted court would read
//    as flat and lit differently from everything around it. v2 paints the
//    existing material's albedo instead, so the art lands INSIDE the venue's
//    look rather than on top of it.

import { PBRMaterial, StandardMaterial, Texture } from '@babylonjs/core';
import type { AbstractMesh, Scene } from '@babylonjs/core';

/** Surface → candidate mesh names, in priority order.
 *
 *  Multiple names per surface on purpose: VenueKit-built venues, M73 Nexus
 *  venues and older hand-built scenes all name things differently, and an art
 *  card should work in whichever one the player is standing in. */
export const SURFACE_MESHES: Record<'court' | 'board' | 'kit' | 'ui', string[]> = {
  // `venue_ground` is what both VenueKit and NexusWebScene actually build.
  court: ['venue_ground', 'court_floor', 'park_floor', 'piste', 'ground'],
  board: ['board_deck', 'deck', 'ramp'],
  kit: ['jersey_mesh', 'torso', 'kit_mesh'],
  ui: [],   // UI skins are applied by the React layer, not to a mesh
};

export interface ApplyResult {
  ok: boolean;
  meshName?: string;
  reason?: string;
}

/** Find the first mesh matching any candidate name, exact first then prefix. */
export function findSurfaceMesh(scene: Scene, candidates: string[]): AbstractMesh | null {
  for (const name of candidates) {
    const exact = scene.getMeshByName(name);
    if (exact) return exact;
  }
  for (const name of candidates) {
    const pre = scene.meshes.find((m) => m.name.toLowerCase().startsWith(name.toLowerCase()));
    if (pre) return pre;
  }
  return null;
}

/**
 * Paint an art card onto a venue surface.
 *
 * Returns a structured result rather than a bare boolean so the caller can
 * tell "no such surface in this venue" from "the card had no image" — v1
 * returned false for both and logged an error either way.
 */
export function applyArtCard(
  scene: Scene,
  dataUrl: string,
  surface: 'court' | 'board' | 'kit' | 'ui',
): ApplyResult {
  if (!dataUrl?.startsWith('data:image/')) {
    return { ok: false, reason: 'card carries no painted canvas' };
  }
  if (surface === 'ui') {
    return { ok: false, reason: 'ui skins are applied by the React layer, not to a mesh' };
  }

  const mesh = findSurfaceMesh(scene, SURFACE_MESHES[surface]);
  if (!mesh) {
    return {
      ok: false,
      reason: `no "${surface}" surface in this venue (looked for: ${SURFACE_MESHES[surface].join(', ')})`,
    };
  }

  const tex = new Texture(dataUrl, scene, false, false);
  const mat = mesh.material;

  // Paint into whatever material is already there, preserving its lighting
  // response. Only build a new material when the mesh has none.
  if (mat instanceof PBRMaterial) {
    mat.albedoTexture = tex;
  } else if (mat instanceof StandardMaterial) {
    mat.diffuseTexture = tex;
  } else {
    const fresh = new PBRMaterial(`art_${mesh.name}`, scene);
    fresh.albedoTexture = tex;
    fresh.roughness = 0.85;
    fresh.metallic = 0;
    mesh.material = fresh;
  }

  console.info(`[FEL-ART] applied art card to "${mesh.name}" (${surface})`);
  return { ok: true, meshName: mesh.name };
}

/** Revert a surface to its venue default by dropping the painted texture. */
export function clearArtCard(scene: Scene, surface: 'court' | 'board' | 'kit'): boolean {
  const mesh = findSurfaceMesh(scene, SURFACE_MESHES[surface]);
  if (!mesh?.material) return false;
  const mat = mesh.material;
  if (mat instanceof PBRMaterial) { mat.albedoTexture?.dispose(); mat.albedoTexture = null; return true; }
  if (mat instanceof StandardMaterial) { mat.diffuseTexture?.dispose(); mat.diffuseTexture = null; return true; }
  return false;
}
