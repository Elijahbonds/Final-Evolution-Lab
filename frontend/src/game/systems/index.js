import { AnalyticsSystem } from './AnalyticsSystem.js';
import { ComboSystem } from './ComboSystem.js';
import { HUDStateSystem } from './HUDStateSystem.js';
import { OfflineCacheSystem } from './OfflineCacheSystem.js';
import { PRQSystem } from './PRQSystem.js';
import { ScoreSystem } from './ScoreSystem.js';
import { SkillLabSystem } from './SkillLabSystem.js';
import { WearableSystem } from './WearableSystem.js';

/**
 * Creates a shared set of framework-agnostic gameplay systems.
 *
 * @returns {{
 *   analytics: AnalyticsSystem,
 *   combo: ComboSystem,
 *   hudState: HUDStateSystem,
 *   offlineCache: OfflineCacheSystem,
 *   prq: PRQSystem,
 *   score: ScoreSystem,
 *   skillLab: SkillLabSystem,
 *   wearable: WearableSystem
 * }}
 */
export function createSharedSystems() {
  return {
    analytics: new AnalyticsSystem(),
    combo: new ComboSystem(),
    hudState: new HUDStateSystem(),
    offlineCache: new OfflineCacheSystem('fel-game'),
    prq: new PRQSystem(),
    score: new ScoreSystem(),
    skillLab: new SkillLabSystem(),
    wearable: new WearableSystem(),
  };
}

export {
  AnalyticsSystem,
  ComboSystem,
  HUDStateSystem,
  OfflineCacheSystem,
  PRQSystem,
  ScoreSystem,
  SkillLabSystem,
  WearableSystem,
};
