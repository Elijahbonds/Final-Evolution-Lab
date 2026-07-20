// DunkMode v2.3 — REPLACES the M42 file. Adds the mechanic every arcade
// basketball game since NBA Jam has used: a HOT STREAK. Consecutive makes
// build a multiplier (up to 2x at a 5-streak) and, from 3 in a row, the
// crowd audibly ramps up and every HUD banner reads "ON FIRE"; a miss resets
// it instantly. This turns "make shots" into "protect your streak," which is
// what makes arcade basketball tense instead of just repetitive. Also wires
// SoundKit throughout (whoosh on launch, score chime that rises in pitch
// with streak, crowd groan on miss, ambient court bed).

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { BallSim } from '../core/BallPhysics';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { attachBallToHand, releaseBall, runEastbayPath, flushThroughRim, clankOffRim } from '../anim/ballRig';
import { EASTBAY_TIMING } from '../anim/authored/timing';
import { DunkReplayRecorder } from '../scene/DunkReplayCam';
import { SoundKit } from '../audio/SoundKit';
import { DUNK_CONFIG as CFG } from './modeConfigs';

type Phase = 'approach' | 'charge' | 'cinematic' | 'resolve' | 'rivalTurn';

const STYLES = ['power', 'flashy', 'sig'] as const;
type Style = (typeof STYLES)[number];
const STYLE_CLIP: Record<Style, string> = {
  power: SPORT_CLIP.dunkLaunchPower, flashy: SPORT_CLIP.dunkLaunchFlashy, sig: SPORT_CLIP.dunkLaunchSig,
};
const STYLE_PTS: Record<Style, number> = { power: 1.5, flashy: 2, sig: 3 };
const STYLE_LABEL: Record<Style, string> = { power: 'POWER', flashy: 'FLASHY', sig: 'SIGNATURE' };
const STREAK_CAP = 5;                        // multiplier caps at 1 + 5*0.2 = 2x

const BUDGET_SEC: Record<Phase, number> = {
  approach: 30, charge: 5, cinematic: 4, resolve: 3, rivalTurn: 6,
};

