// CreatorLoop — what you make becomes what you play with.
//
// THE MISSING THREAD
// FEL has four creative modes: Music, Art, Dance, Acting. All four produce
// something. None of it goes anywhere.
//
// `CardBridge` (M76) can mint a Creator Card from a payload and pay royalties.
// `applyArtCard` (M76 v2) can skin a venue. But nothing connects "I made a
// track in Music" to "that track plays in my dunk contest", so the creative
// modes are a separate app that happens to share a login.
//
// That connection is the difference between four minigames and an ecosystem —
// and it is what makes the creative modes matter to a player who came here to
// play basketball. A track you made scoring your own dunk run is a reason to
// open Music. A track that lives in Music is not.
//
// THE RULE THAT KEEPS IT HONEST
// Equipping something you made must never make you BETTER. A custom track,
// court skin or victory dance is expression, and the moment expression affects
// outcomes, two things happen: players who do not care about creating are
// punished, and the marketplace becomes pay-to-win. So every equip in here is
// cosmetic or contextual, never mechanical. That is a constraint, and it is
// deliberately enforced in code rather than in a style guide.

export type CreationKind = 'track' | 'skin' | 'emote' | 'callout';

/** Where a creation can be equipped. */
export type EquipSlot =
  | 'soundtrack'      // plays during a mode
  | 'venue_skin'      // court/park surface art
  | 'victory'         // the celebration after a win
  | 'intro'           // the pre-match card
  | 'commentary';     // acting-mode callouts over big moments

export interface Creation {
  id: string;
  kind: CreationKind;
  /** Who made it. Drives royalties via CardBridge. */
  authorId: string;
  title: string;
  /** The mode that produced it. */
  sourceMode: string;
  createdAt: string;
  /** Kind-specific data. Opaque here — the producing mode owns its shape. */
  payload: unknown;
  /** Set once the creation has been published as a Creator Card. */
  cardId?: string;
}

/** Which kinds may occupy which slots. */
export const SLOT_ACCEPTS: Record<EquipSlot, CreationKind[]> = {
  soundtrack: ['track'],
  venue_skin: ['skin'],
  victory: ['emote'],
  intro: ['emote', 'track'],
  commentary: ['callout'],
};

/** Which creative mode produces what. */
export const MODE_PRODUCES: Record<string, CreationKind> = {
  music: 'track',
  art: 'skin',
  dance: 'emote',
  acting: 'callout',
};

/**
 * Modes that accept a given slot.
 *
 * `null` means every playable mode. The creative modes are excluded from
 * `soundtrack` on purpose: Music playing your own track over Music is a loop
 * with no meaning, and Dance needs its own beat to score against.
 */
export const SLOT_SCOPE: Record<EquipSlot, string[] | null> = {
  soundtrack: null,
  venue_skin: ['dunk', 'onevone', 'threevthree', 'dunkduel', 'carnival', 'skateboard'],
  victory: null,
  intro: null,
  commentary: ['dunk', 'onevone', 'threevthree', 'karate-vs', 'football'],
};

const NO_SOUNDTRACK = ['music', 'dance'];

export function slotAcceptsIn(slot: EquipSlot, modeId: string): boolean {
  if (slot === 'soundtrack' && NO_SOUNDTRACK.includes(modeId)) return false;
  const scope = SLOT_SCOPE[slot];
  return scope === null || scope.includes(modeId);
}

export interface Loadout {
  /** slot → creation id. */
  equipped: Partial<Record<EquipSlot, string>>;
}

export const EMPTY_LOADOUT: Loadout = { equipped: {} };

export class InvalidEquip extends Error {}

/**
 * Equip a creation.
 *
 * Throws rather than silently ignoring. A creative tool that appears to accept
 * something and then does nothing is the single most demoralising failure a
 * creator mode can have — and it is exactly what `applyArtCard` did for months
 * while looking for a mesh name no venue built.
 */
export function equip(loadout: Loadout, slot: EquipSlot, creation: Creation): Loadout {
  const accepted = SLOT_ACCEPTS[slot];
  if (!accepted) throw new InvalidEquip(`no such slot "${slot}"`);
  if (!accepted.includes(creation.kind)) {
    throw new InvalidEquip(
      `a ${creation.kind} cannot go in the ${slot} slot — that slot takes ${accepted.join(' or ')}`,
    );
  }
  return { equipped: { ...loadout.equipped, [slot]: creation.id } };
}

export function unequip(loadout: Loadout, slot: EquipSlot): Loadout {
  const next = { ...loadout.equipped };
  delete next[slot];
  return { equipped: next };
}

