// Closet server API. Same seams as prior packages (EconomyService, Db).

import { CATALOG, CARD_SKINS, FACE_PRESETS } from '../shared/wearableCatalog';
import {
  DEFAULT_FACE, DEFAULT_WARDROBE,
  type ClosetResponse, type SaveLookRequest, type BuyWearableRequest,
  type AvatarLook, type Wardrobe,
} from '../shared/closetContracts';

export interface EconomyService {
  debitCoins(userId: string, amount: number, reason: string): Promise<{ ledgerId: string; balance: number }>;
  getCoinBalance(userId: string): Promise<number>;
}
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  delete(c: string, id: string): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
}
type Ctx = { userId: string; economy: EconomyService; db: Db };

const C = { looks: 'avatar_looks', owned: 'owned_wearables', cards: 'user_cards' };

const DEFAULT_OWNED = ['tee_fel', 'shorts_court', 'runner_white'];

// ── GET /api/closet ─────────────────────────────────────────────────────────
export async function getCloset(ctx: Ctx): Promise<ClosetResponse> {
  const look = (await ctx.db.get<AvatarLook>(C.looks, ctx.userId)) ?? defaultLook(ctx.userId);
  const ownedDoc = await ctx.db.get<{ items: string[] }>(C.owned, ctx.userId);
  const owned = [...new Set([...DEFAULT_OWNED, ...(ownedDoc?.items ?? [])])];

  // Card skins limited to cards this user owns (existing user_cards collection)
  const userCards = await ctx.db.query<{ card_id?: string; cardId?: string }>(C.cards, { user_id: ctx.userId });
  const ownedCardIds = new Set(userCards.map((c) => c.cardId ?? c.card_id).filter(Boolean) as string[]);
  const cardSkins = CARD_SKINS.filter((s) => ownedCardIds.has(s.cardId));

  return {
    look,
    ownedWearables: owned,
    catalog: CATALOG,
    cardSkins,
    coinBalance: await ctx.economy.getCoinBalance(ctx.userId),
    facePresets: FACE_PRESETS,   // client ignores when blendshapes are available
  };
}

// ── POST /api/closet/buy ────────────────────────────────────────────────────
export async function buyWearable(ctx: Ctx, req: BuyWearableRequest): Promise<{ ok: true; balance: number }> {
  const item = CATALOG.find((i) => i.id === req.itemId);
  if (!item) throw err(404, 'unknown item');
  if (item.cardSkinOnly) throw err(403, 'obtainable only through a Creator Card skin');

  const ownedDoc = await ctx.db.get<{ items: string[] }>(C.owned, ctx.userId);
  const items = ownedDoc?.items ?? [];
  if (items.includes(item.id) || DEFAULT_OWNED.includes(item.id)) throw err(409, 'already owned');

  const { balance } = await ctx.economy.debitCoins(ctx.userId, item.priceCoins, `wearable:${item.id}`);
  await ctx.db.put(C.owned, ctx.userId, { userId: ctx.userId, items: [...items, item.id] });
  return { ok: true, balance };
}

// ── POST /api/closet/look ───────────────────────────────────────────────────
export async function saveLook(ctx: Ctx, req: SaveLookRequest): Promise<{ ok: true }> {
  // Validate wardrobe: every equipped item must be owned (or default)
  const ownedDoc = await ctx.db.get<{ items: string[] }>(C.owned, ctx.userId);
  const owned = new Set([...DEFAULT_OWNED, ...(ownedDoc?.items ?? [])]);

  if (req.equippedCardSkin) {
    const skin = CARD_SKINS.find((s) => s.cardId === req.equippedCardSkin);
    if (!skin) throw err(404, 'unknown card skin');
    const userCards = await ctx.db.query<{ card_id?: string; cardId?: string }>(C.cards, { user_id: ctx.userId });
    const ownsCard = userCards.some((c) => (c.cardId ?? c.card_id) === req.equippedCardSkin);
    if (!ownsCard) throw err(403, 'card not owned');
  } else {
    for (const [slot, itemId] of Object.entries(req.wardrobe) as [keyof Wardrobe, string | null][]) {
      if (!itemId) continue;
      const item = CATALOG.find((i) => i.id === itemId);
      if (!item || item.slot !== normalizeSlot(slot)) throw err(422, `invalid item for ${slot}`);
      if (!owned.has(itemId)) throw err(403, `not owned: ${itemId}`);
    }
  }

  // Face values clamped server-side — never trust slider bounds from the client
  const clamp01 = (n: number) => Math.min(1, Math.max(0, Number(n) || 0));
  const face = structuredClone(req.face);
  for (const g of [face.faceShape, face.eyes, face.brows, face.nose, face.mouth] as Record<string, unknown>[]) {
    for (const k of Object.keys(g)) if (typeof g[k] === 'number') g[k] = clamp01(g[k] as number);
  }

  const look: AvatarLook = {
    userId: ctx.userId,
    face,
    wardrobe: req.wardrobe,
    equippedCardSkin: req.equippedCardSkin,
    updatedAt: new Date().toISOString(),
  };
  await ctx.db.put(C.looks, ctx.userId, look);
  return { ok: true };
}

// ── resolveLook — used by EVERY avatar render site (games, movies, hub) ─────
export async function resolveLook(ctx: Ctx): Promise<AvatarLook> {
  const look = (await ctx.db.get<AvatarLook>(C.looks, ctx.userId)) ?? defaultLook(ctx.userId);
  if (look.equippedCardSkin) {
    const skin = CARD_SKINS.find((s) => s.cardId === look.equippedCardSkin);
    if (skin) return { ...look, wardrobe: skin.wardrobe };  // card skin overrides wardrobe
  }
  return look;
}

// ── DELETE /api/closet (delete-my-data parity) ──────────────────────────────
export async function deleteLook(ctx: Ctx): Promise<{ ok: true }> {
  await ctx.db.delete(C.looks, ctx.userId);
  return { ok: true };
}

function defaultLook(userId: string): AvatarLook {
  return {
    userId, face: DEFAULT_FACE, wardrobe: DEFAULT_WARDROBE,
    equippedCardSkin: null, updatedAt: new Date(0).toISOString(),
  };
}
function normalizeSlot(slot: keyof Wardrobe): string {
  return slot === 'headwear' ? 'headwear' : slot === 'accessory' ? 'accessory'
    : slot === 'top' ? 'top' : slot === 'bottom' ? 'bottom' : 'shoes';
}
function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
