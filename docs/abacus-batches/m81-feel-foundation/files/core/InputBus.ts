// InputBus v3 — REPLACES the M26 version.
//
// Same event shape, same `on()`/`emit()` API, so nothing downstream changes.
// What changes is everything that was wrong underneath:
//
//   · KEYS STUCK ON BLUR. `held` was only ever cleared by a matching keyup.
//     Alt-tab, switch apps, or take a notification while holding W and that
//     keyup never arrives — the character runs forever. On mobile this fires
//     constantly. v3 flushes on blur and visibilitychange.
//   · THE PAGE SCROLLED UNDER THE GAME. No preventDefault on arrows or space.
//   · SPACE WAS TWO THINGS AT ONCE. On release it emitted a trigger-zero AND a
//     button-A press, so no mode could tell "I finished charging" from "I
//     tapped jump". v3 disambiguates by duration, which is what console games
//     do: a short press is a tap, a long one is a charge release.
//   · THE GAMEPAD DEADZONE WAS A CLIFF. `|v| < 0.15 ? 0 : v` gives nothing at
//     0.149 and 0.151 at 0.151. v3 rescales so motion grows from zero.
//   · THE GAMEPAD FLOODED THE BUS. Four stick/trigger events every animation
//     frame whether or not anything moved — 240 events/sec into every
//     listener. v3 emits on change.
//
// New, and deliberately here rather than in a settings screen: REMAPPING and
// HOLD-TO-TOGGLE. Both are accessibility requirements, and both are one line
// each at this layer versus twenty-five mode-by-mode retrofits later.

import { applyDeadzone } from './MotionModel';
import {
  DEFAULT_BINDINGS, DPAD_KEYS, MOVE_KEYS, CHARGE_FULL_MS,
  classifyRelease, stickFromKeys, isGameKey, shouldPreventDefault,
  type FelButton, type FelInput,
} from './inputCore';

// Re-exported so existing imports of `FelInput` from './InputBus' keep working.
export {
  DEFAULT_BINDINGS, TAP_MAX_MS, CHARGE_FULL_MS, classifyRelease, stickFromKeys,
} from './inputCore';
export type { FelButton, FelInput, ReleaseKind } from './inputCore';

type Listener = (e: FelInput) => void;

export interface InputOptions {
  /** Stop the browser scrolling/tabbing while playing. Default true. */
  captureKeys?: boolean;
  /** Accessibility: a hold becomes press-once-to-start, press-again-to-release. */
  holdToToggle?: boolean;
  /** Override the key→button table. */
  bindings?: Record<string, FelButton>;
}

export class InputBus {
  private listeners = new Set<Listener>();
  private held = new Set<string>();
  private padIndex: number | null = null;
  private raf = 0;
  private triggerDownAt = 0;
  private toggleLatched = false;
  private bindings: Record<string, FelButton>;
  private opts: Required<Omit<InputOptions, 'bindings'>>;
  /** Last emitted analog values, so we only speak when something changed. */
  private lastAnalog = new Map<string, string>();

  public gamepadActive = false;

  constructor(options: InputOptions = {}) {
    this.bindings = { ...DEFAULT_BINDINGS, ...(options.bindings ?? {}) };
    this.opts = {
      captureKeys: options.captureKeys ?? true,
      holdToToggle: options.holdToToggle ?? false,
    };
  }

  /** Rebind at runtime. Accessibility requirement; also just good. */
  setBinding(key: string, btn: FelButton): void { this.bindings[key.toLowerCase()] = btn; }
  setHoldToToggle(on: boolean): void { this.opts.holdToToggle = on; }

  start(): void {
    window.addEventListener('keydown', this.onKey);
    window.addEventListener('keyup', this.onKey);
    window.addEventListener('blur', this.flush);
    document.addEventListener('visibilitychange', this.onVisibility);
    window.addEventListener('gamepadconnected', this.onPad);
    window.addEventListener('gamepaddisconnected', this.onPadOff);
    this.pollPads();
  }

  stop(): void {
    window.removeEventListener('keydown', this.onKey);
    window.removeEventListener('keyup', this.onKey);
    window.removeEventListener('blur', this.flush);
    document.removeEventListener('visibilitychange', this.onVisibility);
    window.removeEventListener('gamepadconnected', this.onPad);
    window.removeEventListener('gamepaddisconnected', this.onPadOff);
    cancelAnimationFrame(this.raf);
    this.raf = 0;
    this.flush();
    this.listeners.clear();
  }

  on(fn: Listener): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  emit(e: FelInput): void {
    for (const fn of this.listeners) fn(e);
  }

  /** Emit only if this analog channel actually moved. */
  private emitAnalog(key: string, e: FelInput): void {
    const sig = JSON.stringify(e);
    if (this.lastAnalog.get(key) === sig) return;
    this.lastAnalog.set(key, sig);
    this.emit(e);
  }

  /**
   * Release everything. Called on blur, tab-hide, and stop().
   *
   * This is the fix for the character that runs forever. It is also why
   * `stop()` calls it: tearing down mid-input must not leave a mode that
   * outlives us holding a phantom key.
   */
  private flush = (): void => {
    if (this.held.size === 0 && !this.toggleLatched) return;
    for (const key of [...this.held]) {
      const btn = this.bindings[key];
      if (btn) this.emit({ t: 'button', btn, pressed: false });
      const dir = DPAD_KEYS[key];
      if (dir) this.emit({ t: 'dpad', dir, pressed: false });
    }
    this.held.clear();
    this.toggleLatched = false;
    this.emitAnalog('L', { t: 'stick', side: 'L', x: 0, y: 0 });
    this.emit({ t: 'trigger', side: 'R', value: 0 });
  };

