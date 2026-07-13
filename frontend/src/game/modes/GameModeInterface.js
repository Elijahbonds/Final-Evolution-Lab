/**
 * Named lifecycle phases shared by FEL game modes.
 *
 * @readonly
 * @enum {string}
 */
export const ModePhase = {
  WARMUP: 'warmup',
  ACTIVE: 'active',
  FINISHED: 'finished',
};

/**
 * GameModeInterface — abstract base for all FEL game mode skins.
 * Extend this class, do NOT instantiate directly.
 */
export class GameModeInterface {
  /**
   * @param {string} modeId
   * @param {HTMLCanvasElement|null|undefined} canvas
   */
  constructor(modeId, canvas) {
    if (new.target === GameModeInterface) {
      throw new Error('GameModeInterface is abstract — extend it instead of instantiating directly.');
    }

    this.modeId = modeId;
    this.canvas = canvas;
  }

  /**
   * @returns {Promise<object>}
   */
  async start() {
    throw new Error('start() must be implemented');
  }

  /**
   * @param {object} inputEvent
   * @returns {object}
   */
  update(inputEvent) {
    throw new Error('update() must be implemented');
  }

  /**
   * @returns {object}
   */
  getState() {
    throw new Error('getState() must be implemented');
  }

  /**
   * @returns {object}
   */
  end() {
    throw new Error('end() must be implemented');
  }

  /**
   * @returns {void}
   */
  dispose() {
    throw new Error('dispose() must be implemented');
  }

  /**
   * @returns {string}
   */
  getModeId() {
    return this.modeId;
  }

  /**
   * @returns {HTMLCanvasElement|null|undefined}
   */
  getCanvas() {
    return this.canvas;
  }
}
