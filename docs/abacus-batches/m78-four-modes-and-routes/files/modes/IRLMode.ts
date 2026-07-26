// IRLMode — the real-world jump mode, on the web.
//
// The iOS design assumed HealthKit. The web has no HealthKit, so this reads
// DeviceMotionEvent instead: available on mobile browsers after an explicit
// permission prompt, and NOT AVAILABLE AT ALL on desktop. The mode says so
// rather than showing a counter that can never move — a feature that silently
// does nothing on half the devices is worse than one that explains itself.
//
// All jump maths is in IRLCore (DOM-free, 16 executed tests), including the
// rejection of implausible flight times, which is both a correctness guard and
// the obvious anti-cheat: a thrown phone free-falls beautifully.

import { mountVenue, type VenueHandle } from '../core/NexusVenue';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import {
  detectJumps, summarise, motionAvailability, G, type MotionSample,
} from '../core/IRLCore';

const SESSION_SEC = 60;

export const IRLMode: ModeDefinition = (() => {
  let venue: VenueHandle | null = null;
  let samples: MotionSample[] = [];
  let t = 0;
  let ended = false;
  let counted = 0;
  let listening = false;
  let onMotion: ((e: DeviceMotionEvent) => void) | null = null;

  function start(ctx: ModeContext): void {
    onMotion = (e: DeviceMotionEvent) => {
      const a = e.accelerationIncludingGravity;
      if (!a) return;
      const mag = Math.sqrt((a.x ?? 0) ** 2 + (a.y ?? 0) ** 2 + (a.z ?? 0) ** 2);
      samples.push({ t, magnitude: mag });
      // Keep ~20s of trace. Unbounded growth over a long session is a real
      // leak on a phone, and old samples cannot become new jumps.
      if (samples.length > 2000) samples = samples.slice(-1500);
    };
    window.addEventListener('devicemotion', onMotion);
    listening = true;
    ctx.setHud({ banner: 'JUMP!', explain: '' });
  }

  return {
    modeId: 'irl',
    mood: 'goldenHour',
    camPreset: 'hoops',

    async load(ctx: ModeContext) {
      venue = mountVenue(ctx, 'basketball_irl');
      samples = []; t = 0; ended = false; counted = 0; listening = false;

      const avail = motionAvailability();
      if (avail === 'unsupported') {
        ctx.setHud({
          banner: 'PHONE REQUIRED',
          explain: 'IRL Dunk measures a real vertical jump using your phone’s motion sensor. '
                 + 'Open this mode on a phone to play.',
        });
      } else if (avail === 'needs-permission') {
        ctx.setHud({
          banner: 'TAP TO ALLOW MOTION',
          explain: 'This mode needs motion access to measure your jump.',
        });
      } else {
        start(ctx);
      }

      SoundKit.startAmbient('ambient_gym');
      assertSpawned(ctx.scene, { minWorldMeshes: 4, modeId: 'irl' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      // iOS requires the permission request to come from a user gesture.
      if (!listening && e.t === 'button' && e.pressed) {
        const DME = (globalThis as unknown as {
          DeviceMotionEvent?: { requestPermission?: () => Promise<string> };
        }).DeviceMotionEvent;
        if (DME?.requestPermission) {
          DME.requestPermission()
            .then((res) => { if (res === 'granted') start(ctx); else ctx.setHud({ banner: 'MOTION DENIED' }); })
            .catch(() => ctx.setHud({ banner: 'MOTION UNAVAILABLE' }));
        }
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      t += dt;

      if (listening) {
        const jumps = detectJumps(samples);
        if (jumps.length > counted) {
          const latest = jumps[jumps.length - 1];
          counted = jumps.length;
          EffectsKit.burst(ctx.scene, ctx.scene.activeCamera!.position, 'spark');
          SoundKit.play('score', { volume: 0.5 });
          ctx.setHud({
            banner: `${(latest.height * 100).toFixed(0)} cm`,
            score: Math.round(summarise(jumps).best * 100),
            combo: counted,
          });
        }
        ctx.setHud({ timer: Math.max(0, SESSION_SEC - t) });
      }

      if (t >= SESSION_SEC) {
        ended = true;
        const s = summarise(detectJumps(samples));
        ctx.setHud({ banner: s.total ? `BEST ${(s.best * 100).toFixed(0)} cm` : 'NO JUMPS DETECTED' });
        ctx.onGameOver?.({
          modeId: 'irl', won: s.total > 0, score: Math.round(s.best * 100),
          detail: { jumps: s.total, bestCm: s.best * 100, averageCm: s.average * 100 },
        });
      }
    },

    dispose() {
      if (onMotion) window.removeEventListener('devicemotion', onMotion);
      onMotion = null; listening = false;
      venue?.dispose(); venue = null;
      SoundKit.stopAmbient();
      ended = true; samples = [];
    },
  };
})();
