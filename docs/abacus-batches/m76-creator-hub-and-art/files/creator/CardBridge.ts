// CardBridge — the missing spine between the five disciplines and a card.
//
// M28 shipped the Creator Card TYPES (good ones) and a server API, plus a
// CreatorHub that picks a discipline. What it never shipped was the thing in
// between: something that takes what a mode actually produces — a music track,
// a dance routine, a painted canvas — and turns it into a validated
// CreatorCard. Without it, `/creator` had nothing to be a page *for*.
//
// Every rule below is enforced HERE as well as on the server, because the
// client should never be able to construct an invalid card and discover it
// only after a round trip. The server remains authoritative; this is the fast
// no.
//
// Babylon-free and React-free on purpose, so it can be executed as a test.

import type {
  ArtPayload, CardRarity, CardStats, CreatorCard, Discipline, SportDesignation,
} from './CreatorCardTypes';
import { NEEDS_REVIEW, REMIX_ROYALTY_COINS } from './CreatorCardTypes';

export class InvalidCard extends Error {
  readonly field: string;
  constructor(field: string, message: string) {
    super(message);
    this.name = 'InvalidCard';
    this.field = field;
  }
}

export const MAX_SECONDARY = 2;

export const RARITY_TIERS: CardRarity[] = [
  { tier: 'common', statMultiplier: 1.0 },
  { tier: 'rare', statMultiplier: 1.15 },
  { tier: 'epic', statMultiplier: 1.35 },
  { tier: 'legendary', statMultiplier: 1.6 },
];

export function rarityFor(tier: CardRarity['tier']): CardRarity {
  const r = RARITY_TIERS.find((x) => x.tier === tier);
  if (!r) throw new InvalidCard('rarity', `unknown rarity tier "${tier}"`);
  return r;
}

/** The payload `kind` must match the PRIMARY discipline. A music card carrying
 *  an art payload would render as a blank track in the marketplace — a class
 *  of bug that is invisible until someone buys it. */
export function payloadMatchesDiscipline(primary: Discipline, art: ArtPayload): boolean {
  return art.kind === primary;
}

export interface BuildCardInput {
  ownerId: string;
  title: string;
  primary: Discipline;
  secondary?: Discipline[];
  sportDesignation?: SportDesignation;
  art: ArtPayload;
  stats?: Partial<CardStats>;
  rarity?: CardRarity['tier'];
  isPublic?: boolean;
  remixOf?: string;
  /** Must be literally true — the explicit checkbox, never a default. */
  licenseAccepted: boolean;
}

const DEFAULT_STATS: CardStats = {
  moveset: [],
  gearModifier: {},
  hypeMultiplier: 1,
  bpmSyncBonus: 0,
};

/**
 * Build a validated card draft. Throws `InvalidCard` with the offending field
 * rather than returning a boolean, so the UI can focus the right input.
 */
export function buildCard(input: BuildCardInput, now: () => string = () => new Date().toISOString()): CreatorCard {
  const secondary = input.secondary ?? [];

  if (!input.ownerId) throw new InvalidCard('ownerId', 'a card needs an owner');
  if (!input.title.trim()) throw new InvalidCard('title', 'give the card a title');

  // The license is an opt-in, and the ONLY way it becomes true is the user
  // ticking it. Defaulting it would make every card carry a licence its
  // creator never agreed to.
  if (input.licenseAccepted !== true) {
    throw new InvalidCard('licenseAccepted', 'the creator licence must be accepted explicitly');
  }

  if (secondary.length > MAX_SECONDARY) {
    throw new InvalidCard('secondary', `at most ${MAX_SECONDARY} secondary disciplines (got ${secondary.length})`);
  }
  if (secondary.includes(input.primary)) {
    throw new InvalidCard('secondary', 'the primary discipline cannot also be secondary');
  }
  if (new Set(secondary).size !== secondary.length) {
    throw new InvalidCard('secondary', 'duplicate secondary disciplines');
  }

  const involvesSport = input.primary === 'sport' || secondary.includes('sport');
  if (involvesSport && !input.sportDesignation) {
    throw new InvalidCard('sportDesignation', 'a card involving sport must name which sport');
  }
  if (!involvesSport && input.sportDesignation) {
    throw new InvalidCard('sportDesignation', 'sportDesignation is only meaningful when sport is involved');
  }

  if (!payloadMatchesDiscipline(input.primary, input.art)) {
    throw new InvalidCard('art', `primary is "${input.primary}" but the payload is "${input.art.kind}"`);
  }

  validatePayload(input.art);

  // UGC audio is reviewed before it can be public. This is a content-safety
  // gate, so it is decided by the payload, never by the caller.
  const reviewState = NEEDS_REVIEW.includes(input.primary) ? 'pending_review' : 'approved';

  return {
    id: `card_${input.ownerId}_${Date.now().toString(36)}`,
    ownerId: input.ownerId,
    title: input.title.trim(),
    primary: input.primary,
    secondary,
    ...(input.sportDesignation ? { sportDesignation: input.sportDesignation } : {}),
    art: input.art,
    stats: { ...DEFAULT_STATS, ...input.stats },
    rarity: rarityFor(input.rarity ?? 'common'),
    createdAt: now(),
    isPublic: input.isPublic ?? false,
    ...(input.remixOf ? { remixOf: input.remixOf } : {}),
    licenseAccepted: true,
    reviewState,
  };
}

