// M27 Batch 3 barrel — every Babylon mode, route-ready.
//
// ROUTING (flip one at a time, dunk first — the proof gate):
//   import { runMode } from '../core-framework';        // M26 barrel
//   import { MODES } from './modes-batch';               // this barrel
//   const stop = await runMode(MODES.dunk, { canvas, onPhase, onHud });

import type { ModeDefinition } from '../../m26-babylon-batch2-framework/files/core/ModeHarness';
import { DunkMode } from './modes/DunkMode';
import { KarateEndlessMode } from './modes/KarateEndlessMode';
import { FootballMode } from './modes/FootballMode';
import { makeBoardMode } from './modes/BoardRunMode';
import { makeTimingSportMode } from './modes/TimingSportMode';
import {
  SKATE_CONFIG, SNOWBOARD_CONFIG, SURF_CONFIG,
  TENNIS_CONFIG, DERBY_CONFIG, PENALTY_CONFIG, GOLF_CONFIG,
} from './modes/modeConfigs';

export const MODES: Record<string, ModeDefinition> = {
  // P3–P4 proof mode — ship and playtest FIRST
  dunk: DunkMode,
  // Rollout wave 1 (after dunk passes)
  karate: KarateEndlessMode,
  football: FootballMode,
  // Rollout wave 2 — board family (skate first, then snow w/ lift+yeti, surf)
  skateboard: makeBoardMode(SKATE_CONFIG),
  snowboard_slalom: makeBoardMode(SNOWBOARD_CONFIG),
  surf: makeBoardMode(SURF_CONFIG),
  // Rollout wave 3 — timing family
  tennis: makeTimingSportMode(TENNIS_CONFIG),
  derby: makeTimingSportMode(DERBY_CONFIG),
  penalty: makeTimingSportMode(PENALTY_CONFIG),
  golf: makeTimingSportMode(GOLF_CONFIG),
};

// Remaining modes map onto these same cores in the next batch:
//  · 1v1 / 3v3  → court core (DunkMode's movement + BallSim + Mob defenders)
//  · karate versus → KarateEndlessMode with a single sensei Mob + rounds
//  · big air / tiebreak / sprint → Board/TimingSport configs
//  · brain brawl / who scene it → UI modes (no 3D core needed)
