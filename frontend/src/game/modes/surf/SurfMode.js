import SkateMode from '../skate/SkateMode.js';
import { SURF_MANIFEST } from '../../core/sceneManifest.js';

/** Surf — ride/carve skin on the skate core (wide + flowing; the "rail" is
 *  the wave-lip trim line). All numbers feelConfig.surf TUNE(elijah). */
export class SurfMode extends SkateMode {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    super(
      typeof modeIdOrCanvas === 'string' ? modeIdOrCanvas : 'surfing',
      maybeCanvas, container,
      {
        configKey: 'surf',
        theme: {
          skyName: 'oceanSky', skyTexture: '/backdrops/venice-sky-day.jpg',
          stripColor: '#2E6E8E', railColor: '#EAF6FA', playerColor: '#F2C14E',
          manifest: SURF_MANIFEST,
        },
      }
    );
  }
}

export default SurfMode;
