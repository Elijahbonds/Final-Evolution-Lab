// modeRegistry — ONE source of truth for route ↔ modeId ↔ venue ↔ module.
//
// WHY THIS EXISTS (a mistake worth encoding against)
// While auditing the project I reported nine modes as "built but never
// routed". Six of them were live. I had probed `/play/skateboarding`,
// `/play/snowboarding`, `/play/surfing` — but the modes declare
// `modeId: 'skateboard' | 'snowboard' | 'surf'`, so the real routes are
// `/play/skateboard` and friends. The information needed to avoid that was
// spread across four places that nothing reconciles:
//
//   · the route path              (Next.js app router)
//   · `modeId` inside each mode   (modes/*.ts)
//   · the venue id                (nexus/venueSpecs.ts)
//   · the backend mode id         (backend/FEL_ModeManager.production.json)
//
// Four names for one thing, none of them checked against each other. That is
// also how M74 shipped duplicate tennis/volleyball modes when working ones
// already existed, and how `applyArtCard` spent months looking for a mesh
// name no venue builds. Same failure, three times.
//
// This table is the reconciliation. `tools/route_audit.mjs` checks it against
// the live app and against the files on disk, so "is this mode routed?" is a
// command instead of a guess.

export type ModeStatus =
  /** Routed, live, playable. */
  | 'live'
  /** The mode module exists but no route points at it. */
  | 'unrouted'
  /** Named in a registry, but no mode module has ever been written. */
  | 'unbuilt';

export interface ModeEntry {
  /** URL segment: /play/<route>. MUST equal the mode's own `modeId`. */
  route: string;
  /** `modeId` as declared inside the ModeDefinition. */
  modeId: string;
  /** Human label for menus. */
  label: string;
  /** Key into VENUE_SPECS (nexus/venueSpecs.ts). Null = uses VenueKit. */
  venueId: string | null;
  /** Mode id as it appears in backend/FEL_ModeManager.production.json. */
  backendId: string | null;
  /** Module path relative to the game source root, for the router import. */
  module: string | null;
  status: ModeStatus;
}

/**
 * Every mode this project has ever named. Verified against the live app on
 * 2026-07-26 by probing each route.
 *
 * KEEP `route` AND `modeId` IDENTICAL. They diverged informally for the board
 * sports and cost a full audit cycle. The audit tool fails the build if they
 * ever differ again.
 */
