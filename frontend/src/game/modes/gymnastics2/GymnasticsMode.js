import AirSessionMode from '../airsession/AirSessionMode.js';
import { GYMNASTICS_MANIFEST } from '../../core/sceneManifest.js';

/** Gymnastics vault — cadence run-up (□/○ alternate), auto-punch at the
 *  table, △ flips mid-air, ✕ to stick the landing. feelConfig.gymnastics. */
export class GymnasticsMode extends AirSessionMode {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    super(
      typeof modeIdOrCanvas === 'string' ? modeIdOrCanvas : 'gymnastics',
      typeof modeIdOrCanvas === 'string' ? maybeCanvas : modeIdOrCanvas,
      container,
      {
        configKey: 'gymnastics',
        theme: {
          skyName: 'gymSky', skyTexture: '/backdrops/venice-sky-day.jpg',
          runwayColor: '#27526B', markerName: 'vaultTable', markerColor: '#B03A48',
          markerZ: -22, matName: 'landingMat', matColor: '#2F6EA8', matZ: -28,
          manifest: GYMNASTICS_MANIFEST,
        },
      }
    );
  }
}

export default GymnasticsMode;
