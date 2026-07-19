// Seed program guide + house-ad inventory. Times are templates — the scheduler
// materializes them week-over-week; edit freely in the admin surface later.

import type { Channel, StreamMeta, AdCreative, CreatorSpotlight } from './streamContracts';

export const CHANNELS: Channel[] = [
  {
    id: 'elijah-bonds', name: 'Elijah Bonds', avatarUrl: '/img/channels/eb.jpg',
    bio: 'Founder programming: HIIT, plyometrics & isometrics at every level, corrective SMR, and biomechanics you can actually use.',
    isHouse: true,
  },
  { id: 'fel-pilates', name: 'FEL Pilates', avatarUrl: '/img/channels/pilates.jpg', bio: 'Control, core, and length.', isHouse: true },
  { id: 'fel-dance', name: 'FEL Dance', avatarUrl: '/img/channels/dance.jpg', bio: 'Cardio that feels like a party.', isHouse: true },
];

/** Weekly template — day 0 = Monday. Materializer stamps concrete ISO dates. */
export const WEEKLY_TEMPLATE: Array<Omit<StreamMeta, 'id' | 'startsAt' | 'state'> & { day: number; timeLocal: string }> = [
  // Elijah Bonds flagship block
  { channelId: 'elijah-bonds', title: 'HIIT — Full Throttle 30', category: 'hiit',
    day: 1, timeLocal: '18:00', durationMin: 30, access: 'pass' },
  { channelId: 'elijah-bonds', title: 'Plyos & Isos — Regressed to Progressed', category: 'plyo_iso',
    day: 3, timeLocal: '18:00', durationMin: 45, access: 'pass' },
  { channelId: 'elijah-bonds', title: 'Corrective SMR — Release & Reset', category: 'smr_corrective',
    day: 5, timeLocal: '09:00', durationMin: 35, access: 'pass' },
  { channelId: 'elijah-bonds', title: 'Biomechanics in Practice — Move Better, Score Higher', category: 'biomech_edu',
    day: 6, timeLocal: '11:00', durationMin: 40, access: 'free' },   // free = funnel class
  // Studio block
  { channelId: 'fel-pilates', title: 'Pilates Core Foundations', category: 'pilates',
    day: 2, timeLocal: '08:00', durationMin: 40, access: 'pass' },
  { channelId: 'fel-dance', title: 'Dance Cardio Party', category: 'dance',
    day: 4, timeLocal: '19:00', durationMin: 40, access: 'free' },
];

/** House ads fill unsold inventory — the surface never runs empty. */
export const HOUSE_ADS: AdCreative[] = [
  {
    id: 'house_workout', slot: 'banner_live_tab', kind: 'house', label: 'FEL',
    imageUrl: '/img/ads/workout.jpg',
    headline: 'Train as yourself — personalized plan with YOUR avatar',
    cta: 'GET YOUR PLAN', deepLink: '/workout', weight: 3, active: true,
  },
  {
    id: 'house_shards', slot: 'preroll', kind: 'house', label: 'FEL',
    imageUrl: '/img/ads/shards.jpg',
    headline: 'Shard packs — unlock classes, plans & premium card slots',
    cta: 'SHOP SHARDS', deepLink: '/shop/shards', weight: 2, active: true,
  },
  {
    id: 'house_cards', slot: 'schedule_sponsor', kind: 'house', label: 'FEL',
    imageUrl: '/img/ads/cards.jpg',
    headline: 'Create your Creator Card — share your game',
    cta: 'CREATE', deepLink: '/cards/new', weight: 2, active: true,
  },
];

export const DEFAULT_SPOTLIGHTS: CreatorSpotlight[] = [
  { channelId: 'elijah-bonds', headline: 'Founder Series — new class live this week' },
];
