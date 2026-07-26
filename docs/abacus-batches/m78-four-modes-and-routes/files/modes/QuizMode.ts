// QuizMode — the factory both quiz modes are built from.
//
// Brain Brawl and Who Scene It differ in their prompts and their clock, not
// their loop. All the timing, scoring and opponent logic lives in QuizCore
// (Babylon-free, 36 executed tests); this file owns the venue, the HUD and
// the input, and nothing else.
//
// The interesting difference is that Who Scene It RENDERS ITS QUESTION: each
// prompt names a venue id, and the mode rebuilds that venue behind the
// answer buttons. The question is the scene. That is why the venue system had
// to exist before this mode could.

import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { mountVenue, type VenueHandle } from '../core/NexusVenue';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { drawRound, QuizRound, type QuizConfig, type QuizPack } from '../core/QuizCore';
import { DUNK_CONFIG as SHARED_CFG } from './modeConfigs';

export interface QuizModeOptions {
  modeId: string;
  /** Venue when a question does not name one of its own. */
  defaultVenueId: string;
  pack: QuizPack;
  cfg: QuizConfig;
  /** True for Who Scene It: rebuild the venue named by each question. */
  renderQuestionScene: boolean;
  foeSkill: number;
  foeSpeed: number;
}

export function createQuizMode(o: QuizModeOptions): ModeDefinition {
  let me: SpawnedCharacter | null = null;
  let venue: VenueHandle | null = null;
  let currentVenueId = '';
  let round: QuizRound;
  let ended = false;
  let revealSec = 0;

  function showVenue(ctx: ModeContext, venueId: string): void {
    if (venueId === currentVenueId) return;
    venue?.dispose();
    venue = mountVenue(ctx, venueId);
    currentVenueId = venueId;
  }

  function pushHud(ctx: ModeContext): void {
    const q = round.current;
    ctx.setHud({
      score: round.you.score,
      foeScore: round.foe.score,
      combo: round.you.streak,
      timer: Math.max(0, round.timeLeft),
      question: q?.prompt ?? '',
      options: q?.options ?? [],
      questionIndex: round.index + 1,
      questionTotal: round.questions.length,
    });
  }

  function finish(ctx: ModeContext): void {
    if (ended) return;
    ended = true;
    const w = round.winner;
    ctx.setHud({ banner: w === 'you' ? 'YOU WIN' : w === 'foe' ? 'YOU LOSE' : 'DRAW', options: [] });
    ctx.onGameOver?.({
      modeId: o.modeId,
      won: w === 'you',
      score: round.you.score,
      detail: { correct: round.you.correct, answered: round.you.answered, accuracy: round.accuracy },
    });
  }

  function resolveAndReveal(ctx: ModeContext, correct: boolean): void {
    const q = round.current;
    ctx.setHud({
      banner: correct ? 'CORRECT' : 'WRONG',
      explain: q?.explain ?? '',
      revealId: q?.answer ?? '',
    });
    if (correct && me) EffectsKit.burst(ctx.scene, me.root.position, 'spark');
    SoundKit.play(correct ? 'score' : 'miss', { volume: 0.4 });
    // Hold on the answer so the explanation is readable. A quiz that snaps to
    // the next question teaches nothing.
    revealSec = 2.0;
  }

  return {
    modeId: o.modeId,
    mood: 'neon',
    camPreset: 'board',

    async load(ctx: ModeContext) {
      round = new QuizRound(
        drawRound(o.pack, o.cfg, Date.now() & 0xffff), o.cfg,
        Date.now() & 0xffff, o.foeSkill, o.foeSpeed,
      );
      ended = false; revealSec = 0; currentVenueId = '';

      const first = o.renderQuestionScene ? round.current?.sceneVenueId : undefined;
      showVenue(ctx, first ?? o.defaultVenueId);

      // A host body on the stage. Who Scene It hides it — the venue IS the
      // question, and a character standing in front of it gives the answer away
      // by drawing the eye to the wrong thing.
      if (!o.renderQuestionScene) {
        me = await CharacterLibrary.spawn(ctx.scene, SHARED_CFG.heroUrl, {
          position: (await import('@babylonjs/core')).Vector3.Zero(),
          yawRad: Math.PI, startClip: SPORT_CLIP.idle,
        });
        neverBindPose(me.animator, SPORT_CLIP.idle);
        installSafePlay(me.animator, `${o.modeId}-host`);
        ctx.groundLock?.track(me.root, me.skeleton);
        venue?.hidePlaceholders();
        ctx.heroRef = () => me!.root;
      }

      SoundKit.startAmbient('arena');
      pushHud(ctx);
      assertSpawned(ctx.scene, { hero: me?.root, minWorldMeshes: 6, modeId: o.modeId });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (ended || round.resolved) return;
      // Options are answered by index: buttons A/B/X/Y map to 0..3, and the
      // touch UI sends the same as `option` events.
      const BTN: Record<string, number> = { A: 0, B: 1, X: 2, Y: 3 };
      let idx = -1;
      if (e.t === 'button' && e.pressed && BTN[e.btn] !== undefined) idx = BTN[e.btn];
      if ((e as { t: string; index?: number }).t === 'option') idx = (e as { index: number }).index;
      const opt = round.current?.options[idx];
      if (!opt) return;
      const res = round.answer(opt.id);
      if (res) resolveAndReveal(ctx, res.outcome === 'correct');
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;

      if (revealSec > 0) {
        revealSec -= dt;
        if (revealSec <= 0) {
          ctx.setHud({ banner: '', explain: '', revealId: '' });
          if (!round.next()) { finish(ctx); return; }
          if (o.renderQuestionScene && round.current?.sceneVenueId) {
            showVenue(ctx, round.current.sceneVenueId);
          }
          pushHud(ctx);
        }
        return;
      }

      const ev = round.tick(dt);
      if (ev.foeAnswered) ctx.setHud({ foeScore: round.foe.score });
      if (ev.timedOut) { resolveAndReveal(ctx, false); return; }
      pushHud(ctx);
    },

    dispose() {
      venue?.dispose(); venue = null;
      SoundKit.stopAmbient();
      ended = true; me = null;
    },
  };
}
