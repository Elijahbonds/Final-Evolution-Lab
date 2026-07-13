/**
 * InputSystem — normalised gamepad input mapper for all FEL game modes.
 *
 * Translates raw PS2GamepadOverlay events (face buttons, D-pad, sticks,
 * shoulder/trigger) into mode-specific GameModeInterface inputEvent objects.
 *
 * iOS parity: mirrors InputManager.swift deadzone helpers + per-mode
 * button-to-action mappings from GamePlayView.swift.
 *
 * Usage:
 *   const input = new InputSystem('basketball_dunk');
 *   input.onEvent = (inputEvent) => mode.update(inputEvent);
 *   // in render: <GamepadOverlay onFaceButton={input.onFaceButton} ... />
 */

// ---------------------------------------------------------------------------
// Deadzone helpers (mirrors iOS InputManager.applyDeadzone)
// ---------------------------------------------------------------------------
const DEADZONE_INNER = 0.06;

function applyDeadzone(value, inner = DEADZONE_INNER) {
  const v = Math.max(0, Math.min(1, Math.abs(value)));
  if (v <= inner) return 0;
  const sign = value < 0 ? -1 : 1;
  return sign * (v - inner) / (1 - inner);
}

function applyStickDeadzone(x, y, inner = DEADZONE_INNER) {
  const mag = Math.sqrt(x * x + y * y);
  if (mag <= inner) return { x: 0, y: 0, magnitude: 0 };
  const rescale = (mag - inner) / (1 - inner);
  const scale = rescale / mag;
  return { x: x * scale, y: y * scale, magnitude: Math.min(1, rescale) };
}

// ---------------------------------------------------------------------------
// Per-mode button → action mappings
// Mirrors iOS GamePlayView face-button switch statements
// ---------------------------------------------------------------------------

/**
 * Returns the action name for a face button press in a given mode.
 *
 * @param {string} modeId
 * @param {'triangle'|'square'|'circle'|'cross'} button
 * @returns {{ type: string, payload: object }|null}
 */
