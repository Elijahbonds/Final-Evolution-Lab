// KeyboardMap — THE one keyboard→FelInput mapping (fixes E13's keyboard half:
// keys existed but were undocumented and diverged per mode). Desktop plays
// every mode with the same hands-on-home-row scheme TouchOverlay verbs map to.
//
//   WASD / arrows     left stick
//   SPACE (hold)      right trigger — analog ramp 0→1 while held, 0 on release
//   J                 A (SLAM / JAB / POP / SWING / primary verb)
//   K                 B (STYLE / KICK / FLIP)
//   L                 X (BLOCK / GRAB / JUKE L)
//   I                 Y (HEAVY / JUKE R)
//   1 / 2 / 3         dpad up/right/down (direct style pick)
//   ESC               pause

import type { InputBus } from './InputBus';

const CHARGE_RAMP_MS = 1100;                 // matches TouchOverlay hold ramp

export function mountKeyboard(bus: InputBus): () => void {
  const held = new Set<string>();
  let chargeRaf = 0, chargeStart = 0;

  const stick = () => {
    const x = (held.has('KeyD') || held.has('ArrowRight') ? 1 : 0) - (held.has('KeyA') || held.has('ArrowLeft') ? 1 : 0);
    const y = (held.has('KeyS') || held.has('ArrowDown') ? 1 : 0) - (held.has('KeyW') || held.has('ArrowUp') ? 1 : 0);
    const len = Math.hypot(x, y) || 1;
    bus.emit({ t: 'stick', side: 'L', x: x / len, y: y / len });
  };

  const BTN: Record<string, 'A' | 'B' | 'X' | 'Y'> = { KeyJ: 'A', KeyK: 'B', KeyL: 'X', KeyI: 'Y' };
  const DPAD: Record<string, 'up' | 'right' | 'down'> = { Digit1: 'up', Digit2: 'right', Digit3: 'down' };

  const down = (e: KeyboardEvent) => {
    if (e.repeat) return;
    held.add(e.code);
    if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) { stick(); e.preventDefault(); }
    if (BTN[e.code]) bus.emit({ t: 'button', btn: BTN[e.code], pressed: true });
    if (DPAD[e.code]) bus.emit({ t: 'dpad', dir: DPAD[e.code], pressed: true });
    if (e.code === 'Space') {
      e.preventDefault();
      chargeStart = performance.now();
      const ramp = () => {
        const v = Math.min(1, (performance.now() - chargeStart) / CHARGE_RAMP_MS);
        bus.emit({ t: 'trigger', side: 'R', value: Math.max(0.01, v) });
        chargeRaf = requestAnimationFrame(ramp);
      };
      ramp();
    }
    if (e.code === 'Escape') bus.emit({ t: 'button', btn: 'start', pressed: true } as never);
  };

  const up = (e: KeyboardEvent) => {
    held.delete(e.code);
    if (['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(e.code)) stick();
    if (BTN[e.code]) bus.emit({ t: 'button', btn: BTN[e.code], pressed: false });
    if (e.code === 'Space') {
      cancelAnimationFrame(chargeRaf);
      bus.emit({ t: 'trigger', side: 'R', value: 0 });   // release = launch
    }
  };

  const blur = () => {                                    // tab-away: neutral state
    held.clear();
    cancelAnimationFrame(chargeRaf);
    bus.emit({ t: 'stick', side: 'L', x: 0, y: 0 });
    bus.emit({ t: 'trigger', side: 'R', value: 0 });
  };

  window.addEventListener('keydown', down);
  window.addEventListener('keyup', up);
  window.addEventListener('blur', blur);
  return () => {
    window.removeEventListener('keydown', down);
    window.removeEventListener('keyup', up);
    window.removeEventListener('blur', blur);
    blur();
  };
}

// MOUNT once in ModeHarness alongside TouchOverlay + gamepad poller. DELETE
// any per-mode keydown listeners (grep `addEventListener('keydown'` outside
// this file) — one input path, ever (see KNOWN-ERRORS E7/E13).
