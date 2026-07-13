import { ModePhase } from './GameModeInterface.js';
import { DunkingMode } from './dunking/index.js';
import { KarateMode } from './karate/index.js';

const LIVE_MODE_IDS = new Set(['basketball_dunk', 'karate']);

function cloneStub(modeEntry, canvas) {
  return {
    ...modeEntry,
    canvas,
    phase: ModePhase.WARMUP,
  };
}

function instantiateMode(ModeCtor, modeId, canvas) {
  return new ModeCtor(modeId, canvas);
}

/**
 * Creates a stub mode contract for unimplemented FEL experiences.
 *
 * @param {string} modeId
 * @returns {{ modeId: string, canvas: HTMLCanvasElement|null, phase: string, start: () => Promise<object>, update: (inputEvent?: object) => object, getState: () => object, end: () => object, dispose: () => void, getModeId: () => string, getCanvas: () => HTMLCanvasElement|null }}
 */
function createStub(modeId) {
  return {
    modeId,
    canvas: null,
    phase: ModePhase.WARMUP,
    async start() {
      throw new Error(`Mode "${modeId}" is not yet implemented in v1. Stub only.`);
    },
    update() {
      return this.getState();
    },
    getState() {
      return {
        modeId: this.modeId,
        live: false,
        phase: this.phase,
      };
    },
    end() {
      this.phase = ModePhase.FINISHED;
      return this.getState();
    },
    dispose() {
      this.phase = ModePhase.FINISHED;
    },
    getModeId() {
      return this.modeId;
    },
    getCanvas() {
      return this.canvas;
    },
  };
}

// TODO: add new modes here as they graduate from stub to live implementation
const MODES = {
  basketball_h2h: createStub('basketball_h2h'),
  basketball_dunk: DunkingMode,
  basketball_3v3: createStub('basketball_3v3'),
  karate: KarateMode,
  karate_h2h: createStub('karate_h2h'),
  karate_endless: createStub('karate_endless'),
  baseball: createStub('baseball'),
  football: createStub('football'),
  soccer: createStub('soccer'),
  golf: createStub('golf'),
  tennis: createStub('tennis'),
  volleyball: createStub('volleyball'),
  gymnastics: createStub('gymnastics'),
  brain_brawl: createStub('brain_brawl'),
  surfing: createStub('surfing'),
  skateboarding: createStub('skateboarding'),
  snowboarding: createStub('snowboarding'),
  market_browse: createStub('market_browse'),
  trivia_arena: createStub('trivia_arena'),
};

/**
 * Central registry for all FEL game mode entries.
 *
 * @type {Readonly<Record<string, object|Function>>}
 */
export const ModeRegistry = Object.freeze(MODES);

/**
 * Creates a game mode instance for the supplied mode id.
 *
 * @param {string} modeId
 * @param {HTMLCanvasElement|null|undefined} canvas
 * @returns {object}
 */
export function getMode(modeId, canvas) {
  const modeEntry = ModeRegistry[modeId];

  if (!modeEntry) {
    throw new Error('Unknown mode: ' + modeId);
  }

  return isLive(modeId)
    ? instantiateMode(modeEntry, modeId, canvas)
    : cloneStub(modeEntry, canvas ?? null);
}

/**
 * Reports whether a mode id points at a live implementation.
 *
 * @param {string} modeId
 * @returns {boolean}
 */
export function isLive(modeId) {
  return LIVE_MODE_IDS.has(modeId);
}

/**
 * Lists every registered mode and whether it is live.
 *
 * @returns {Array<{ id: string, live: boolean }>}
 */
export function listModes() {
  return Object.keys(ModeRegistry).map((id) => ({
    id,
    live: isLive(id),
  }));
}
