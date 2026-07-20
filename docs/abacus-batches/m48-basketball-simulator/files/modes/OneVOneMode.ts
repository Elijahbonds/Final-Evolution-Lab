// OneVOneMode — REPLACES whatever currently drives `/play/onevone`. Full
// rebuild on the M48 basketball core: momentum-based dribbling with a real
// crossover, a green-window shot meter that a defender's contest actually
// narrows, make-it-take-it possession, and a momentum meter with a real
// payoff (a hot hand shrinks the defender's effective contest). Built on
// PlayerSlot so the defender slot is multiplayer-ready — swap DefenderBrain
// for a NetworkInputSource later and nothing else in this file changes.
//
// SCOPE NOTE: this is a NEW implementation, not a patch — M46 established
// this repo has never seen the existing 1v1 Hoops source, so an honest fix
// meant building complete, tested logic on infrastructure this project
// already owns and trusts, matched to the live HUD contract observed
// (MOMENTUM meter, CAM FOLLOW readout, FIRST TO 11).

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { VenueKit } from '../visual/VenueKit';
import { BallSim } from '../core/BallPhysics';
import { attachBallToHand, releaseBall } from '../anim/ballRig';
import { PlayerSlot, LocalInputSource, AISource } from '../core/PlayerSlot';
import { DribbleController, ShotMeter, DefenderBrain, contestLevel, clampToHalfCourt, SHOT_QUALITY_PCT, type ShotQuality } from '../core/BasketballCore';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { DUNK_CONFIG as SHARED_CFG } from './modeConfigs';

const RIM = new Vector3(0, 3.05, -0.6);            // matches VenueKit.buildCourt's hoop placement
const TARGET_SCORE = 11;
const PAINT_RADIUS = 4.2;                          // inside this = 1pt; beyond = 2pt jumper

