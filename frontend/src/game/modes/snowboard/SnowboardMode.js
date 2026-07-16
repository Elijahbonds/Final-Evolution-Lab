import SkateMode from '../skate/SkateMode.js';
import { SNOWBOARD_MANIFEST } from '../../core/sceneManifest.js';

/** Snowboard — ride/carve skin on the skate core (steeper + faster; the
 *  "rail" is a rock ledge). All numbers feelConfig.snowboard TUNE(elijah). */
export class SnowboardMode extends SkateMode {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    super(
      typeof modeIdOrCanvas === 'string' ? modeIdOrCanvas : 'snowboarding',
      maybeCanvas, container,
      {
        configKey: 'snowboard',
        theme: {
          skyName: 'alpineSky', skyTexture: '/backdrops/venice-sky-day.jpg',
          stripColor: '#E8EEF4', railColor: '#8A8F98', playerColor: '#D0552E',
          manifest: SNOWBOARD_MANIFEST,
        },
      }
    );
  }
}

export default SnowboardMode;