function faceButtonAction(modeId, button) {
  switch (modeId) {

    // ── Dunk Contest ────────────────────────────────────────────────────────
    // iOS: square=Windmill, triangle=Contortion, circle=Power, cross=Technical
    // iOS DunkModifier: .flashy, .power, .signature, .standard
    case 'basketball_dunk':
    case 'basketball_dunk_3d':
      return {
        triangle: { type: 'dunk', payload: { variant: 'contortion',  modifier: 'flashy'    } },
        square:   { type: 'dunk', payload: { variant: 'windmill',    modifier: 'signature' } },
        circle:   { type: 'dunk', payload: { variant: 'power',       modifier: 'power'     } },
        cross:    { type: 'jump', payload: { variant: 'technical'                           } },
      }[button] ?? null;

    // ── Karate / Karate Endless ──────────────────────────────────────────────
    // iOS: light_strike=square, heavy_strike=triangle, special=circle, dodge=cross
    case 'karate':
    case 'karate_endless':
    case 'karate_h2h':
      return {
        square:   { type: 'strike', payload: { variant: 'light'   } },
        triangle: { type: 'strike', payload: { variant: 'heavy'   } },
        circle:   { type: 'strike', payload: { variant: 'special' } },
        cross:    { type: 'dodge',  payload: {}                      },
      }[button] ?? null;

    // ── Soccer ───────────────────────────────────────────────────────────────
    // circle=shoot, square=pass, triangle=chip/special, cross=sprint
    case 'soccer':
      return {
        circle:   { type: 'shoot',   payload: {} },
        square:   { type: 'pass',    payload: {} },
        triangle: { type: 'chip',    payload: {} },
        cross:    { type: 'sprint',  payload: {} },
      }[button] ?? null;

    // ── Tennis ───────────────────────────────────────────────────────────────
    // cross=forehand, circle=backhand, square=lob, triangle=slice
    case 'tennis':
      return {
        cross:    { type: 'swing', payload: { shot_type: 'forehand'  } },
        circle:   { type: 'swing', payload: { shot_type: 'backhand'  } },
        square:   { type: 'swing', payload: { shot_type: 'lob'       } },
        triangle: { type: 'swing', payload: { shot_type: 'slice'     } },
      }[button] ?? null;

    // ── Football ─────────────────────────────────────────────────────────────
    // cross=dive, circle=spin, square=stiff_arm, triangle=hurdle
    case 'football':
      return {
        cross:    { type: 'move',   payload: { play_type: 'dive'      } },
        circle:   { type: 'move',   payload: { play_type: 'spin'      } },
        square:   { type: 'move',   payload: { play_type: 'stiff_arm' } },
        triangle: { type: 'move',   payload: { play_type: 'hurdle'    } },
      }[button] ?? null;

    // ── Volleyball ────────────────────────────────────────────────────────────
    // cross=jump/spike, circle=set, square=dig, triangle=serve
    case 'volleyball':
      return {
        cross:    { type: 'action', payload: { rally_type: 'spike'     } },
        circle:   { type: 'action', payload: { rally_type: 'set'       } },
        square:   { type: 'action', payload: { rally_type: 'dig'       } },
        triangle: { type: 'action', payload: { rally_type: 'serve'     } },
      }[button] ?? null;

    // ── Baseball ─────────────────────────────────────────────────────────────
    // cross=swing (timing), square=bunt, triangle=check, circle=steal
    case 'baseball':
      return {
        cross:    { type: 'swing', payload: { play_type: 'full_swing'   } },
        square:   { type: 'swing', payload: { play_type: 'bunt'         } },
        triangle: { type: 'swing', payload: { play_type: 'check_swing'  } },
        circle:   { type: 'run',   payload: { play_type: 'steal'        } },
      }[button] ?? null;

    // ── Golf ──────────────────────────────────────────────────────────────────
    // cross=swing (charge release), square=chip, triangle=putt, circle=aim_toggle
    case 'golf':
      return {
        cross:    { type: 'swing',  payload: { club: 'driver'  } },
        square:   { type: 'swing',  payload: { club: 'wedge'   } },
        triangle: { type: 'swing',  payload: { club: 'putt'    } },
        circle:   { type: 'aim',    payload: {}                  },
      }[button] ?? null;

    // ── Skateboarding ─────────────────────────────────────────────────────────
    // cross=kickflip, square=heelflip, triangle=360flip, circle=grind
    case 'skateboarding':
      return {
        cross:    { type: 'trick', payload: { trick: 'kickflip'  } },
        square:   { type: 'trick', payload: { trick: 'heelflip'  } },
        triangle: { type: 'trick', payload: { trick: '360flip'   } },
        circle:   { type: 'trick', payload: { trick: 'grind'     } },
      }[button] ?? null;

    // ── Snowboarding ───────────────────────────────────────────────────────────
    // cross=jump, circle=butter, square=wipeout_recovery, triangle=360
    case 'snowboarding':
      return {
        cross:    { type: 'jump',      payload: {} },
        circle:   { type: 'butter',    payload: {} },
        square:   { type: 'carve',     payload: { direction: 'left'  } },
        triangle: { type: 'carve',     payload: { direction: 'right' } },
      }[button] ?? null;

    // ── Gymnastics ─────────────────────────────────────────────────────────────
    // cross=tap (timing), others = direction taps
    case 'gymnastics':
      return {
        cross:    { type: 'tap', payload: { direction: 'center' } },
        triangle: { type: 'tap', payload: { direction: 'up'     } },
        square:   { type: 'tap', payload: { direction: 'left'   } },
        circle:   { type: 'tap', payload: { direction: 'right'  } },
      }[button] ?? null;

    // ── Brain Brawl ────────────────────────────────────────────────────────────
    // Each button = answer choice A/B/C/D
    case 'brain_brawl':
    case 'trivia_arena':
      return {
        cross:    { type: 'answer', payload: { choice: 'A' } },
        square:   { type: 'answer', payload: { choice: 'B' } },
        triangle: { type: 'answer', payload: { choice: 'C' } },
        circle:   { type: 'answer', payload: { choice: 'D' } },
      }[button] ?? null;

    default:
      return { type: button, payload: {} };
  }
}

