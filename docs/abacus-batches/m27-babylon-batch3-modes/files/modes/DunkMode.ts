// DunkMode — the proof mode. Phases: approach → charge → (style pre-selected)
// → cinematic dunk clip with ball hand-to-hand → QTE at rim arrival → flush or
// clank → replay → rival turn → first to 21.

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../../core/CharacterLibrary';
import type { ModeContext, ModeDefinition } from '../../core/ModeHarness';
import type { FelInput } from '../../core/InputBus';
import { BallSim } from '../../core/BallPhysics';
import { attachBallToHand, releaseBall, runEastbayPath, flushThroughRim, clankOffRim } from '../../anim/ballRig';
import { EASTBAY_TIMING } from '../../anim/authored/timing';
import { DunkReplayRecorder } from '../../scene/DunkReplayCam';
import { DUNK_CONFIG as CFG } from './modeConfigs';

type Phase = 'approach' | 'charge' | 'cinematic' | 'resolve' | 'rivalTurn';
type Style = 'power' | 'flashy' | 'sig';
const STYLE_CLIP: Record<Style, string> = {
  power: 'dunk_launch', flashy: 'dunk_360_scoop', sig: 'dunk_360_eastbay',
};
const STYLE_PTS: Record<Style, number> = { power: 1.5, flashy: 2, sig: 3 };

