// Seed wearable catalog + example Creator Card skins. Prices in COINS (soft
// currency, earned by play) — cosmetics only, never stats.

import type { WearableItem, CardSkin, FacePreset } from './closetContracts';
import { DEFAULT_FACE } from './closetContracts';

export const CATALOG: WearableItem[] = [
  // Defaults (free, everyone owns)
  { id: 'tee_fel', slot: 'top', name: 'FEL Tee', rarity: 'common', priceCoins: 0, meshId: 'wear.tee_fel', palette: ['#22d3ee'] },
  { id: 'shorts_court', slot: 'bottom', name: 'Court Shorts', rarity: 'common', priceCoins: 0, meshId: 'wear.shorts_court', palette: ['#0f172a'] },
  { id: 'runner_white', slot: 'shoes', name: 'White Runners', rarity: 'common', priceCoins: 0, meshId: 'wear.runner_white' },

  // Tops
  { id: 'jersey_venice', slot: 'top', name: 'Venice Jersey', rarity: 'rare', priceCoins: 400, meshId: 'wear.jersey_venice', palette: ['#f59e0b', '#0ea5e9'] },
  { id: 'hoodie_nexus', slot: 'top', name: 'Nexus Hoodie', rarity: 'elite', priceCoins: 900, meshId: 'wear.hoodie_nexus', palette: ['#a855f7'] },
  { id: 'gi_top', slot: 'top', name: 'Dojo Gi', rarity: 'rare', priceCoins: 450, meshId: 'wear.gi_top', palette: ['#f8fafc'] },

  // Bottoms
  { id: 'joggers_beach', slot: 'bottom', name: 'Beach Joggers', rarity: 'rare', priceCoins: 350, meshId: 'wear.joggers_beach' },
  { id: 'gi_pants', slot: 'bottom', name: 'Gi Pants', rarity: 'rare', priceCoins: 350, meshId: 'wear.gi_pants' },

  // Shoes
  { id: 'high_top_flame', slot: 'shoes', name: 'Flame High-Tops', rarity: 'elite', priceCoins: 800, meshId: 'wear.high_top_flame', palette: ['#ef4444', '#f59e0b'] },
  { id: 'skate_lows', slot: 'shoes', name: 'Skate Lows', rarity: 'rare', priceCoins: 400, meshId: 'wear.skate_lows' },

  // Headwear
  { id: 'cap_fel', slot: 'headwear', name: 'FEL Snapback', rarity: 'common', priceCoins: 200, meshId: 'wear.cap_fel' },
  { id: 'headband_court', slot: 'headwear', name: 'Court Headband', rarity: 'common', priceCoins: 150, meshId: 'wear.headband_court' },
  { id: 'beanie_snow', slot: 'headwear', name: 'Slope Beanie', rarity: 'rare', priceCoins: 300, meshId: 'wear.beanie_snow' },

  // Accessories
  { id: 'chain_gold', slot: 'accessory', name: 'Gold Chain', rarity: 'elite', priceCoins: 1000, meshId: 'wear.chain_gold' },
  { id: 'wristband_pair', slot: 'accessory', name: 'Wristbands', rarity: 'common', priceCoins: 100, meshId: 'wear.wristband_pair' },
  { id: 'keyblade_sig', slot: 'accessory', name: 'Signature Keyblade', rarity: 'legendary', priceCoins: 0, meshId: 'wear.keyblade_sig', cardSkinOnly: true },
];

/** Skins bundled with Creator Cards (ownership of the CARD unlocks the skin). */
export const CARD_SKINS: CardSkin[] = [
  {
    cardId: 'card_golden_hour',
    name: 'Golden Hour Set',
    wardrobe: { headwear: null, top: 'jersey_venice', bottom: 'joggers_beach', shoes: 'high_top_flame', accessory: 'chain_gold' },
    paletteOverride: { jersey: '#f59e0b', shorts: '#78350f', shoes: '#fbbf24', accent: '#fff7ed' },
  },
  {
    cardId: 'card_nexus_glitch',
    name: 'Glitch Runner Set',
    wardrobe: { headwear: 'beanie_snow', top: 'hoodie_nexus', bottom: 'shorts_court', shoes: 'skate_lows', accessory: 'keyblade_sig' },
    paletteOverride: { jersey: '#a855f7', shorts: '#1e1b4b', shoes: '#22d3ee', accent: '#f0abfc' },
    signatureItemId: 'keyblade_sig',
  },
];

/** Fallback presets when the model has no blendshapes (README §Integration 1). */
export const FACE_PRESETS: FacePreset[] = [
  { id: 'preset_default', label: 'Classic', config: DEFAULT_FACE },
  { id: 'preset_wide', label: 'Bold', config: { ...DEFAULT_FACE, faceShape: { width: 0.8, jaw: 0.7, cheeks: 0.6 } } },
  { id: 'preset_narrow', label: 'Sharp', config: { ...DEFAULT_FACE, faceShape: { width: 0.3, jaw: 0.35, cheeks: 0.4 } } },
  { id: 'preset_soft', label: 'Soft', config: { ...DEFAULT_FACE, faceShape: { width: 0.55, jaw: 0.4, cheeks: 0.75 }, mouth: { width: 0.5, lipFullness: 0.7, smileRest: 0.65 } } },
];