/**
 * Returns the action for a D-pad press.
 *
 * @param {string} modeId
 * @param {'up'|'down'|'left'|'right'} direction
 * @returns {{ type: string, payload: object }|null}
 */
function dpadAction(modeId, direction) {
  switch (modeId) {
    case 'basketball_dunk':
    case 'basketball_dunk_3d':
      return { type: 'run', payload: { direction } };
    case 'karate':
    case 'karate_endless':
      return direction === 'up'
        ? { type: 'dodge', payload: { direction: 'forward' } }
        : direction === 'down'
        ? { type: 'block', payload: {} }
        : { type: 'dodge', payload: { direction } };
    case 'soccer':
    case 'football':
    case 'volleyball':
      return { type: 'move', payload: { direction } };
    case 'golf':
      return { type: 'aim', payload: { direction, delta: 5 } };
    case 'baseball':
      return { type: 'aim', payload: { direction } };
    default:
      return { type: 'dpad', payload: { direction } };
  }
}

/**
 * Returns the action for a shoulder/trigger event.
 *
 * @param {string} modeId
 * @param {'L1'|'R1'|'L2'|'R2'} id
 * @param {number} value  0–1 (L1/R1 are 0 or 1; L2/R2 are analog 0–1)
 * @returns {{ type: string, payload: object }|null}
 */
function shoulderAction(modeId, id, value) {
  switch (modeId) {
    case 'basketball_dunk':
    case 'basketball_dunk_3d':
      if (id === 'L2') return { type: 'charge', payload: { depth: value, trigger: 'style'  } };
      if (id === 'R2') return { type: 'charge', payload: { depth: value, trigger: 'power'  } };
      if (id === 'L1') return { type: 'dodge',  payload: { direction: 'left'               } };
      if (id === 'R1') return { type: 'dodge',  payload: { direction: 'right'              } };
      break;
    case 'karate':
    case 'karate_endless':
    case 'karate_h2h':
      if (id === 'L1') return { type: 'block',   payload: { incomingDamage: 0 } };
      if (id === 'R1') return { type: 'strike',  payload: { variant: 'counter' } };
      if (id === 'L2') return { type: 'dodge',   payload: { direction: 'back'  } };
      if (id === 'R2') return { type: 'strike',  payload: { variant: 'special', charged: value } };
      break;
    case 'soccer':
      if (id === 'L1') return { type: 'sprint',  payload: { active: value > 0.5 } };
      if (id === 'R1') return { type: 'tackle',  payload: {} };
      if (id === 'R2') return { type: 'shoot',   payload: { power: value, shot_type: 'penalty' } };
      break;
    case 'tennis':
      if (id === 'L1') return { type: 'serve',   payload: {} };
      if (id === 'R2') return { type: 'power',   payload: { depth: value } };
      break;
    case 'golf':
      if (id === 'R2') return { type: 'charge',  payload: { depth: value } };
      if (id === 'L2') return { type: 'release', payload: { power: value } };
      break;
    case 'volleyball':
      if (id === 'R2') return { type: 'action',  payload: { rally_type: 'ace_serve', power: value } };
      if (id === 'L1') return { type: 'action',  payload: { rally_type: 'block_jump' } };
      break;
    case 'baseball':
      if (id === 'R2') return { type: 'pitch',   payload: { pitch_type: 'fastball', power: value } };
      if (id === 'L2') return { type: 'pitch',   payload: { pitch_type: 'curveball', power: value } };
      break;
    default:
      break;
  }
  return { type: id.toLowerCase(), payload: { value } };
}

// ---------------------------------------------------------------------------
// InputSystem class
// ---------------------------------------------------------------------------

/**
 * Manages virtual gamepad input and translates it into mode-aware InputEvents.
 *
 * Designed to bridge the React GamepadOverlay component to any mode
 * that implements GameModeInterface.update(inputEvent).
 */
