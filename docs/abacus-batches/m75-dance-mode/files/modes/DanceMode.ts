// DanceMode — the mode Dance never had.
//
// M28 shipped ChoreographyEngine and CreatorCardTypes with a full `dance`
// payload (choreographyId, sequence, routineVideoUrl). What it never shipped
// was a ModeDefinition, a route, a venue, or clips the ids resolve to — so
// /play/dance has been a 404 the whole time. This is the missing half.
//
// TIMING RUNS ON THE AUDIO CLOCK, NOT THE FRAME CLOCK
// The one decision that matters in a rhythm game. `update(dt)` arrives on
// requestAnimationFrame; a single dropped frame shifts the judging window
// against the music, and players feel a 30 ms drift immediately even though
// no counter shows it. So every timing call takes AudioContext.currentTime,
// and the frame loop only ever asks "what time is it in the song?".

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { mountVenue, type VenueHandle } from '../core/NexusVenue';
import { registerDanceClips, resolveDanceClip } from '../anim/danceClips';
import { AudioEngine } from '../music/AudioEngine';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import {
  DancePerformance, generateRoutine, beatDuration, type Judgement, type DanceStep,
} from '../core/DanceCore';
import { DUNK_CONFIG as SHARED_CFG } from './modeConfigs';

const BPM = 96;
const BARS = 16;
const DIFFICULTY: 1 | 2 | 3 = 2;

export const DanceMode: ModeDefinition = (() => {
  let me: SpawnedCharacter;
  let venue: VenueHandle | null = null;
  let perf: DancePerformance;
  let registered = new Set<string>();
  let ended = false;
  let countInSec = 0;
  let started = false;

  /** The song clock. Falls back to performance.now() only if no audio context
   *  exists — and says so, because silent fallback to the frame clock is the
   *  bug this mode is most likely to ship with. */
  function audioNow(): number {
    const ctx = AudioEngine.context;
    if (ctx) return ctx.currentTime;
    return performance.now() / 1000;
  }

  function playStep(s: DanceStep): void {
    const id = resolveDanceClip(s.clipId, (x) => registered.has(x));
    // Clips are authored at 120 BPM; rescale so one clip serves every tempo.
    me.animator.play(s.mirrored ? `${id}.M` : id, {
      fadeSec: 0.12,
      speedRatio: BPM / 120,
    });
  }

  function onJudged(ctx: ModeContext, label: Judgement, _pts: number, combo: number): void {
    ctx.setHud({ banner: combo >= 4 ? `${label}  ×${combo}` : label, score: perf.score, combo });
    if (label === 'PERFECT') {
      EffectsKit.burst(ctx.scene, me.root.position.add(new Vector3(0, 1.4, 0)), 'spark');
      SoundKit.play('uiTick', { pitch: 1.6, volume: 0.35 });
    } else if (label === 'MISS') {
      SoundKit.play('miss', { volume: 0.25 });
    }
    setTimeout(() => ctx.setHud({ banner: '' }), 380);
  }

  function finish(ctx: ModeContext): void {
    if (ended) return;
    ended = true;
    perf.stop();
    AudioEngine.stop?.();
    const r = perf.result();
    ctx.setHud({
      banner: `${'★'.repeat(r.stars)}${'☆'.repeat(5 - r.stars)}  ${Math.round(r.accuracy * 100)}%`,
    });
    ctx.onGameOver?.({
      modeId: 'dance',
      won: r.stars >= 3,
      score: r.score,
      detail: {
        stars: r.stars,
        maxCombo: r.maxCombo,
        perfect: r.counts.PERFECT,
        great: r.counts.GREAT,
        good: r.counts.GOOD,
        miss: r.counts.MISS,
      },
    });
  }

  return {
    modeId: 'dance',
    mood: 'neon',
    camPreset: 'overShoulder',

    async load(ctx: ModeContext) {
      venue = mountVenue(ctx, 'dance');

      me = await CharacterLibrary.spawn(ctx.scene, SHARED_CFG.heroUrl, {
        // Stand on the stage deck, not in it — podium scale 1.4 → surface y 0.7.
        position: new Vector3(0, 0.7, 0), yawRad: Math.PI, startClip: SPORT_CLIP.idle,
      });
      neverBindPose(me.animator, SPORT_CLIP.idle);
      installSafePlay(me.animator, 'dance-me');
      ctx.groundLock?.track(me.root, me.skeleton);
      venue?.hidePlaceholders();

      // Build the dance clips against THIS skeleton.
      registered = new Set<string>();
      registerDanceClips(ctx.scene, me.skeleton, (id, group) => {
        me.animator.registerClip?.(id, group);
        registered.add(id);
      });

      perf = new DancePerformance(BPM);
      perf.setRoutine(generateRoutine({ bars: BARS, difficulty: DIFFICULTY, seed: Date.now() & 0xffff }));
      perf.onStepFired = playStep;
      perf.onJudged = (l, p, c) => onJudged(ctx, l, p, c);

      ended = false; started = false;
      countInSec = beatDuration(BPM) * 4;          // one bar of count-in

      ctx.heroRef = () => me.root;
      ctx.objectiveRef = () => me.root.position;
      ctx.camDirector.snapTo(me.root.position, me.root.position);
      ctx.setHud({ score: 0, combo: 0, banner: 'GET READY' });
      SoundKit.startAmbient('club');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 6, modeId: 'dance' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (ended || !started) return;
      const tap = (e.t === 'button' && e.pressed && (e.btn === 'A' || e.btn === 'B'))
        || (e.t === 'trigger' && e.side === 'R' && e.value > 0.5);
      if (tap) {
        const label = perf.hit(audioNow());
        void label;   // onJudged already reported it
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;

      if (!started) {
        countInSec -= dt;
        if (countInSec <= 0) {
          started = true;
          AudioEngine.startTrack?.({ bpm: BPM, bars: BARS });
          perf.start(audioNow());
          ctx.setHud({ banner: 'GO' });
          setTimeout(() => ctx.setHud({ banner: '' }), 500);
        } else {
          ctx.setHud({ banner: `${Math.ceil(countInSec / beatDuration(BPM))}` });
        }
        return;
      }

      const now = audioNow();
      perf.update(now);

      // The routine is over one full beat after the last step's window closes,
      // so a final PERFECT is never cut off by the results screen.
      const elapsedBeats = (now - (perf as unknown as { started: number }).started) / beatDuration(BPM);
      if (elapsedBeats > perf.totalBeats + 1) finish(ctx);
    },

    dispose() {
      perf?.stop();
      AudioEngine.stop?.();
      SoundKit.stopAmbient();
      venue?.dispose(); venue = null;
      ended = true;
    },
  };
})();

// HUD fields used: score, combo, banner (judgement + final star rating).
//
// ROUTE: add `/play/dance` and register DanceMode in the mode registry.
// The Creator Card `dance` payload (choreographyId + sequence) is already
// defined in M28's CreatorCardTypes — `perf.setRoutine(card.sequence)` is all
// that is needed to play a card's routine instead of a generated one.
