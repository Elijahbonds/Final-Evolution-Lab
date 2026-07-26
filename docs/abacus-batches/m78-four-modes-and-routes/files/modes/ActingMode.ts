// ActingMode — the fifth Creator Card discipline finally gets a surface.
//
// M28 shipped VoiceCapture.ts and nothing ever played it, so `acting` has been
// the one discipline of five you could put on a card and never actually do.
//
// PRIVACY: audio is analysed LOCALLY and never uploaded for scoring. The
// analyser reads loudness from the live stream; no recording leaves the device
// unless the player explicitly saves the take to a Creator Card. There is no
// speech recognition here at all — see ActingCore for why that is deliberate
// rather than a gap.

import { mountVenue, type VenueHandle } from '../core/NexusVenue';
import { SoundKit } from '../audio/SoundKit';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import {
  scorePerformance, type Delivery, type Scene, type ScriptLine,
} from '../core/ActingCore';
import { ACTING_SCENES } from '../content/actingScenes';

export const ActingMode: ModeDefinition = (() => {
  let venue: VenueHandle | null = null;
  let scene: Scene = ACTING_SCENES[0];
  let elapsed = 0;
  let ended = false;
  let mic: MediaStream | null = null;
  let analyser: AnalyserNode | null = null;
  let audioCtx: AudioContext | null = null;
  let buf: Uint8Array | null = null;

  const deliveries: Record<string, Delivery> = {};
  let active: { line: ScriptLine; env: number[]; startedAt: number } | null = null;

  /** Normalised 0–1 loudness from the live analyser. */
  function level(): number {
    if (!analyser || !buf) return 0;
    analyser.getByteTimeDomainData(buf);
    let sum = 0;
    for (let i = 0; i < buf.length; i++) {
      const v = (buf[i] - 128) / 128;
      sum += v * v;
    }
    return Math.min(1, Math.sqrt(sum / buf.length) * 3);   // ×3 ≈ speech headroom
  }

  async function openMic(ctx: ModeContext): Promise<boolean> {
    try {
      mic = await navigator.mediaDevices.getUserMedia({ audio: true });
      audioCtx = new AudioContext();
      const src = audioCtx.createMediaStreamSource(mic);
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 1024;
      buf = new Uint8Array(analyser.fftSize);
      src.connect(analyser);
      return true;
    } catch {
      // Denied or unavailable. Say so plainly — a performance mode that
      // silently scores zero looks broken rather than blocked.
      ctx.setHud({ banner: 'MICROPHONE NEEDED', explain: 'Allow microphone access to perform this scene.' });
      return false;
    }
  }

  return {
    modeId: 'acting',
    mood: 'neon',
    camPreset: 'overShoulder',

    async load(ctx: ModeContext) {
      venue = mountVenue(ctx, 'who_scene_it');   // the Scene Vault stage
      scene = ACTING_SCENES[Math.floor(Math.random() * ACTING_SCENES.length)];
      elapsed = 0; ended = false;
      for (const k of Object.keys(deliveries)) delete deliveries[k];
      active = null;

      const okMic = await openMic(ctx);
      ctx.setHud({
        sceneTitle: scene.title,
        script: scene.lines.map((l) => ({ id: l.id, text: l.text, cueAt: l.cueAt, intensity: l.intensity })),
        micReady: okMic,
      });
      SoundKit.startAmbient('studio');
      assertSpawned(ctx.scene, { minWorldMeshes: 4, modeId: 'acting' });
    },

    onInput(_ctx: ModeContext, _e: FelInput) { /* delivery is voice-driven */ },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      elapsed += dt;

      // Open a capture window around each line's cue, generously on both
      // sides so an early or late entry is still MEASURED — and then scored
      // as early or late, rather than lost entirely.
      const line = scene.lines.find(
        (l) => elapsed >= l.cueAt - 1.5 && elapsed <= l.cueAt + l.duration + 1.5 && !deliveries[l.id],
      );

      if (line) {
        if (!active || active.line.id !== line.id) {
          active = { line, env: [], startedAt: elapsed };
          ctx.setHud({ activeLineId: line.id });
        }
        const lvl = level();
        active.env.push(lvl);
        ctx.setHud({ micLevel: lvl });
      } else if (active) {
        // Window closed — commit the take.
        const env = active.env;
        const firstSound = env.findIndex((v) => v > 0.05);
        const lastSound = env.length - 1 - [...env].reverse().findIndex((v) => v > 0.05);
        const perSample = (elapsed - active.startedAt) / Math.max(1, env.length);
        deliveries[active.line.id] = firstSound < 0
          ? { startedAt: active.startedAt, endedAt: active.startedAt, envelope: [] }
          : {
              startedAt: active.startedAt + firstSound * perSample,
              endedAt: active.startedAt + lastSound * perSample,
              envelope: env.slice(firstSound, lastSound + 1),
            };
        active = null;
        ctx.setHud({ activeLineId: '' });
      }

      const last = scene.lines[scene.lines.length - 1];
      if (elapsed > last.cueAt + last.duration + 2.5) {
        ended = true;
        const r = scorePerformance(scene, deliveries);
        ctx.setHud({
          banner: `${'★'.repeat(r.stars)}${'☆'.repeat(5 - r.stars)}`,
          notes: r.perLine.map((l) => ({ lineId: l.lineId, note: l.note, score: l.total })),
        });
        ctx.onGameOver?.({
          modeId: 'acting', won: r.stars >= 3, score: Math.round(r.average * 1000),
          detail: { stars: r.stars, sceneId: scene.id, best: r.best, worst: r.worst },
        });
      }
    },

    dispose() {
      mic?.getTracks().forEach((t) => t.stop());
      audioCtx?.close().catch(() => {});
      mic = null; analyser = null; audioCtx = null; buf = null;
      venue?.dispose(); venue = null;
      SoundKit.stopAmbient();
      ended = true;
    },
  };
})();
