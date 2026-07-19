// M18 FEL LIVE — shared contracts.

export type StreamCategory =
  | 'hiit' | 'plyo_iso' | 'smr_corrective' | 'biomech_edu'
  | 'pilates' | 'dance' | 'creator' | 'event';

export interface Channel {
  id: string;                 // 'elijah-bonds'
  name: string;               // 'Elijah Bonds'
  avatarUrl: string;
  bio: string;
  isHouse: boolean;           // FEL-owned programming
}

export interface StreamMeta {
  id: string;
  channelId: string;
  title: string;
  category: StreamCategory;
  startsAt: string;           // ISO
  durationMin: number;
  access: 'free' | 'pass';    // pass-gated classes
  hlsUrl?: string;            // present when live/replay available
  state: 'scheduled' | 'live' | 'replay' | 'ended';
  viewerCount?: number;
  sponsorAdId?: string;       // sold schedule-card sponsorship
}

// ── Advertising ────────────────────────────────────────────────────────────
export type AdSlotId = 'banner_live_tab' | 'preroll' | 'schedule_sponsor';

export interface AdCreative {
  id: string;
  slot: AdSlotId;
  kind: 'house' | 'sold';     // house = FEL services/products/in-game items
  label: string;              // rendered "AD" | "SPONSORED" | "FEL"
  imageUrl: string;
  headline: string;
  cta: string;                // 'SHOP SHARDS'
  deepLink: string;           // '/shop/shards' | external https
  weight: number;             // rotation weight
  active: boolean;
}

export interface AdImpression { creativeId: string; slot: AdSlotId; at: string; userId: string }

// ── Monetization ───────────────────────────────────────────────────────────
export interface ClassPassProduct {
  id: 'class_single' | 'class_monthly';
  name: string; shards: number;
  scope: 'one_stream' | 'all_access_30d';
}
export const CLASS_PASSES: ClassPassProduct[] = [
  { id: 'class_single', name: 'Single Class Pass', shards: 120, scope: 'one_stream' },
  { id: 'class_monthly', name: 'All-Access Month', shards: 600, scope: 'all_access_30d' },
];

export interface TipRequest { streamId: string; shards: 25 | 50 | 100 | 500 }
export interface TipEvent { userHandle: string; shards: number; at: string }

// ── API DTOs ───────────────────────────────────────────────────────────────
export interface GuideResponse {
  liveNow: StreamMeta[];
  upNext: StreamMeta[];       // next 48h, sorted
  replays: StreamMeta[];
  channels: Channel[];
  spotlights: CreatorSpotlight[];
  banner: AdCreative | null;  // resolved rotation pick for banner_live_tab
}

export interface CreatorSpotlight {
  channelId: string;
  headline: string;           // 'Creator of the Week'
  cardId?: string;            // links into the creator-card system
  clipUrl?: string;
}

export interface WatchHeartbeat { streamId: string; interacted: boolean }
export interface WatchGrant { seasonXp: number; capped: boolean }