  private onVisibility = (): void => { if (document.hidden) this.flush(); };

  private onKey = (ev: KeyboardEvent): void => {
    const key = ev.key.toLowerCase();
    const down = ev.type === 'keydown';

    // A modifier chord is a browser shortcut, not gameplay. Never swallow it
    // and never act on it — eating Cmd-R would be a worse bug than the one
    // this file fixes.
    const hasModifier = ev.ctrlKey || ev.metaKey || ev.altKey;
    if (hasModifier) return;
    if (this.opts.captureKeys && shouldPreventDefault(key, hasModifier, this.bindings)) {
      ev.preventDefault();
    }
    if (!isGameKey(key, this.bindings)) return;

    if (down && this.held.has(key)) return;          // ignore auto-repeat
    if (down) this.held.add(key); else this.held.delete(key);

    if ((MOVE_KEYS as readonly string[]).includes(key)) {
      const { x, y } = stickFromKeys(this.held);
      this.emitAnalog('L', { t: 'stick', side: 'L', x, y });
      return;
    }

    // Shift is sprint, and sprint is an EXPLICIT decision. It is never
    // inferred from how far a digital key is pressed — that inference is the
    // always-sprinting bug this whole batch exists to kill.
    if (key === 'shift') { this.emit({ t: 'button', btn: 'L1', pressed: down }); return; }

    if (key === ' ') { this.handleTrigger(down); return; }

    const dir = DPAD_KEYS[key];
    if (dir) { this.emit({ t: 'dpad', dir, pressed: down }); return; }

    const btn = this.bindings[key];
    if (btn) this.emit({ t: 'button', btn, pressed: down });
  };

  /**
   * Space: charge trigger, and — only on a short press — a button A tap.
   *
   * v2 emitted BOTH on every release, so a mode could not distinguish
   * "released a full charge" from "tapped to jump". Duration disambiguates
   * them, which is both correct and what the player already expects.
   */
  private handleTrigger(down: boolean): void {
    if (this.opts.holdToToggle) {
      if (!down) return;                              // toggle acts on press only
      this.toggleLatched = !this.toggleLatched;
      if (this.toggleLatched) { this.triggerDownAt = performance.now(); this.emit({ t: 'trigger', side: 'R', value: 0.01 }); }
      else { this.emit({ t: 'trigger', side: 'R', value: 0 }); this.emit({ t: 'button', btn: 'A', pressed: true }); }
      return;
    }
    if (down) {
      this.triggerDownAt = performance.now();
      this.emit({ t: 'trigger', side: 'R', value: 0.01 });
      return;
    }
    const heldMs = performance.now() - this.triggerDownAt;
    this.emit({ t: 'trigger', side: 'R', value: 0 });
    if (classifyRelease(heldMs) === 'tap') this.emit({ t: 'button', btn: 'A', pressed: true });
  }

  private onPad = (ev: GamepadEvent): void => { this.padIndex = ev.gamepad.index; this.gamepadActive = true; };
  private onPadOff = (): void => { this.padIndex = null; this.gamepadActive = false; this.flush(); };

  private pollPads = (): void => {
    if (this.padIndex !== null) {
      const pad = navigator.getGamepads?.()[this.padIndex];
      if (pad) {
        // Rescaled radial deadzone — the same function MotionModel uses, so
        // the pad and the keyboard cannot drift apart.
        const l = applyDeadzone(pad.axes[0] ?? 0, pad.axes[1] ?? 0, 0.12);
        const r = applyDeadzone(pad.axes[2] ?? 0, pad.axes[3] ?? 0, 0.12);
        // Gamepad Y is inverted relative to our "up is +y" convention.
        this.emitAnalog('L', { t: 'stick', side: 'L', x: l.x, y: -l.y });
        this.emitAnalog('R', { t: 'stick', side: 'R', x: r.x, y: -r.y });
        this.emitAnalog('TL', { t: 'trigger', side: 'L', value: pad.buttons[6]?.value ?? 0 });
        this.emitAnalog('TR', { t: 'trigger', side: 'R', value: pad.buttons[7]?.value ?? 0 });

        const btns: Array<[FelButton, number]> =
          [['A', 0], ['B', 1], ['X', 2], ['Y', 3], ['L1', 4], ['R1', 5], ['SELECT', 8], ['START', 9]];
        for (const [btn, i] of btns) {
          const pressed = !!pad.buttons[i]?.pressed;
          const key = `pad_${btn}`;
          if (pressed && !this.held.has(key)) { this.held.add(key); this.emit({ t: 'button', btn, pressed: true }); }
          if (!pressed && this.held.has(key)) { this.held.delete(key); this.emit({ t: 'button', btn, pressed: false }); }
        }
      }
    }

    // Analog charge depth while space is held.
    if (this.held.has(' ') || this.toggleLatched) {
      const depth = Math.min(1, (performance.now() - this.triggerDownAt) / CHARGE_FULL_MS);
      this.emitAnalog('space', { t: 'trigger', side: 'R', value: depth });
    }

    this.raf = requestAnimationFrame(this.pollPads);
  };
}
