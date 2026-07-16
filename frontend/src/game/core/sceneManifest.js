/**
 * Scene manifest + integrity gate (mode-agnostic).
 *
 * A map is a DATA FILE + assets, not bespoke code: the manifest declares
 * what a scene needs (required nodes, props, spawn points, camera rig,
 * archetype) and the integrity gate refuses to call a scene "playable"
 * until every required node is present AND visibly rendering — this is
 * what catches missing rims and floor-on-sky material failures.
 */

/**
 * @typedef {{ sceneId: string, mode: string, archetype: string,
 *   requiredNodes: string[], props?: { name: string, source: string }[],
 *   spawnPoints?: { name: string, x: number, y: number, z: number }[],
 *   cameraRig?: string, lighting?: string }} SceneManifest
 */

/** @type {SceneManifest} */
export const VENICE_COURT_MANIFEST = {
  sceneId: 'venice-court',
  mode: 'basketball_dunk',
  archetype: 'court-free-3d',
  requiredNodes: ['court', 'backboard', 'hoop', 'playerCapsule', 'veniceSky', 'veniceBlacktop'],
  props: [
    { name: 'veniceBlacktop', source: '/models/venice-blacktop.glb' }, // license NEEDS-VERIFY(elijah) — Meshy/Luma-derived
    { name: 'veniceSky', source: '/backdrops/venice-sky-sunset.jpg' }, // Elijah's own photo — license SAFE
  ],
  spawnPoints: [{ name: 'player', x: 0, y: 0, z: 4 }],
  cameraRig: 'gameplay',
  lighting: 'sunset',
};

/** @type {SceneManifest} */
export const DOJO_MANIFEST = {
  sceneId: 'zen-dojo',
  mode: 'karate',
  archetype: 'court-free-3d',
  // Torsos, not roots: fighter roots are intentionally-invisible 0.01u
  // containers — the gate must require what the EYE sees.
  requiredNodes: ['dojoFloor', 'playerTorso', 'opponentTorso', 'toriiBeam', 'dojoEnv'],
  props: [
    { name: 'dojoEnv', source: '/models/dojo.glb' }, // license NEEDS-VERIFY(elijah) — Meshy-derived
  ],
  spawnPoints: [{ name: 'player', x: -1.2, y: 0, z: 0 }],
  cameraRig: 'broadcast',
  lighting: 'candlelit',
};

/**
 * Validates a live Babylon scene against a manifest.
 * A node passes when it exists, is enabled, and (for meshes) is visible
 * with a ready material — catches "markings floating on sky".
 *
 * @param {import('@babylonjs/core').Scene} scene
 * @param {SceneManifest} manifest
 * @returns {{ ok: boolean, missing: string[], invisible: string[] }}
 */
export function validateSceneIntegrity(scene, manifest) {
  const missing = [];
  const invisible = [];
  for (const name of manifest.requiredNodes) {
    const node = scene.getMeshByName?.(name) ?? scene.getNodeByName?.(name);
    if (!node) { missing.push(name); continue; }
    const enabled = node.isEnabled?.() ?? true;
    const visible = node.isVisible !== false && (node.visibility === undefined || node.visibility > 0);
    const materialReady = node.material === undefined || node.material === null || node.material.isReady?.(node) !== false;
    if (!enabled || !visible || !materialReady) invisible.push(name);
  }
  return { ok: missing.length === 0 && invisible.length === 0, missing, invisible };
}

/** @type {SceneManifest} */
export const SOCCER_MANIFEST = {
  sceneId: 'soccer-penalty',
  mode: 'soccer',
  archetype: 'court-rally',
  requiredNodes: ['pitch', 'goalLeft', 'goalRight', 'soccerBall', 'goalkeeper'],
  props: [],
  spawnPoints: [
    { name: 'player', x: 0, y: 0, z: -13.2 },
    { name: 'ball', x: 0, y: 0.36, z: -15.5 },
  ],
  cameraRig: 'penalty',
  lighting: 'stadium',
};

/** @type {SceneManifest} */
export const SKATE_MANIFEST = {
  sceneId: 'venice-strip',
  mode: 'skateboarding',
  archetype: 'ride-carve',
  requiredNodes: ['strip', 'grindRail', 'playerCapsule', 'veniceSky'],
  props: [
    { name: 'veniceSky', source: '/backdrops/venice-sky-sunset.jpg' }, // Elijah's photo — SAFE
  ],
  spawnPoints: [{ name: 'player', x: 0, y: 0, z: 0 }],
  cameraRig: 'chase',
  lighting: 'sunset',
};

/**
 * Schedules integrity validation on a live scene: re-checks every rendered
 * frame from minFrame until it PASSES or times out — materials, shadow
 * effects, and streamed textures compile across the first frames, so a
 * one-shot early check reports false negatives. Only a timeout is a FAIL.
 *
 * @param {{ scene: object, engine: object, integrity?: object }} host —
 *   the scene wrapper; result is written to host.integrity
 * @param {SceneManifest} manifest
 * @param {{ minFrame?: number, timeoutFrames?: number }} [opts]
 */
export function scheduleIntegrityValidation(host, manifest, { minFrame = 5, timeoutFrames = 600 } = {}) {
  host.integrity = { ok: false, pending: true };
  const obs = host.scene.onAfterRenderObservable.add(() => {
    const f = host.engine.frameId;
    if (f < minFrame) return;
    const result = validateSceneIntegrity(host.scene, manifest);
    if (result.ok || f >= timeoutFrames) {
      host.scene.onAfterRenderObservable.remove(obs);
      host.integrity = result;
      if (!result.ok) {
        console.error(`[scene-integrity] ${manifest.sceneId} FAILED`, JSON.stringify(result));
      }
    }
  });
}

/**
 * Pure manifest sanity check (unit-testable without a scene): every
 * manifest must declare an id, a mode, at least one required node, and a
 * spawn point for its player when the archetype moves an avatar.
 */
export function validateManifestShape(manifest) {
  const problems = [];
  if (!manifest.sceneId) problems.push('sceneId missing');
  if (!manifest.mode) problems.push('mode missing');
  if (!manifest.requiredNodes?.length) problems.push('requiredNodes empty');
  if (manifest.archetype?.includes('court') && !manifest.spawnPoints?.some((s) => s.name === 'player')) {
    problems.push('court archetype requires a player spawn point');
  }
  return { ok: problems.length === 0, problems };
}