/** Per-discipline payload requirements. A card whose payload is missing its
 *  content is worse than no card — it lists, sells, and delivers nothing. */
export function validatePayload(art: ArtPayload): void {
  switch (art.kind) {
    case 'music':
      if (!art.trackId) throw new InvalidCard('art.trackId', 'a music card needs a track');
      if (!art.stemUrls?.length) throw new InvalidCard('art.stemUrls', 'a music card needs at least one stem');
      if (!(art.bpm > 0)) throw new InvalidCard('art.bpm', 'a music card needs a positive BPM');
      break;
    case 'art':
      if (!art.canvasDataUrl?.startsWith('data:image/')) {
        throw new InvalidCard('art.canvasDataUrl', 'an art card needs a painted canvas');
      }
      if (!art.palette?.length) throw new InvalidCard('art.palette', 'an art card needs its palette recorded');
      break;
    case 'dance':
      if (!art.choreographyId) throw new InvalidCard('art.choreographyId', 'a dance card needs a routine id');
      if (!art.sequence?.length) throw new InvalidCard('art.sequence', 'a dance card needs at least one step');
      break;
    case 'acting':
      if (!art.sceneId) throw new InvalidCard('art.sceneId', 'an acting card needs a scene');
      if (!art.performanceUrl) throw new InvalidCard('art.performanceUrl', 'an acting card needs a recording');
      break;
    case 'sport':
      if (!art.routineId && !art.signatureMoveId && !art.highlightReelUrl) {
        throw new InvalidCard('art', 'a sport card needs a routine, a signature move, or a highlight reel');
      }
      break;
  }
}

// ── remix royalties ───────────────────────────────────────────────────────

export interface RoyaltyPayment { toUserId: string; coins: number; reason: string }

/**
 * Who gets paid when `card` is published as a remix.
 *
 * **Exactly one hop, always.** The royalty goes to the immediate parent's
 * creator and stops there — it never walks up the remix chain paying every
 * ancestor. That is a deliberate structural limit, not an optimisation: a
 * royalty that compounds up a lineage turns a marketplace into a downline,
 * which is the thing this economy is explicitly not allowed to be. Keeping it
 * one hop keeps it a flat marketplace where each creator is paid for their own
 * work and nobody earns from recruiting.
 *
 * Returns an empty array for an original card, and never pays a creator for
 * remixing themselves.
 */
export function royaltiesFor(
  card: CreatorCard,
  parent: Pick<CreatorCard, 'id' | 'ownerId'> | null,
): RoyaltyPayment[] {
  if (!card.remixOf || !parent) return [];
  if (parent.id !== card.remixOf) return [];
  if (parent.ownerId === card.ownerId) return [];        // no self-payment
  return [{
    toUserId: parent.ownerId,
    coins: REMIX_ROYALTY_COINS,
    reason: `remix royalty for ${parent.id}`,
  }];
}

// ── payload constructors, one per discipline ──────────────────────────────
// These exist so each mode has ONE obvious call rather than assembling a
// union member by hand and getting `kind` wrong.

export const Payloads = {
  music(trackId: string, stemUrls: string[], bpm: number, keySignature: string, coverArtUrl = ''): ArtPayload {
    return { kind: 'music', trackId, stemUrls, coverArtUrl, bpm, keySignature };
  },
  art(canvasDataUrl: string, palette: string[], brushSetId: string,
      appliedSurface: 'court' | 'board' | 'kit' | 'ui'): ArtPayload {
    return { kind: 'art', canvasDataUrl, palette, brushSetId, appliedSurface };
  },
  dance(choreographyId: string, sequence: ArtPayload extends { kind: 'dance' } ? never : { clipId: string; beat: number; holdBeats: number; mirrored: boolean }[],
        routineVideoUrl?: string): ArtPayload {
    return { kind: 'dance', choreographyId, sequence, ...(routineVideoUrl ? { routineVideoUrl } : {}) };
  },
  acting(sceneId: string, performanceUrl: string, voiceLineIds: string[] = []): ArtPayload {
    return { kind: 'acting', sceneId, performanceUrl, voiceLineIds };
  },
  sport(opts: { routineId?: string; signatureMoveId?: string; highlightReelUrl?: string }): ArtPayload {
    return { kind: 'sport', ...opts };
  },
};
