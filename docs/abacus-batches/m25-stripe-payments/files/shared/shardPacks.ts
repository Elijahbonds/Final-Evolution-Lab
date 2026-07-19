// The only real-money SKUs: shard packs. Single source of truth for store UI
// and server checkout creation. Prices in USD cents (Stripe smallest unit).

export interface ShardPack {
  id: string;
  name: string;
  shards: number;
  bonus: number;            // extra shards over base rate — the value ladder
  usdCents: number;
  badge?: string;
}

export const SHARD_PACKS: ShardPack[] = [
  { id: 'pack_starter', name: 'Starter Pack',  shards: 500,   bonus: 0,    usdCents: 499 },
  { id: 'pack_grinder', name: 'Grinder Pack',  shards: 1200,  bonus: 100,  usdCents: 999,  badge: 'POPULAR' },
  { id: 'pack_baller',  name: 'Baller Pack',   shards: 2600,  bonus: 400,  usdCents: 1999, badge: 'BEST VALUE' },
  { id: 'pack_legend',  name: 'Legend Pack',   shards: 7000,  bonus: 1500, usdCents: 4999 },
];

export function getPack(id: string): ShardPack | undefined {
  return SHARD_PACKS.find((p) => p.id === id);
}

// Pricing sanity: base rate ~100 shards/$1; bonuses reward bigger packs.
// Reference points in the economy: 4-week plan 300◆ · class 120◆ · monthly pass
// 600◆ · 12-week program 900◆ · 1-on-1 900◆ — the $9.99 pack covers any single
// flagship purchase with change.