export const MODE_REGISTRY: ModeEntry[] = [
  // ── basketball ──────────────────────────────────────────────────────────
  { route: 'dunk', modeId: 'dunk', label: 'Dunk Contest', venueId: 'basketball_dunk', backendId: 'basketball_dunk', module: 'modes/DunkMode', status: 'live' },
  { route: 'onevone', modeId: 'onevone', label: '1v1 Hoops', venueId: 'basketball_h2h', backendId: 'basketball_h2h', module: 'modes/OneVOneMode', status: 'live' },
  { route: 'threevthree', modeId: 'threevthree', label: '3v3', venueId: 'basketball_3v3', backendId: 'basketball_3v3', module: 'modes/ThreeVThreeMode', status: 'live' },
  { route: 'dunkduel', modeId: 'dunkduel', label: 'Dunk Duel', venueId: 'basketball_dunk', backendId: null, module: 'modes/DunkDuelMode', status: 'live' },
  { route: 'carnival', modeId: 'carnival', label: 'Court Carnival', venueId: 'court_carnival', backendId: 'court_carnival', module: 'modes/CourtCarnivalMode', status: 'live' },

  // ── combat ──────────────────────────────────────────────────────────────
  { route: 'karate', modeId: 'karate', label: 'Karate Endless', venueId: 'karate_endless', backendId: 'karate_endless', module: 'modes/KarateEndlessMode', status: 'live' },
  { route: 'karate-vs', modeId: 'karate-vs', label: 'Karate VS', venueId: 'karate_h2h', backendId: 'karate_h2h', module: 'modes/KarateVSMode', status: 'live' },
  { route: 'mixedcombat', modeId: 'mixedcombat', label: 'Mixed Combat', venueId: 'karate_h2h', backendId: null, module: 'modes/MixedCombatMode', status: 'live' },

  // ── field & precision (all served by precisionModes.ts) ─────────────────
  { route: 'soccer', modeId: 'soccer', label: 'Soccer', venueId: 'soccer', backendId: 'soccer', module: 'modes/precisionModes', status: 'live' },
  { route: 'football', modeId: 'football', label: 'Football', venueId: 'football', backendId: 'football', module: 'modes/FootballRushMode', status: 'live' },
  { route: 'baseball', modeId: 'baseball', label: 'Baseball', venueId: 'baseball', backendId: 'baseball', module: 'modes/precisionModes', status: 'live' },
  { route: 'tennis', modeId: 'tennis', label: 'Tennis', venueId: 'tennis', backendId: 'tennis', module: 'modes/precisionModes', status: 'live' },
  { route: 'golf', modeId: 'golf', label: 'Golf', venueId: 'golf', backendId: 'golf', module: 'modes/precisionModes', status: 'live' },
  { route: 'volleyball', modeId: 'volleyball', label: 'Volleyball', venueId: 'volleyball', backendId: 'volleyball', module: 'modes/precisionModes', status: 'live' },
  { route: 'gymnastics', modeId: 'gymnastics', label: 'Gymnastics', venueId: 'gymnastics', backendId: 'gymnastics', module: 'modes/precisionModes', status: 'live' },

  // ── board ───────────────────────────────────────────────────────────────
  { route: 'skateboard', modeId: 'skateboard', label: 'Skate Run', venueId: 'skateboarding', backendId: 'skateboarding', module: 'modes/SkateRunMode', status: 'live' },
  { route: 'snowboard', modeId: 'snowboard', label: 'Snowboard Slalom', venueId: 'snowboarding', backendId: 'snowboarding', module: 'modes/SnowboardSlalomMode', status: 'live' },
  { route: 'surf', modeId: 'surf', label: 'Surf Break', venueId: 'surfing', backendId: 'surfing', module: 'modes/SurfBreakMode', status: 'live' },

  // ── creative ────────────────────────────────────────────────────────────
  { route: 'music', modeId: 'music', label: 'Music', venueId: null, backendId: null, module: 'modes/music/MusicMode', status: 'live' },
  // Built in M75, never routed. This is the whole of the routing backlog for dance.
  { route: 'dance', modeId: 'dance', label: 'Dance', venueId: 'dance', backendId: null, module: 'modes/DanceMode', status: 'unrouted' },
  // ArtMode.tsx has existed since M28 and has never had a route.
  { route: 'art', modeId: 'art', label: 'Art', venueId: null, backendId: null, module: 'modes/art/ArtMode', status: 'unrouted' },

  // ── named everywhere, never built ───────────────────────────────────────
  // These appear in the backend mode manager and the Nexus venue registry, and
  // M73 even built venues for two of them. No mode module has ever existed, so
  // routing them would 500, not 404. `unbuilt` is the honest status.
  { route: 'acting', modeId: 'acting', label: 'Acting', venueId: null, backendId: null, module: null, status: 'unbuilt' },
  { route: 'irl', modeId: 'irl', label: 'IRL Dunk', venueId: 'basketball_irl', backendId: 'basketball_irl', module: null, status: 'unbuilt' },
  { route: 'brain_brawl', modeId: 'brain_brawl', label: 'Brain Brawl', venueId: 'brain_brawl', backendId: 'brain_brawl', module: null, status: 'unbuilt' },
  { route: 'who_scene_it', modeId: 'who_scene_it', label: 'Who Scene It', venueId: 'who_scene_it', backendId: 'who_scene_it', module: null, status: 'unbuilt' },
];

export const byRoute = (route: string): ModeEntry | undefined =>
  MODE_REGISTRY.find((m) => m.route === route);

export const playableModes = (): ModeEntry[] =>
  MODE_REGISTRY.filter((m) => m.status === 'live' || m.status === 'unrouted');

/** Routes the app should register. Excludes `unbuilt` — routing a mode with no
 *  module turns a clean 404 into a runtime error, which is strictly worse. */
export const routableModes = (): ModeEntry[] =>
  MODE_REGISTRY.filter((m) => m.module !== null);

/** Internal consistency, checked by tools/route_audit.mjs. */
export function registryProblems(): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  for (const m of MODE_REGISTRY) {
    if (m.route !== m.modeId) {
      out.push(`route "${m.route}" !== modeId "${m.modeId}" — this exact mismatch cost an audit cycle`);
    }
    if (seen.has(m.route)) out.push(`duplicate route "${m.route}"`);
    seen.add(m.route);
    if (m.status === 'unbuilt' && m.module) {
      out.push(`"${m.route}" is marked unbuilt but names a module`);
    }
    if (m.status !== 'unbuilt' && !m.module) {
      out.push(`"${m.route}" is marked ${m.status} but has no module`);
    }
  }
  return out;
}
