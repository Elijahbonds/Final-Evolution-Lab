// M20 — Closet contracts. AvatarLook = face + wardrobe + optional card skin.
// Merged into MiniAvatarSpec (M17) at every render site via resolveLook().

// ── Face ────────────────────────────────────────────────────────────────────

export interface FaceConfig {
  /** Hex skin tone; UI offers 12 curated swatches + fine slider between them. */
  skinTone: string;
  /** Morph-target weights 0..1 (blendshape path). */
  faceShape: { width: number; jaw: number; cheeks: number };
  eyes: { shape: number; size: number; spacing: number; color: string };
  brows: { thickness: number; angle: number; color: string };
  nose: { width: number; length: number; bridge: number };
  mouth: { width: number; lipFullness: number; smileRest: number };
  hair: { styleId: HairStyleId; color: string };
  extras: { freckles: number; facialHairId: FacialHairId | null; facialHairColor: string };
}

export type HairStyleId =
  | 'afro' | 'high_top' | 'braids' | 'locs' | 'cornrows' | 'twists'
  | 'straight_short' | 'straight_long' | 'wavy' | 'curly' | 'buzz' | 'bald'
  | 'ponytail' | 'buns' | 'hijab';

export type FacialHairId = 'stubble' | 'goatee' | 'full_beard' | 'mustache';

/** Fallback path when the character model has no blendshapes: discrete presets. */
export interface FacePreset { id: string; label: string; config: FaceConfig }

// ── Wearables ───────────────────────────────────────────────────────────────

export type WearableSlot = 'headwear' | 'top' | 'bottom' | 'shoes' | 'accessory';
export type Rarity = 'common' | 'rare' | 'elite' | 'legendary';

export interface WearableItem {
  id: string;
  slot: WearableSlot;
  name: string;
  rarity: Rarity;
  priceCoins: number;          // 0 = default/free item
  meshId: string;              // asset reference resolved by the rig seam
  palette?: string[];          // recolorable channels, hex defaults
  cardSkinOnly?: boolean;      // only obtainable via a Creator Card skin
}

export interface Wardrobe {
  headwear: string | null;     // WearableItem ids
  top: string;                 // top/bottom/shoes always present (defaults)
  bottom: string;
  shoes: string;
  accessory: string | null;
}

// ── Creator Card skins ──────────────────────────────────────────────────────

/** A full themed look bundled with a Creator Card the player owns. */
export interface CardSkin {
  cardId: string;
  name: string;
  wardrobe: Wardrobe;
  paletteOverride?: { jersey: string; shorts: string; shoes: string; accent: string };
  signatureItemId?: string;    // renders in karate 1v1 etc. (M14 §3.1)
}

// ── The saved look ──────────────────────────────────────────────────────────

export interface AvatarLook {
  userId: string;
  face: FaceConfig;
  wardrobe: Wardrobe;
  equippedCardSkin: string | null;   // cardId; when set, cardSkin overrides wardrobe
  updatedAt: string;
}

// ── API DTOs ────────────────────────────────────────────────────────────────

export interface ClosetResponse {
  look: AvatarLook;
  ownedWearables: string[];          // item ids
  catalog: WearableItem[];           // full catalog with prices (locked = not owned)
  cardSkins: CardSkin[];             // skins from cards this user OWNS
  coinBalance: number;
  facePresets: FacePreset[];         // populated only in no-blendshape fallback mode
}

export interface BuyWearableRequest { itemId: string }
export interface SaveLookRequest { face: FaceConfig; wardrobe: Wardrobe; equippedCardSkin: string | null }

// ── Defaults ────────────────────────────────────────────────────────────────

export const DEFAULT_FACE: FaceConfig = {
  skinTone: '#b98a63',
  faceShape: { width: 0.5, jaw: 0.5, cheeks: 0.5 },
  eyes: { shape: 0.5, size: 0.5, spacing: 0.5, color: '#4a2f1d' },
  brows: { thickness: 0.5, angle: 0.5, color: '#1f1b16' },
  nose: { width: 0.5, length: 0.5, bridge: 0.5 },
  mouth: { width: 0.5, lipFullness: 0.5, smileRest: 0.55 },
  hair: { styleId: 'curly', color: '#1f1b16' },
  extras: { freckles: 0, facialHairId: null, facialHairColor: '#1f1b16' },
};

export const SKIN_SWATCHES = [
  '#f6e0cf', '#f0d0b0', '#e6b98f', '#d9a06f', '#c98a5a', '#b97a4b',
  '#a5683f', '#8f5734', '#7a482c', '#644027', '#503322', '#3c281c',
];

export const DEFAULT_WARDROBE: Wardrobe = {
  headwear: null, top: 'tee_fel', bottom: 'shorts_court', shoes: 'runner_white', accessory: null,
};
