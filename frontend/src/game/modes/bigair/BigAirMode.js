import AirSessionMode from '../airsession/AirSessionMode.js';
import { BIGAIR_MANIFEST } from '../../core/sceneManifest.js';

/** Big-Air — the slope builds your speed (negative drag), hit the kicker,
 *  △ spins mid-air, ✕ to stick it. feelConfig.bigair. */
export class BigAirMode extends AirSessionMode {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    super(
      typeof modeIdOrCanvas === 'string' ? modeIdOrCanvas : 'big_air',
      typeof modeIdOrCanvas === 'string' ? maybeCanvas : modeIdOrCanvas,
      container,
      {
        configKey: 'bigair',
        theme: {
          skyName: 'bigairSky', skyTexture: '/backdrops/venice-sky-day.jpg',
          runwayColor: '#E8EEF4', markerName: 'kicker', markerColor: '#5A6572',
          markerZ: -26, matName: 'landingMat', matColor: '#C9D8E4', matZ: -33,
          manifest: BIGAIR_MANIFEST,
        },
      }
    );
  }

  /** Carve: speed builds from the slope; taps not required. */
  _onRunTap() {}
}

export default BigAirMode;
