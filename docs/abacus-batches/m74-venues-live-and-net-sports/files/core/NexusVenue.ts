// NexusVenue — the one call that puts an M73 venue into a live mode.
//
// M73 built and rendered 20 venues; they were not wired into anything. This
// is the wiring, and it exists as a helper rather than six copy-pasted blocks
// because every one of the integration details below is easy to omit and
// invisible when omitted:
//
//   1. The camera must know the venue's BOUNDS, or it walks out of the world.
//      M64 added CameraDirector.setBounds() precisely for this; a venue that
//      never calls it silently reverts to the pre-M64 behaviour.
//   2. The placeholder actors must go when real characters spawn, or you get
//      two bodies per player — one capsule, one avatar, in the same spot.
//   3. Disposal must be complete. A mode switch that leaves a sky dome behind
//      shows the previous venue's sky over the new one, and it looks like a
//      grading bug rather than a leak.
//
// Everything is under one root, so dispose() is total.

import type { Scene, TransformNode } from '@babylonjs/core';
import { buildNexusScene, type BuiltScene } from '../nexus/NexusWebScene';
import { specFor } from '../nexus/venueSpecs';

export interface VenueHandle {
  built: BuiltScene;
  /** Placeholder bodies, kept so a mode can drop them the moment real
   *  characters are ready. */
  placeholders: TransformNode[];
  /** Hide the stand-ins. Call right after CharacterLibrary.spawn() resolves. */
  hidePlaceholders(): void;
  dispose(): void;
}

/** Minimal shape we need from the mode context — declared structurally so this
 *  file does not have to import ModeHarness and create a cycle. */
interface VenueCtx {
  scene: Scene;
  canvas?: HTMLCanvasElement;
  camera?: {
    setBounds?(b: { minX: number; maxX: number; minZ: number; maxZ: number; minY: number }): void;
    invalidateBounds?(): void;
  };
}

/**
 * Build the venue for `modeId` and wire it to the camera.
 *
 * Returns null when no spec exists — deliberately not a throw. A mode with no
 * venue should still be playable on whatever VenueKit already builds; losing
 * the scenery is a downgrade, losing the mode is an outage.
 */
export function mountVenue(ctx: VenueCtx, modeId: string): VenueHandle | null {
  const spec = specFor(modeId);
  if (!spec) {
    console.warn(`[NEXUS] no venue spec for "${modeId}" — falling back to VenueKit. `
      + 'Add one to venueSpecs.ts to give this mode its own venue.');
    return null;
  }

  const built = buildNexusScene(ctx.scene, spec, ctx.canvas);

  // Hand the camera the venue footprint. Without this the M64 bounds clamp has
  // nothing to clamp against and the camera can leave the venue entirely — the
  // full-court 3v3 case that produced E26.
  const [w, d] = spec.ground.size;
  ctx.camera?.setBounds?.({
    minX: -w / 2, maxX: w / 2,
    minZ: -d / 2, maxZ: d / 2,
    minY: 0,
  });

  const placeholders = built.actors;

  return {
    built,
    placeholders,
    hidePlaceholders() {
      for (const a of placeholders) {
        a.getChildMeshes().forEach((m) => { m.isVisible = false; });
      }
    },
    dispose() {
      ctx.camera?.invalidateBounds?.();
      built.dispose();
    },
  };
}

// ── WIRING, per mode ──────────────────────────────────────────────────────
//
// In a ModeDefinition.load(ctx), REPLACING the VenueKit.buildCourt(...) call:
//
//   import { mountVenue } from '../core/NexusVenue';
//   let venue: VenueHandle | null = null;
//   …
//   venue = mountVenue(ctx, 'basketball_h2h');
//   …spawn characters as usual…
//   venue?.hidePlaceholders();
//
// and in dispose():
//
//   venue?.dispose(); venue = null;
//
// MODE ID MAPPING — the web routes and the Nexus mode ids are not the same
// strings, and guessing wrong yields a silent VenueKit fallback:
//
//   route /play/dunk        → 'basketball_dunk'
//   route /play/onevone     → 'basketball_h2h'
//   route /play/threevthree → 'basketball_3v3'
//   route /play/karate      → 'karate_endless'
//   route /play/carnival    → 'court_carnival'
export const ROUTE_TO_VENUE: Record<string, string> = {
  dunk: 'basketball_dunk',
  onevone: 'basketball_h2h',
  threevthree: 'basketball_3v3',
  karate: 'karate_endless',
  carnival: 'court_carnival',
  tennis: 'tennis',
  volleyball: 'volleyball',
};
