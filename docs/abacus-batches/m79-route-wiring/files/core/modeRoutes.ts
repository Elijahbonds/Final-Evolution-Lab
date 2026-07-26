// modeRoutes — the wiring artifact for the six unrouted modes.
//
// I cannot add the routes myself: they live in the Abacus-hosted Next.js app
// and this repo has no copy of it. So this is the piece that makes wiring a
// drop rather than a rewrite — a lazy import per mode, keyed by the same route
// string the registry uses.
//
// WHY LAZY IMPORTS, NOT A STATIC MAP
// Every mode pulls in Babylon, its venue, its core and its content pack. A
// static map means visiting /play/music downloads the karate wave AI, the
// rally engine and twenty venue specs. `() => import(...)` keeps each mode in
// its own chunk, so the route pays for what it loads and nothing else. On a
// 25-mode app that is the difference between a first load people wait through
// and one they don't.
//
// TWO SHAPES OF MODE, AND THEY MOUNT DIFFERENTLY
//   'harness' — a ModeDefinition, run by ModeHarness (all the 3-D modes)
//   'react'   — a React component that owns its own surface (Music, Art)
// Getting this wrong is not a subtle failure: handing a React component to
// ModeHarness calls `load(ctx)` on something that has no such method.

export type MountKind = 'harness' | 'react';

export interface RouteDef {
  route: string;
  kind: MountKind;
  /** Lazy loader. Returns the module; the caller picks the export. */
  load: () => Promise<unknown>;
  /** Named export to use from the module. */
  exportName: string;
  /** Shown while the chunk downloads. */
  label: string;
}

/**
 * The six routes M78 leaves to wire, plus the shape each one needs.
 *
 * Add the live modes here too if you want a single table driving every route;
 * they are omitted only because they already work and this batch should not
 * touch working routes.
 */
export const PENDING_ROUTES: RouteDef[] = [
  { route: 'dance', kind: 'harness', exportName: 'DanceMode', label: 'Dance',
    load: () => import('../modes/DanceMode') },
  { route: 'art', kind: 'react', exportName: 'default', label: 'Art',
    load: () => import('../modes/art/ArtMode') },
  { route: 'acting', kind: 'harness', exportName: 'ActingMode', label: 'Acting',
    load: () => import('../modes/ActingMode') },
  { route: 'irl', kind: 'harness', exportName: 'IRLMode', label: 'IRL Dunk',
    load: () => import('../modes/IRLMode') },
  { route: 'brain_brawl', kind: 'harness', exportName: 'BrainBrawlMode', label: 'Brain Brawl',
    load: () => import('../modes/BrainBrawlMode') },
  { route: 'who_scene_it', kind: 'harness', exportName: 'WhoSceneItMode', label: 'Who Scene It',
    load: () => import('../modes/WhoSceneItMode') },
];

export const routeDef = (route: string): RouteDef | undefined =>
  PENDING_ROUTES.find((r) => r.route === route);

/**
 * Resolve a route to its export.
 *
 * Returns null rather than throwing when the module is missing, so a route
 * whose chunk fails to load renders "unavailable" instead of a white screen
 * with a console error nobody sees.
 */
export async function loadMode(route: string): Promise<{ kind: MountKind; value: unknown } | null> {
  const def = routeDef(route);
  if (!def) return null;
  try {
    const mod = (await def.load()) as Record<string, unknown>;
    const value = mod[def.exportName];
    if (!value) {
      console.error(`[FEL-ROUTE] "${route}": module loaded but has no export "${def.exportName}"`);
      return null;
    }
    return { kind: def.kind, value };
  } catch (e) {
    console.error(`[FEL-ROUTE] "${route}" failed to load:`, e);
    return null;
  }
}

// ── WIRING ────────────────────────────────────────────────────────────────
//
// If /play/[mode] is a DYNAMIC route with a whitelist (most likely — every
// unknown mode currently 404s rather than erroring), the whole job is adding
// these six strings to that whitelist and mounting by `kind`:
//
//   const entry = await loadMode(params.mode);
//   if (!entry) return <NotFound />;
//   return entry.kind === 'react'
//     ? <ModeReactHost component={entry.value} />
//     : <ModeCanvasHost definition={entry.value} />;
//
// If instead each route is its own file, create six files that each call
// `loadMode('<route>')` — the table stays the single source either way.
//
// AFTER DEPLOYING, run:  node tools/route_audit.mjs
// It should report 25 live · 0 unrouted · 0 unbuilt. If a route 404s, it is
// not in the whitelist; if it 500s, `kind` is wrong for that mode.