export const DunkMode: ModeDefinition = (() => {
  let player: SpawnedCharacter, rival: SpawnedCharacter;
  let ball: AbstractMesh, ballSim: BallSim, replay: DunkReplayRecorder;
  let phase: Phase = 'approach';
  let style: Style = 'power';
  let charge = 0, clipTime = 0, qteHit = false, qteWindowOpen = false;
  let sinceRelease = 0, releasePos = new Vector3();
  let myScore = 0, rivalScore = 0;
  const rim = new Vector3(0, CFG.rimHeight, CFG.rimZ);
  const ebState = { inLeftHand: false };
  let stickX = 0, stickY = 0;

  const def: ModeDefinition = {
    modeId: 'dunk', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, CFG.startZ), yawRad: Math.PI,
      });
      rival = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(3.2, 0, CFG.rimZ + 3), tint: '#ff2d78',
      });
      ball = MeshBuilder.CreateSphere('ball', { diameter: 0.24 }, ctx.scene);
      ballSim = new BallSim(ball, 0.12);
      attachBallToHand(ball, player.skeleton, 'RightHand');
      replay = new DunkReplayRecorder(ctx.scene, player.root, ball, ctx.camera as never);
      player.animator.play('idle_stand', { loop: true });
      ctx.setHud({ score: `${myScore} – ${rivalScore}`, hint: 'Drive the lane · hold trigger to charge' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'dpad' && e.pressed) {
        style = e.dir === 'up' ? 'power' : e.dir === 'down' ? 'sig' : 'flashy';
        ctx.setHud({ style: style.toUpperCase() });
      }
      if (e.t === 'trigger' && e.side === 'R') {
        if (phase === 'approach' && e.value > 0.02) { phase = 'charge'; player.animator.play('dunk_charge_gather', { loop: true }); }
        if (phase === 'charge') {
          charge = e.value;
          if (e.value === 0) launchDunk(ctx);      // release = takeoff
        }
      }
      if (e.t === 'button' && e.btn === 'A' && e.pressed && qteWindowOpen) qteHit = true;
    },

    update(ctx: ModeContext, dt: number) {
      const vel = new Vector3(stickX * 4, 0, -Math.max(0, -stickY) * 5 - 2);
      if (phase === 'approach') {
        player.root.position.addInPlace(vel.scale(dt));
        player.root.position.z = Math.max(player.root.position.z, CFG.gatherZ);
        const moving = Math.hypot(vel.x, vel.z) > 2.5;
        player.animator.play(moving ? 'run_forward' : 'idle_stand', { loop: true });
        if (player.root.position.z <= CFG.gatherZ + 0.2) ctx.setHud({ hint: 'HOLD trigger — charge your jump' });
      }
      if (phase === 'cinematic') {
        clipTime += dt;
        if (style === 'sig') runEastbayPath(ball, player.skeleton, clipTime, ebState);
        // rise the body along the jump arc while the clip plays
        const k = Math.min(1, clipTime / EASTBAY_TIMING.duration);
        player.root.position.y = Math.sin(k * Math.PI) * (1.05 + charge * 0.55);
        player.root.position.z += (rim.z + 0.6 - player.root.position.z) * 1.6 * dt;
        // QTE window opens at rim arrival beat
        qteWindowOpen = clipTime >= EASTBAY_TIMING.extend - CFG.qteWindowSec / 2
          && clipTime <= EASTBAY_TIMING.extend + CFG.qteWindowSec / 2;
        ctx.setHud({ hint: qteWindowOpen ? 'SLAM! — PRESS A' : 'RISE…' });
        if (clipTime >= EASTBAY_TIMING.extend + CFG.qteWindowSec / 2) resolveDunk(ctx);
      }
      if (phase === 'resolve') {
        sinceRelease += dt;
        if (qteHit) {
          if (flushThroughRim(ball, rim, releasePos, sinceRelease)) finishAttempt(ctx, true);
        } else {
          ballSim.step(dt);
          if (sinceRelease > 1.2) finishAttempt(ctx, false);
        }
      }
      ctx.camDirector.update(player.root.position, vel, phase === 'approach' ? rim : ball.position);
    },

    dispose() { player?.dispose(); rival?.dispose(); replay?.dispose(); ball?.dispose(); },
  };

  function launchDunk(ctx: ModeContext): void {
    phase = 'cinematic'; clipTime = 0; qteHit = false; ebState.inLeftHand = false;
    attachBallToHand(ball, player.skeleton, 'RightHand');
    player.animator.play(STYLE_CLIP[style], { speedRatio: 1, onEnd: () => {} });
  }

  function resolveDunk(ctx: ModeContext): void {
    phase = 'resolve'; sinceRelease = 0;
    releasePos.copyFrom(ball.getAbsolutePosition());
    releaseBall(ball);
    if (!qteHit) { ballSim.launch(releasePos, clankOffRim(ball, rim)); }
    player.animator.play(qteHit ? 'dunk_score_hang' : 'jump_land');
  }

  async function finishAttempt(ctx: ModeContext, made: boolean): Promise<void> {
    if (made) {
      myScore += STYLE_PTS[style];
      ctx.setHud({ score: `${myScore} – ${rivalScore}`, hint: 'REPLAY — tap to skip' });
      ctx.camDirector.suspended = true;
      await replay.play(rim);
      ctx.camDirector.suspended = false;
    } else {
      ctx.setHud({ hint: 'MISS — rival ball' });
    }
    player.animator.play('dunk_land_crouch', { onEnd: () => player.animator.play('idle_stand', { loop: true }) });
    if (myScore >= CFG.target) return ctx.end('WIN', myScore, { rivalScore, styleUsed: STYLE_PTS[style] });
    await rivalAttempt(ctx);
    if (rivalScore >= CFG.target) return ctx.end('LOSS', myScore, { rivalScore });
    player.root.position.set(0, 0, CFG.startZ);
    player.root.rotation.y = Math.PI;
    attachBallToHand(ball, player.skeleton, 'RightHand');
    phase = 'approach';
    ctx.setHud({ hint: 'Your ball — drive the lane' });
  }

  async function rivalAttempt(ctx: ModeContext): Promise<void> {
    phase = 'rivalTurn';
    rival.animator.play('dunk_launch', {});
    await new Promise((r) => setTimeout(r, 1400));
    if (Math.random() < CFG.rivalMakeChance) {
      rivalScore += 1.5;
      rival.animator.play('bball_score_celebrate', {});
    }
    ctx.setHud({ score: `${myScore} – ${rivalScore}` });
  }

  return def;
})();
