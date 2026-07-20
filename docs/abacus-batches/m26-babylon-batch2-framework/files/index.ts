// M26 Batch 2 barrel — the shared game framework.
//
// WIRING: every Babylon mode = a ModeDefinition run through runMode():
//   const stop = await runMode(DunkMode, { canvas, onPhase, onHud });
// Characters ONLY via CharacterLibrary.spawn(). Balls ONLY via BallSim
// (sweptHit for anything fast vs thin). Coins via CoinField (server-capped).
// Mobs (defenders/karate/yeti) via Mob + MobPool with STEERING_PRESETS.
// Riders via Rider (ground snap + grind lines incl. the lift cable).

export { CharacterLibrary, type SpawnedCharacter, type SpawnOpts } from './core/CharacterLibrary';
export { runMode, type ModeDefinition, type ModeContext, type ModePhase } from './core/ModeHarness';
export { CameraDirector, FOLLOW_PRESETS } from './core/CameraDirector';
export { InputBus, type FelInput } from './core/InputBus';
export { BallSim, arcVelocity } from './core/BallPhysics';
export { CoinField, COIN_RUN_CAP } from './core/Pickups';
export { Mob, MobPool, STEERING_PRESETS, type SteeringConfig } from './core/MobSteering';
export { Rider, type GrindLine } from './core/GroundRide';
export { buildResult, defaultResultSink, type SessionResult } from './core/sessionResult';
