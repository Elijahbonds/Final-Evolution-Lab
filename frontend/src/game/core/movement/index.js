import LocomotionCore from './LocomotionCore.js';
import JumpCore from './JumpCore.js';
import DodgeCore from './DodgeCore.js';
import StrikeCore from './StrikeCore.js';

/**
 * Creates the default FEL movement core bundle.
 * @param {{ locomotion?: object, jump?: object, dodge?: object, strike?: object }} [config]
 * @returns {{ locomotion: LocomotionCore, jump: JumpCore, dodge: DodgeCore, strike: StrikeCore }}
 */
export function MovementCoreFactory(config = {}) {
  return {
    locomotion: new LocomotionCore({
      maxSpeed: 7,
      acceleration: 30,
      friction: 18,
      ...(config.locomotion || {}),
    }),
    jump: new JumpCore({
      jumpForce: 8.5,
      gravity: 24,
      maxAirTime: 1.4,
      ...(config.jump || {}),
    }),
    dodge: new DodgeCore({
      dashSpeed: 14,
      dashDuration: 0.18,
      cooldown: 0.9,
      iFrameDuration: 0.12,
      ...(config.dodge || {}),
    }),
    strike: new StrikeCore({
      comboWindowMs: 400,
      maxComboLength: 4,
      strikeTypes: {
        light: {
          durationMs: 240,
          hitWindowStartMs: 50,
          hitWindowEndMs: 140,
          comboValue: 1,
        },
        heavy: {
          durationMs: 420,
          hitWindowStartMs: 110,
          hitWindowEndMs: 260,
          comboValue: 1.5,
        },
        special: {
          durationMs: 520,
          hitWindowStartMs: 140,
          hitWindowEndMs: 320,
          comboValue: 2,
        },
        ...(config.strike?.strikeTypes || {}),
      },
      ...config.strike,
    }),
  };
}

export { LocomotionCore, JumpCore, DodgeCore, StrikeCore };
