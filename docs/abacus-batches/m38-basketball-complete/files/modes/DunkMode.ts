// DunkMode v2.1 — REPLACES M35's DunkMode (which replaced M27's). Everything
// from v2 (touch-first charge/launch, SLAM pulse, anti-stall watchdog, ball
// from spawn) PLUS the fixes for what the July live audit actually showed:
// the PLAYER WAS NEVER ON SCREEN. v2.1 guarantees framing from frame one
// (camDirector.snapTo at spawn), registers heroRef/objectiveRef for
// FrameGuard (M37), pans to the rival for their turn so the H2H reads, and
// exposes a real end-of-game result. Basketball works ALL the way through:
// approach → charge → launch → slam → flush/replay → rival turn → to 21 →
// win/loss screen.

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { BallSim } from '../core/BallPhysics';
import { neverBindPose } from '../anim/importSanitizer';
import { attachBallToHand, releaseBall, runEastbayPath, flushThroughRim, clankOffRim } from '../anim/ballRig';
import { EASTBAY_TIMING } from '../anim/authored/timing';
import { DunkReplayRecorder } from '../scene/DunkReplayCam';
import { DUNK_CONFIG as CFG } from './modeConfigs';

type Phase = 'approach' | 'charge' | 'cinematic' | 'resolve' | 'rivalTurn';

const STYLES = ['power', 'flashy', 'sig'] as const;
type Style = (typeof STYLES)[number];
const STYLE_CLIP: Record<Style, string> = {
  power: 'dunk_launch', flashy: 'dunk_360_scoop', sig: 'dunk_360_eastbay',
};
const STYLE_PTS: Record<Style, number> = { power: 1.5, flashy: 2, sig: 3 };
const STYLE_LABEL: Record<Style, string> = { power: 'POWER', flashy: 'FLASHY', sig: 'SIGNATURE' };

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
  let myScore = 0, rivalScore = 0;
  let finishing = false;
  const rim = new Vector3(0, CFG.rimHeight, CFG.rimZ);
  const ebState = { inLeftHand: false };
  let stickX = 0, stickY = 0;

  function setPhase(p: Phase): void { phase = p; phaseSec = 0; }

  const def: ModeDefinition = {
    modeId: 'dunk', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, CFG.startZ), yawRad: Math.PI, startClip: 'idle_stand',
      });
      neverBindPose(player.animator, 'idle_stand');
      ctx.groundLock?.track(player.root, player.skeleton);
      rival = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(3.2, 0, CFG.rimZ + 3), tint: '#ff2d78', startClip: 'idle_stand',
      });
      neverBindPose(rival.animator, 'idle_stand');
      ctx.groundLock?.track(rival.root, rival.skeleton);

      ball = MeshBuilder.CreateSphere('ball', { diameter: 0.24 }, ctx.scene);
      ballSim = new BallSim(ball, 0.12);
      attachBallToHand(ball, player.skeleton, 'RightHand');
      replay = new DunkReplayRecorder(ctx.scene, player.root, ball, ctx.camera as never);

      // v2.1: FRAME ONE IS FRAMED — player + rim both in shot before the
      // first render, and the guards know who the hero is (M37).
      ctx.camDirector.snapTo(player.root.position, rim);
      ctx.heroRef = () => player.root;
      ctx.objectiveRef = () => rim;

      myScore = 0; rivalScore = 0; finishing = false;
      setPhase('approach');
      ctx.setHud({
        score: `${myScore} – ${rivalScore}`, style: STYLE_LABEL[style],
        hint: 'Drive the lane · HOLD CHARGE to load your jump',
      });
    },

    onInput(ctx: ModeContext, e: FelInput) {
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
          player.animator.play('dunk_charge_gather', { loop: true });
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
        player.animator.play(moving ? 'run_forward' : 'idle_stand', { loop: true });
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

      // v2.1: during the rival's turn the camera tells THEIR story
      if (phase === 'rivalTurn') {
        ctx.camDirector.update(rival.root.position, Vector3.Zero(), rim);
      } else {
        ctx.camDirector.update(player.root.position, vel, phase === 'approach' ? rim : ball.position);
      }
    },

    dispose() { player?.dispose(); rival?.dispose(); replay?.dispose(); ball?.dispose(); },
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
    player.animator.play(qteHit ? 'dunk_score_hang' : 'jump_land', {
      onEnd: () => player.animator.play('idle_stand', { loop: true }),
    });
  }

  async function finishAttempt(ctx: ModeContext, made: boolean): Promise<void> {
    if (finishing) return;
    finishing = true;
    if (made) {
      myScore += STYLE_PTS[style];
      ctx.setHud({ score: `${myScore} – ${rivalScore}`, hint: 'FLUSH! — replay' });
      ctx.camDirector.suspended = true;
      await Promise.race([replay.play(rim), new Promise((r) => setTimeout(r, 4000))]);
      ctx.camDirector.suspended = false;
    } else {
      ctx.setHud({ hint: 'MISS — rival ball' });
    }
    player.animator.play('dunk_land_crouch', {
      onEnd: () => player.animator.play('idle_stand', { loop: true }),
    });
    if (myScore >= CFG.target) {
      return ctx.end('WIN', myScore, { rivalScore, styleUsed: STYLE_PTS[style] });
    }
    await rivalAttempt(ctx);
    if (rivalScore >= CFG.target) return ctx.end('LOSS', myScore, { rivalScore });
    resetForNextAttempt(ctx);
  }

  function resetForNextAttempt(ctx: ModeContext): void {
    player.root.position.set(0, 0, CFG.startZ);
    player.root.rotation.y = Math.PI;
    player.animator.play('idle_stand', { loop: true });
    attachBallToHand(ball, player.skeleton, 'RightHand');
    charge = 0; qteHit = false; qteWindowOpen = false; finishing = false;
    ctx.camDirector.snapTo(player.root.position, rim);     // re-frame each possession
    setPhase('approach');
    ctx.setHud({ hint: 'Your ball — drive the lane', charge: 0, slamPulse: false });
  }

  async function rivalAttempt(ctx: ModeContext): Promise<void> {
    setPhase('rivalTurn');
    ctx.setHud({ hint: 'RIVAL BALL' });
    ctx.camDirector.snapTo(rival.root.position, rim);      // cut to the rival
    rival.animator.play('dunk_launch', {
      onEnd: () => rival.animator.play('idle_stand', { loop: true }),
    });
    // rival body arcs to the rim so their attempt is watchable
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
      rival.animator.play('bball_score_celebrate', {
        onEnd: () => rival.animator.play('idle_stand', { loop: true }),
      });
    }
    rival.root.position.set(3.2, 0, CFG.rimZ + 3);
    ctx.setHud({ score: `${myScore} – ${rivalScore}` });
  }

  return def;
})();

// ModeContext additions used here (M37): heroRef/objectiveRef setters and
// camDirector.snapTo — see the M37 batch. HUD contract: charge (0–100) +
// slamPulse (boolean, pulses the SLAM verb button).