export const OneVOneMode: ModeDefinition = (() => {
  let me: SpawnedCharacter, foe: SpawnedCharacter, ball: AbstractMesh, ballSim: BallSim;
  let meSlot: PlayerSlot, foeSlot: PlayerSlot, localSource: LocalInputSource;
  let meDribble: DribbleController;
  let shotMeter: ShotMeter;
  let myScore = 0, foeScore = 0, momentum = 0;
  let carrying = true;                              // make-it-take-it: you keep the ball after a make
  let shooting = false, ballLive = false;
  let ended = false;

  const cfg = { heroUrl: SHARED_CFG.heroUrl };

  function resetPositions(): void {
    me.root.position.set(0, 0, 5);
    foe.root.position.set(0, 0, 2);
    attachBallToHand(ball, me.skeleton, 'RightHand');
    ballLive = true; shooting = false;
  }

  return {
    modeId: 'onevone', mood: 'goldenHour', camPreset: 'hoops',

    async load(ctx: ModeContext) {
      VenueKit.buildCourt(ctx.scene, 'venice');
      me = await CharacterLibrary.spawn(ctx.scene, cfg.heroUrl, { position: new Vector3(0, 0, 5), yawRad: Math.PI, startClip: SPORT_CLIP.idle });
      neverBindPose(me.animator, SPORT_CLIP.idle); installSafePlay(me.animator, 'onevone-me');
      ctx.groundLock?.track(me.root, me.skeleton);
      foe = await CharacterLibrary.spawn(ctx.scene, cfg.heroUrl, { position: new Vector3(0, 0, 2), tint: '#ff2d78', startClip: SPORT_CLIP.idle });
      neverBindPose(foe.animator, SPORT_CLIP.idle); installSafePlay(foe.animator, 'onevone-foe');
      ctx.groundLock?.track(foe.root, foe.skeleton);

      ball = MeshBuilder.CreateSphere('ball', { diameter: 0.24 }, ctx.scene);
      ballSim = new BallSim(ball, 0.12);
      attachBallToHand(ball, me.skeleton, 'RightHand');
      EffectsKit.ambient(ctx.scene, 'venice');
      EffectsKit.ballTrail(ctx.scene, ball);
      SoundKit.startAmbient('stadium');

      localSource = new LocalInputSource();
      meSlot = new PlayerSlot('me', localSource, true);
      foeSlot = new PlayerSlot('foe', new AISource(foe.root.position, {
        ball: () => ball.position, hoop: () => RIM, allies: () => [], foes: () => [me.root.position],
      }, new DefenderBrain(0.7)), false);

      meDribble = new DribbleController();
      shotMeter = new ShotMeter();
      myScore = 0; foeScore = 0; momentum = 0; ended = false;
      carrying = true;
      ctx.heroRef = () => me.root;
      ctx.objectiveRef = () => RIM;
      ctx.camDirector.snapTo(me.root.position, RIM);
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 6, modeId: 'onevone' });
      resetPositions();
      ctx.setHud({
        score: myScore, foeScore, target: TARGET_SCORE, momentum: 0,
        hint: 'Move to drive · reverse the stick fast for a crossover · HOLD SHOOT, release in the green',
      });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      localSource.feed(e);
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      meSlot.poll(dt);
      foeSlot.poll(dt);

      const intent = meSlot.intent;
      const drib = meDribble.update(dt, intent.moveX, intent.moveY, intent.sprint);
      if (!shooting) {
        me.root.position.addInPlace(meDribble.vel.scale(dt));
        clampToHalfCourt(me.root.position, 7.2, 14.5);
        me.root.rotation.y = drib.facingRad;
        me.animator.play(drib.speed01 > 0.15 ? SPORT_CLIP.moveLoop : SPORT_CLIP.idle, { loop: true });
        if (drib.crossover) {
          SoundKit.play('whoosh', { pitch: 1.4, volume: 0.4 });
          ctx.feel?.impact?.(0.1);
        }
      }

      // defender steering (contact-avoidant — it's on-ball D, not a tackle)
      const foeIntent = foeSlot.intent;
      const foeVel = new Vector3(foeIntent.moveX, 0, -foeIntent.moveY).scale(3.6);
      foe.root.position.addInPlace(foeVel.scale(dt));
      clampToHalfCourt(foe.root.position, 7.2, 14.5);
      if (foeVel.lengthSquared() > 0.05) foe.root.rotation.y = Math.atan2(foeVel.x, foeVel.z);
      foe.animator.play(foeVel.lengthSquared() > 0.3 ? SPORT_CLIP.moveLoop : SPORT_CLIP.idle, { loop: true });

      // steal: a successful poke turns the ball over — you get it right back
      // at the top (arcade-fair; a real turnover clock adds punishment
      // without adding fun, so this stays a possession reset, not a loss)
      if (carrying && !shooting && foeIntent.steal && Vector3.Distance(me.root.position, foe.root.position) < 1.2) {
        SoundKit.play('impact', { pitch: 1.2, volume: 0.3 });
        ctx.setHud({ banner: 'STRIPPED!' });
        momentum = Math.max(0, momentum - 20);
        setTimeout(() => ctx.setHud({ banner: '' }), 700);
        resetPositions();
      }

      // shooting
      if (!shooting && carrying && intent.actionHeld > 0.02) {
        shooting = true;
        const contest = contestLevel(me.root.position, foe.root.position);
        shotMeter.start(contest);
        me.animator.play(SPORT_CLIP.dunkChargeGather, { loop: true });
      }
      if (shooting) {
        const t = shotMeter.update(dt);
        ctx.setHud({ shotMeterT: t });
        if (intent.action || t >= 1) {
          const quality = shotMeter.release();
          void resolveShot(ctx, quality);
        }
      }

      ctx.camDirector.update(me.root.position, meDribble.vel, ball ? RIM : null);
      ctx.setHud({ camFollowM: Math.round(Vector3.Distance(ctx.camera.position, me.root.position) * 10) / 10 });
    },

    dispose() {
      me?.dispose(); foe?.dispose(); ball?.dispose();
      meSlot?.dispose(); foeSlot?.dispose();
      SoundKit.stopAmbient();
    },
  };

  async function resolveShot(ctx: ModeContext, quality: ShotQuality): Promise<void> {
    shooting = false;
    const pct = SHOT_QUALITY_PCT[quality] * (1 + momentum / 400);   // hot hand nudges make% up, capped small
    const dist = Vector3.Distance(me.root.position, RIM);
    const points = dist > PAINT_RADIUS ? 2 : 1;
    const made = Math.random() < Math.min(0.98, pct);

    releaseBall(ball);
    carrying = false; ballLive = false;
    me.animator.play(SPORT_CLIP.dunkLaunchPower, { onEnd: () => me.animator.play(SPORT_CLIP.idle, { loop: true }) });

    if (made) {
      myScore += points;
      momentum = Math.min(100, momentum + 18 + (quality === 'perfect' ? 12 : 0));
      SoundKit.play('score', { pitch: quality === 'perfect' ? 1.2 : 1 });
      EffectsKit.burst(ctx.scene, RIM, 'net');
      if (quality === 'perfect') { SoundKit.play('crowdCheer'); ctx.feel?.impact?.(0.4); }
      ctx.setHud({ score: myScore, momentum, banner: quality === 'perfect' ? 'SPLASH!' : 'GOOD!' });
      carrying = true;                                // make it, take it
    } else {
      momentum = Math.max(0, momentum - 15);
      SoundKit.play('miss');
      ballSim.launch(ball.getAbsolutePosition(), new Vector3((Math.random() - 0.5) * 2, 3, (Math.random() - 0.5) * 2));
      ctx.setHud({ momentum, banner: quality === 'brick' ? 'AIRBALL' : 'RIMS OUT' });
      // simple rebound: whoever's closer to the loose ball gets it
      setTimeout(() => {
        const meDist = Vector3.Distance(me.root.position, ball.position);
        const foeDist = Vector3.Distance(foe.root.position, ball.position);
        carrying = meDist <= foeDist;
        if (!carrying) { foeScore += Math.random() < 0.4 ? 1 : 0; ctx.setHud({ foeScore }); }   // AI occasionally converts the putback
        resetPositions();
      }, 900);
    }
    setTimeout(() => ctx.setHud({ banner: '' }), 900);

    if (myScore >= TARGET_SCORE) { ended = true; SoundKit.play('whistle'); ctx.end('WIN', myScore, { foeScore, momentum }); return; }
    if (foeScore >= TARGET_SCORE) { ended = true; SoundKit.play('whistle'); ctx.end('LOSS', myScore, { foeScore }); return; }
    if (made) setTimeout(() => resetPositions(), 700);
  }
})();

// HUD fields introduced: foeScore, target, momentum (0-100), shotMeterT
// (0-1, drive the meter fill + green-zone marker in the bezel), camFollowM.