/**
 * What is actually active in a given mode.
 *
 * A loadout is global; what applies is per-mode. Equipping a court skin and
 * then playing tennis should not silently repaint a tennis court with
 * basketball art, and it should not look like the equip failed either — hence
 * `inactive`, which a UI can explain.
 */
export function activeIn(
  loadout: Loadout, modeId: string, library: Map<string, Creation>,
): { active: Partial<Record<EquipSlot, Creation>>; inactive: EquipSlot[] } {
  const active: Partial<Record<EquipSlot, Creation>> = {};
  const inactive: EquipSlot[] = [];

  for (const [slot, id] of Object.entries(loadout.equipped) as Array<[EquipSlot, string]>) {
    const creation = library.get(id);
    if (!creation) continue;                       // deleted; not an error
    if (slotAcceptsIn(slot, modeId)) active[slot] = creation;
    else inactive.push(slot);
  }
  return { active, inactive };
}

/**
 * THE NON-NEGOTIABLE RULE, ENFORCED IN CODE.
 *
 * A loadout must never change a gameplay number. This exists so the constraint
 * survives contact with a future feature that would very much like to give a
 * legendary track a 2% shot bonus — a review comment is forgettable and a
 * throwing function is not.
 */
export const GAMEPLAY_KEYS = [
  'speed', 'power', 'accuracy', 'damage', 'defense', 'score', 'multiplier',
  'window', 'reach', 'cooldown', 'health', 'stamina', 'prq', 'difficulty',
];

export function assertCosmetic(payload: unknown, context = 'creation'): void {
  if (!payload || typeof payload !== 'object') return;
  const walk = (o: unknown, path: string): void => {
    if (!o || typeof o !== 'object') return;
    for (const [k, v] of Object.entries(o as Record<string, unknown>)) {
      if (GAMEPLAY_KEYS.includes(k.toLowerCase())) {
        throw new InvalidEquip(
          `${context} carries a gameplay field "${path}${k}". Creations are expression, `
          + 'never advantage — the moment they affect outcomes the marketplace is pay-to-win '
          + 'and players who do not create are punished for it.',
        );
      }
      if (typeof v === 'object') walk(v, `${path}${k}.`);
    }
  };
  walk(payload, '');
}

/**
 * The loop, in one function: finish a creative session, get something
 * equippable.
 *
 * The `equipNow` hint matters more than it looks. A player who finishes a track
 * and is immediately asked "use this in your next game?" understands the loop
 * in one step. One who has to find a loadout screen never discovers it exists,
 * and the whole ecosystem thread dies in a menu.
 */
export function creationFrom(
  modeId: string, authorId: string, title: string, payload: unknown,
  now: () => string = () => new Date().toISOString(),
): { creation: Creation; equipNow: EquipSlot | null } {
  const kind = MODE_PRODUCES[modeId];
  if (!kind) throw new InvalidEquip(`"${modeId}" does not produce a creation`);
  assertCosmetic(payload, `${modeId} output`);

  const creation: Creation = {
    id: `${modeId}_${authorId}_${now()}`,
    kind, authorId, title, sourceMode: modeId, createdAt: now(), payload,
  };
  const slot = (Object.entries(SLOT_ACCEPTS) as Array<[EquipSlot, CreationKind[]]>)
    .find(([, kinds]) => kinds[0] === kind)?.[0] ?? null;
  return { creation, equipNow: slot };
}

/**
 * Which modes this creation will actually show up in.
 *
 * For the "you made this — here's where it plays" confirmation. Concrete and
 * checkable beats "equipped!", which tells a creator nothing about whether
 * their work will ever be seen.
 */
export function willAppearIn(kind: CreationKind, allModes: string[]): string[] {
  const slots = (Object.entries(SLOT_ACCEPTS) as Array<[EquipSlot, CreationKind[]]>)
    .filter(([, kinds]) => kinds.includes(kind))
    .map(([slot]) => slot);
  return allModes.filter((m) => slots.some((s) => slotAcceptsIn(s, m)));
}

/**
 * Attribution for a creation used in a session.
 *
 * Feeds `CardBridge.royaltiesFor()`, which pays exactly ONE hop — the author,
 * and nobody above them. That single-hop rule is what keeps the marketplace a
 * flat marketplace rather than a recruitment scheme, and it is load-bearing
 * legally, not just structurally. Multi-level payout is not a feature request.
 */
export function attributionFor(
  active: Partial<Record<EquipSlot, Creation>>, playerId: string,
): Array<{ authorId: string; slot: EquipSlot; creationId: string }> {
  return (Object.entries(active) as Array<[EquipSlot, Creation]>)
    .filter(([, c]) => c.authorId !== playerId)     // you do not pay yourself
    .map(([slot, c]) => ({ authorId: c.authorId, slot, creationId: c.id }));
}