export class InputSystem {
  /**
   * @param {string} modeId  — The active arena mode id (e.g. 'basketball_dunk')
   */
  constructor(modeId = '') {
    this.modeId = modeId;

    /** @type {(inputEvent: {type: string, payload: object}) => void} */
    this.onEvent = () => {};

    // Current stick state — updated continuously
    this.leftStick  = { x: 0, y: 0, magnitude: 0 };
    this.rightStick = { x: 0, y: 0, magnitude: 0 };

    // Trigger state (0–1)
    this.l2 = 0;
    this.r2 = 0;

    // Shoulder state
    this.l1 = 0;
    this.r1 = 0;

    // Bind callbacks for GamepadOverlay props
    this.onFaceButton  = this._onFaceButton.bind(this);
    this.onDPad        = this._onDPad.bind(this);
    this.onLeftStick   = this._onLeftStick.bind(this);
    this.onRightStick  = this._onRightStick.bind(this);
    this.onShoulder    = this._onShoulder.bind(this);
    this.onTrigger     = this._onTrigger.bind(this);
  }

  /**
   * Change the active mode id (clears stick state).
   * @param {string} modeId
   */
  setModeId(modeId) {
    this.modeId = modeId;
    this.leftStick  = { x: 0, y: 0, magnitude: 0 };
    this.rightStick = { x: 0, y: 0, magnitude: 0 };
    this.l2 = 0;
    this.r2 = 0;
    this.l1 = 0;
    this.r1 = 0;
  }

  // ── Internal handlers ──────────────────────────────────────────────────────

  _onFaceButton(button) {
    const action = faceButtonAction(this.modeId, button);
    if (action) this.onEvent(action);
  }

  _onDPad(direction) {
    const action = dpadAction(this.modeId, direction);
    if (action) this.onEvent(action);
  }

  _onLeftStick(vec) {
    const deadzone = applyStickDeadzone(vec.x, vec.y);
    this.leftStick = deadzone;

    // Emit movement event when stick has magnitude
    if (deadzone.magnitude > 0.05) {
      this.onEvent({
        type: 'move',
        payload: {
          leftStick:  { x: deadzone.x, y: deadzone.y },
          magnitude:  deadzone.magnitude,
          direction:  this._vec2Direction(deadzone.x, deadzone.y),
        },
      });
    }
  }

  _onRightStick(vec) {
    const deadzone = applyStickDeadzone(vec.x, vec.y);
    this.rightStick = deadzone;

    if (deadzone.magnitude > 0.05) {
      this.onEvent({
        type: 'aim',
        payload: {
          rightStick: { x: deadzone.x, y: deadzone.y },
          magnitude:  deadzone.magnitude,
        },
      });
    }
  }

  _onShoulder(id, value) {
    if (id === 'L1') this.l1 = value;
    if (id === 'R1') this.r1 = value;
    const action = shoulderAction(this.modeId, id, value);
    if (action) this.onEvent(action);
  }

  _onTrigger(id, depth) {
    const d = applyDeadzone(depth, 0.04);
    if (id === 'L2') this.l2 = d;
    if (id === 'R2') this.r2 = d;
    const action = shoulderAction(this.modeId, id, d);
    if (action) this.onEvent(action);
  }

  /**
   * Convert normalised stick vector to cardinal direction string.
   * @private
   */
  _vec2Direction(x, y) {
    if (Math.abs(x) < 0.3 && Math.abs(y) < 0.3) return 'neutral';
    const angle = Math.atan2(y, x) * (180 / Math.PI);
    if (angle > 45  && angle <= 135)  return 'up';
    if (angle <= -45 && angle > -135) return 'down';
    if (angle >= 135 || angle < -135) return 'left';
    return 'right';
  }

  /**
   * Returns current stick/trigger state snapshot (useful for polling in render loops).
   */
  getState() {
    return {
      leftStick:  { ...this.leftStick },
      rightStick: { ...this.rightStick },
      l1: this.l1, r1: this.r1,
      l2: this.l2, r2: this.r2,
    };
  }

  /**
   * Returns props object ready to spread onto <GamepadOverlay />.
   */
  getGamepadProps() {
    return {
      onFaceButton:  this.onFaceButton,
      onDPad:        this.onDPad,
      onLeftStick:   this.onLeftStick,
      onRightStick:  this.onRightStick,
      onShoulder:    this.onShoulder,
      onTrigger:     this.onTrigger,
      l2Depth:       this.l2,
      r2Depth:       this.r2,
    };
  }
}

export default InputSystem;
