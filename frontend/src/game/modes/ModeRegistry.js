import { ModePhase } from './GameModeInterface.js';
import { DunkingMode } from './dunking/index.js';
import { GolfMode } from './golf/index.js';
import { KarateMode } from './karate/index.js';
import { SoccerMode } from './soccer/index.js';
import { TennisMode } from './tennis/index.js';
import { FootballMode } from './football/index.js';
import { VolleyballMode } from './volleyball/index.js';
import { BaseballMode } from './baseball/index.js';
import SkateMode from './skate/SkateMode.js';

// Modes graduate here when they are ROUTED and verified playable:
// dunk (feel gate passed) · karate (round gate + locomotion) ·
// soccer (court-rally) · skateboarding (ride/carve).
const LIVE_MODE_IDS = new Set([
  'basketball_dunk',
  'karate',
  'soccer',
  'skateboarding',
  'tennis',
  'golf',
  'volleyball',
  'baseball',
  'football',
]);

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
  baseball: BaseballMode,
  football: FootballMode,
  soccer: SoccerMode,
  golf: GolfMode,
  tennis: TennisMode,
  volleyball: VolleyballMode,
  gymnastics: createStub('gymnastics'),
  brain_brawl: createStub('brain_brawl'),
  surfing: createStub('surfing'),
  skateboarding: SkateMode,
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

  if (isLive(modeId)) {
    return instantiateMode(modeEntry, modeId, canvas);
  }

  // Gated modes: class entries get a fresh stub so callers see a uniform
  // not-yet-live contract instead of a half-spread constructor.
  const stubEntry = typeof modeEntry === 'function' ? createStub(modeId) : modeEntry;
  return cloneStub(stubEntry, canvas ?? null);
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
