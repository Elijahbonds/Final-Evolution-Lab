import { AnalyticsSystem } from './AnalyticsSystem.js';
import { AudioSystem } from './AudioSystem.js';
import { ComboSystem } from './ComboSystem.js';
import { HUDStateSystem } from './HUDStateSystem.js';
import { OfflineCacheSystem } from './OfflineCacheSystem.js';
import { PRQSystem } from './PRQSystem.js';
import { ScoreSystem } from './ScoreSystem.js';
import { SkillLabSystem } from './SkillLabSystem.js';
import { VFXSystem } from './VFXSystem.js';
import { WearableSystem } from './WearableSystem.js';

/**
 * Creates a shared set of framework-agnostic gameplay systems.
 *
 * @param {HTMLElement|null} [container]  — game container el for VFXSystem
 * @returns {{
 *   analytics: AnalyticsSystem,
 *   audio: AudioSystem,
 *   combo: ComboSystem,
 *   hudState: HUDStateSystem,
 *   offlineCache: OfflineCacheSystem,
 *   prq: PRQSystem,
 *   score: ScoreSystem,
 *   skillLab: SkillLabSystem,
 *   vfx: VFXSystem,
 *   wearable: WearableSystem
 * }}
 */
export function createSharedSystems(container = null) {
  return {
    analytics:    new AnalyticsSystem(),
    audio:        new AudioSystem(),
    combo:        new ComboSystem(),
    hudState:     new HUDStateSystem(),
    offlineCache: new OfflineCacheSystem('fel-game'),
    prq:          new PRQSystem(),
    score:        new ScoreSystem(),
    skillLab:     new SkillLabSystem(),
    vfx:          new VFXSystem(container),
    wearable:     new WearableSystem(),
  };
}

export {
  AnalyticsSystem,
  AudioSystem,
  ComboSystem,
  HUDStateSystem,
  OfflineCacheSystem,
  PRQSystem,
  ScoreSystem,
  SkillLabSystem,
  VFXSystem,
  WearableSystem,
};
