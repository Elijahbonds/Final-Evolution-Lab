// characterPipeline — ONE identity pipe for the player character, everywhere.
// scan proportions (M17) + face (face scan / Closet) + wardrobe (M20)
//   → PlayerIdentity → applied at spawn. Modes must use spawnPlayer()/spawnNpc().

import { Color3, PBRMaterial, StandardMaterial } from '@babylonjs/core';
import type { Scene } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter, type SpawnOpts } from './CharacterLibrary';
import type { AvatarProportions } from '../workout/contracts';        // M17
import type { FaceConfig, Wardrobe } from '../closet/closetContracts'; // M20

export interface PlayerIdentity {
  proportions: AvatarProportions | null;   // null until a body scan exists
  face: FaceConfig;
  wardrobe: Wardrobe;
  paletteOverride?: { jersey: string; shorts: string; shoes: string; accent: string };
}

let cached: PlayerIdentity | null = null;

/** Fetch + merge the user's identity once per session. Fail soft to defaults. */
export async function resolveIdentity(force = false): Promise<PlayerIdentity> {
  if (cached && !force) return cached;
  const [lookRes, scanRes] = await Promise.all([
    fetch('/api/closet').then((r) => (r.ok ? r.json() : null)).catch(() => null),
    fetch('/api/workout/plan').then((r) => (r.ok ? r.json() : null)).catch(() => null),
  ]);
  const look = lookRes?.look;
  const skin = lookRes?.cardSkins?.find(
    (s: { cardId: string }) => s.cardId === look?.equippedCardSkin,
  );
  cached = {
    proportions: scanRes?.plan?.athleteAvatar?.proportions ?? null,
    face: look?.face ?? (await import('../closet/closetContracts')).DEFAULT_FACE,
    wardrobe: skin?.wardrobe ?? look?.wardrobe
      ?? (await import('../closet/closetContracts')).DEFAULT_WARDROBE,
    paletteOverride: skin?.paletteOverride,
  };
  return cached;
}
/** Call on Closet save / new scan so the next spawn picks up changes. */
export function invalidateIdentity(): void { cached = null; }

// ── Application layers ──────────────────────────────────────────────────────

const BONE_SCALE: Record<string, string[]> = {
  torso: ['Spine', 'Spine1', 'Spine2'],
  arms: ['LeftArm', 'RightArm'],
  forearms: ['LeftForeArm', 'RightForeArm'],
  legs: ['LeftUpLeg', 'RightUpLeg'],
  shins: ['LeftLeg', 'RightLeg'],
  shoulders: ['LeftShoulder', 'RightShoulder'],
  hips: ['Hips'],
};

export function applyIdentity(spawn: SpawnedCharacter, id: PlayerIdentity): void {
  // 1) Proportions (scan) — bone-local scaling on the UNPREFIXED skeleton
  if (id.proportions) {
    spawn.root.scaling.scaleInPlace(id.proportions.height);
    for (const [key, bones] of Object.entries(BONE_SCALE)) {
      const s = (id.proportions as unknown as Record<string, number>)[key];
      if (!s) continue;
      for (const name of bones) {
        spawn.skeleton.bones.find((b) => b.name === name)?.getTransformNode()?.scaling.setAll(s);
      }
    }
  }
  // 2) Face — skin tone on skin materials; morphs when the rig has them
  applySkinTone(spawn, id.face.skinTone);
  applyMorphs(spawn, id.face);
  // 3) Wardrobe palette — jersey/shorts/shoes tints (mesh-slot wearables attach
  //    via the Closet rig seam where available; palette works on every model)
  if (id.paletteOverride) {
    tintSlot(spawn, ['jersey', 'top', 'shirt'], id.paletteOverride.jersey);
    tintSlot(spawn, ['shorts', 'pants', 'bottom'], id.paletteOverride.shorts);
    tintSlot(spawn, ['shoe', 'sneaker'], id.paletteOverride.shoes);
  }
}

function matColor(m: PBRMaterial & StandardMaterial): Color3 | undefined {
  return (m as PBRMaterial).albedoColor ?? (m as StandardMaterial).diffuseColor;
}
function applySkinTone(spawn: SpawnedCharacter, hex: string): void {
  const tone = Color3.FromHexString(hex);
  for (const mesh of spawn.meshes) {
    const m = mesh.material as (PBRMaterial & StandardMaterial) | null;
    const c = m && matColor(m);
    if (!c) continue;
    const isSkin = c.r > 0.45 && c.g > 0.25 && c.b > 0.15 && c.r > c.b && c.g > c.b * 0.9;
    if (!isSkin) continue;
    const clone = m!.clone(`${m!.name}_skin`);
    const cc = matColor(clone as never)!;
    cc.copyFrom(tone);
    mesh.material = clone;
  }
}
function applyMorphs(spawn: SpawnedCharacter, face: FaceConfig): void {
  // Blendshape path: map sliders → morph target influences when present.
  for (const mesh of spawn.meshes) {
    const mtm = mesh.morphTargetManager;
    if (!mtm) continue;
    for (let i = 0; i < mtm.numTargets; i++) {
      const t = mtm.getTarget(i);
      const n = t.name.toLowerCase();
      if (n.includes('jaw')) t.influence = face.faceShape.jaw;
      else if (n.includes('cheek')) t.influence = face.faceShape.cheeks;
      else if (n.includes('nose') && n.includes('width')) t.influence = face.nose.width;
      else if (n.includes('lip') || n.includes('mouth')) t.influence = face.mouth.lipFullness;
      else if (n.includes('eye') && n.includes('size')) t.influence = face.eyes.size;
    }
  }
  // No blendshapes on the current hero model → skin tone + wardrobe still apply;
  // the preset-based fallback (M20) covers face variety until a morph rig lands.
}
function tintSlot(spawn: SpawnedCharacter, keys: string[], hex: string): void {
  const tint = Color3.FromHexString(hex);
  for (const mesh of spawn.meshes) {
    const m = mesh.material as (PBRMaterial & StandardMaterial) | null;
    if (!m) continue;
    const name = `${mesh.name} ${m.name}`.toLowerCase();
    if (!keys.some((k) => name.includes(k))) continue;
    const clone = m.clone(`${m.name}_wear`);
    matColor(clone as never)?.copyFrom(tint);
    mesh.material = clone;
  }
}

// ── The only sanctioned spawn paths ─────────────────────────────────────────

export const CharacterPipeline = {
  /** Player-controlled character: identity ALWAYS applied. */
  async spawnPlayer(scene: Scene, url: string, opts: SpawnOpts = {}): Promise<SpawnedCharacter> {
    const [spawn, id] = await Promise.all([
      CharacterLibrary.spawn(scene, url, opts),
      resolveIdentity(),
    ]);
    applyIdentity(spawn, id);
    return spawn;
  },
  /** NPCs/mobs: variety, never the player's identity. */
  spawnNpc(scene: Scene, url: string, opts: SpawnOpts = {}): Promise<SpawnedCharacter> {
    return CharacterLibrary.spawn(scene, url, opts);
  },
};