export const DunkMode: ModeDefinition = (() => {
  let player: SpawnedCharacter, rival: SpawnedCharacter;
  let ball: AbstractMesh, ballSim: BallSim, replay: DunkReplayRecorder;
  let phase: Phase = 'approach';
  let phaseSec = 0;
  let style: Style = 'power';
  let charge = 0, clipTime = 0, qteHit = false, qteWindowOpen = false;
  let sinceRelease = 0, releasePos = new Vector3();
  let myScore = 0, rivalScore = 0, streak = 0;
  let finishing = false;
  const rim = new Vector3(0, CFG.rimHeight, CFG.rimZ);
  const ebState = { inLeftHand: false };
  let stickX = 0, stickY = 0;

  function setPhase(p: Phase): void { phase = p; phaseSec = 0; }
  const multiplier = () => 1 + Math.min(streak, STREAK_CAP) * 0.2;

  const def: ModeDefinition = {
    modeId: 'dunk', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, CFG.startZ), yawRad: Math.PI, startClip: SPORT_CLIP.idle,
      });
      neverBindPose(player.animator, SPORT_CLIP.idle);
      installSafePlay(player.animator, 'dunk-player');
      ctx.groundLock?.track(player.root, player.skeleton);
      rival = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(3.2, 0, CFG.rimZ + 3), tint: '#ff2d78', startClip: SPORT_CLIP.idle,
      });
      neverBindPose(rival.animator, SPORT_CLIP.idle);
      installSafePlay(rival.animator, 'dunk-rival');
      ctx.groundLock?.track(rival.root, rival.skeleton);

      ball = MeshBuilder.CreateSphere('ball', { diameter: 0.24 }, ctx.scene);
      ballSim = new BallSim(ball, 0.12);
      attachBallToHand(ball, player.skeleton, 'RightHand');
      replay = new DunkReplayRecorder(ctx.scene, player.root, ball, ctx.camera as never);

      ctx.camDirector.snapTo(player.root.position, rim);
      ctx.heroRef = () => player.root;
      ctx.objectiveRef = () => rim;
      SoundKit.startAmbient('stadium');

      myScore = 0; rivalScore = 0; streak = 0; finishing = false;
      setPhase('approach');
      ctx.setHud({
        score: `${myScore} – ${rivalScore}`, style: STYLE_LABEL[style], streak: '',
        hint: 'Drive the lane · HOLD CHARGE to load your jump',
      });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }

      if (e.t === 'button' && e.btn === 'B' && e.pressed && phase !== 'cinematic') {
        style = STYLES[(STYLES.indexOf(style) + 1) % STYLES.length];
        ctx.setHud({ style: STYLE_LABEL[style] });
      }
      if (e.t === 'dpad' && e.pressed) {
        style = e.dir === 'up' ? 'power' : e.dir === 'down' ? 'sig' : 'flashy';
        ctx.setHud({ style: STYLE_LABEL[style] });
      }

      if (e.t === 'trigger' && e.side === 'R') {
        if (phase === 'approach' && e.value > 0.02) {
          setPhase('charge');
          player.animator.play(SPORT_CLIP.dunkChargeGather, { loop: true });
        }
        if (phase === 'charge') {
          charge = Math.max(charge, e.value);
          ctx.setHud({ charge: Math.round(charge * 100) });
          if (e.value === 0) launchDunk(ctx);
        }
      }

      if (e.t === 'button' && e.btn === 'A' && e.pressed && qteWindowOpen) qteHit = true;
    },

    update(ctx: ModeContext, dt: number) {
      phaseSec += dt;
      watchdog(ctx);

      const vel = new Vector3(stickX * 4, 0, -Math.max(0, -stickY) * 5 - 2);
      if (phase === 'approach') {
        player.root.position.addInPlace(vel.scale(dt));
        player.root.position.z = Math.max(player.root.position.z, CFG.gatherZ);
        player.root.position.x = Math.max(-6, Math.min(6, player.root.position.x));
        const moving = Math.hypot(vel.x, vel.z) > 2.5;
        player.animator.play(moving ? SPORT_CLIP.moveLoop : SPORT_CLIP.idle, { loop: true });
        if (player.root.position.z <= CFG.gatherZ + 0.2) {
          ctx.setHud({ hint: 'HOLD CHARGE — load your jump' });
        }
      }

      if (phase === 'cinematic') {
        clipTime += dt;
        if (style === 'sig') runEastbayPath(ball, player.skeleton, clipTime, ebState);
        const k = Math.min(1, clipTime / EASTBAY_TIMING.duration);
        player.root.position.y = Math.sin(k * Math.PI) * (1.05 + charge * 0.55);
        player.root.position.z += (rim.z + 0.6 - player.root.position.z) * 1.6 * dt;

        const wasOpen = qteWindowOpen;
        qteWindowOpen = clipTime >= EASTBAY_TIMING.extend - CFG.qteWindowSec / 2
          && clipTime <= EASTBAY_TIMING.extend + CFG.qteWindowSec / 2;
        if (qteWindowOpen && !wasOpen) ctx.setHud({ hint: 'SLAM!', slamPulse: true });
        if (!qteWindowOpen && wasOpen) ctx.setHud({ slamPulse: false });
        if (clipTime >= EASTBAY_TIMING.extend + CFG.qteWindowSec / 2) resolveDunk(ctx);
      }

      if (phase === 'resolve') {
        sinceRelease += dt;
        if (qteHit) {
          if (flushThroughRim(ball, rim, releasePos, sinceRelease)) void finishAttempt(ctx, true);
        } else {
          ballSim.step(dt);
          if (sinceRelease > 1.2) void finishAttempt(ctx, false);
        }
      }

      if (phase === 'rivalTurn') {
        ctx.camDirector.update(rival.root.position, Vector3.Zero(), rim);
      } else {
        ctx.camDirector.update(player.root.position, vel, phase === 'approach' ? rim : ball.position);
      }
    },

    dispose() { player?.dispose(); rival?.dispose(); replay?.dispose(); ball?.dispose(); SoundKit.stopAmbient(); },
  };

  function watchdog(ctx: ModeContext): void {
    if (phaseSec <= BUDGET_SEC[phase] || finishing) return;
    console.warn(`[FEL-DUNK] watchdog tripped in phase "${phase}" after ${phaseSec.toFixed(1)}s — auto-resolving`);
    switch (phase) {
      case 'approach':
        player.root.position.set(0, 0, CFG.gatherZ);
        ctx.setHud({ hint: 'HOLD CHARGE — load your jump' });
        phaseSec = 0;
        break;
      case 'charge': launchDunk(ctx); break;
      case 'cinematic': resolveDunk(ctx); break;
      case 'resolve': void finishAttempt(ctx, qteHit); break;
      case 'rivalTurn':
        ctx.setHud({ score: `${myScore} – ${rivalScore}` });
        resetForNextAttempt(ctx);
        break;
    }
  }

  function launchDunk(ctx: ModeContext): void {
    if (phase === 'cinematic') return;
    setPhase('cinematic');
    clipTime = 0; qteHit = false; qteWindowOpen = false; ebState.inLeftHand = false;
    attachBallToHand(ball, player.skeleton, 'RightHand');
    SoundKit.play('whoosh', { pitch: 0.85 });
    player.animator.play(STYLE_CLIP[style], { speedRatio: 1, onEnd: () => {} });
  }

  function resolveDunk(ctx: ModeContext): void {
    if (phase === 'resolve') return;
    setPhase('resolve');
    sinceRelease = 0;
    qteWindowOpen = false;
    ctx.setHud({ slamPulse: false });
    releasePos.copyFrom(ball.getAbsolutePosition());
    releaseBall(ball);
    if (!qteHit) ballSim.launch(releasePos, clankOffRim(ball, rim));
    player.animator.play(qteHit ? SPORT_CLIP.dunkScoreHang : SPORT_CLIP.jumpLand, {
      onEnd: () => player.animator.play(SPORT_CLIP.idle, { loop: true }),
    });
  }

  async function finishAttempt(ctx: ModeContext, made: boolean): Promise<void> {
    if (finishing) return;
    finishing = true;
    if (made) {
      streak++;
      const mult = multiplier();
      const gained = Math.round(STYLE_PTS[style] * mult * 10) / 10;
      myScore += gained;
      const onFire = streak >= 3;
      SoundKit.play('score', { pitch: 1 + Math.min(streak, STREAK_CAP) * 0.08 });
      if (onFire) SoundKit.play('crowdCheer');
      ctx.feel?.impact?.(0.15 + Math.min(streak, STREAK_CAP) * 0.08);
      ctx.setHud({
        score: `${myScore} – ${rivalScore}`,
        streak: onFire ? `🔥 ${streak}x streak · ${mult.toFixed(1)}×` : streak > 1 ? `${streak}x streak` : '',
        hint: onFire ? 'ON FIRE!' : 'FLUSH! — replay',
      });
      ctx.camDirector.suspended = true;
      await Promise.race([replay.play(rim), new Promise((r) => setTimeout(r, 4000))]);
      ctx.camDirector.suspended = false;
    } else {
      if (streak >= 3) SoundKit.play('crowdGroan'); else SoundKit.play('miss');
      streak = 0;
      ctx.setHud({ hint: 'MISS — rival ball', streak: '' });
    }
    player.animator.play(SPORT_CLIP.dunkLandCrouch, {
      onEnd: () => player.animator.play(SPORT_CLIP.idle, { loop: true }),
    });
    if (myScore >= CFG.target) {
      SoundKit.play('whistle');
      return ctx.end('WIN', myScore, { rivalScore, styleUsed: STYLE_PTS[style], bestStreak: streak });
    }
    await rivalAttempt(ctx);
    if (rivalScore >= CFG.target) { SoundKit.play('whistle'); return ctx.end('LOSS', myScore, { rivalScore }); }
    resetForNextAttempt(ctx);
  }

  function resetForNextAttempt(ctx: ModeContext): void {
    player.root.position.set(0, 0, CFG.startZ);
    player.root.rotation.y = Math.PI;
    player.animator.play(SPORT_CLIP.idle, { loop: true });
    attachBallToHand(ball, player.skeleton, 'RightHand');
    charge = 0; qteHit = false; qteWindowOpen = false; finishing = false;
    ctx.camDirector.snapTo(player.root.position, rim);
    setPhase('approach');
    ctx.setHud({ hint: 'Your ball — drive the lane', charge: 0, slamPulse: false });
  }

  async function rivalAttempt(ctx: ModeContext): Promise<void> {
    setPhase('rivalTurn');
    ctx.setHud({ hint: 'RIVAL BALL' });
    ctx.camDirector.snapTo(rival.root.position, rim);
    rival.animator.play(SPORT_CLIP.dunkLaunchPower, {
      onEnd: () => rival.animator.play(SPORT_CLIP.idle, { loop: true }),
    });
    const t0 = performance.now();
    const from = rival.root.position.clone();
    await new Promise<void>((res) => {
      const obs = ctx.scene.onBeforeRenderObservable.add(() => {
        const k = Math.min(1, (performance.now() - t0) / 1400);
        rival.root.position.x = from.x + (rim.x - from.x) * k;
        rival.root.position.z = from.z + (rim.z + 0.7 - from.z) * k;
        rival.root.position.y = Math.sin(k * Math.PI) * 1.25;
        if (k >= 1) { ctx.scene.onBeforeRenderObservable.remove(obs); res(); }
      });
    });
    if (Math.random() < CFG.rivalMakeChance) {
      rivalScore += 1.5;
      SoundKit.play('crowdGroan', { volume: 0.4 });
      rival.animator.play(SPORT_CLIP.scoreCelebrate, {
        onEnd: () => rival.animator.play(SPORT_CLIP.idle, { loop: true }),
      });
    }
    rival.root.position.set(3.2, 0, CFG.rimZ + 3);
    ctx.setHud({ score: `${myScore} – ${rivalScore}` });
  }

  return def;
})();
