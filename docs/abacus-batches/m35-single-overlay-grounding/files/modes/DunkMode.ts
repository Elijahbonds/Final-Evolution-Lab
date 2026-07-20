// DunkMode v2 — REPLACES the M27 file. Fixes from the live audit: the mode is
// now touch-first (driven entirely by TouchOverlay verbs: HOLD CHARGE = analog
// charge, release = launch; STYLE cycles the pre-selected dunk; SLAM pulses
// when the window opens), a cinematic watchdog guarantees the sequence can
// NEVER stall (every phase has a hard timeout that auto-resolves as a miss),
// the ball is attached from spawn, and keyboard/gamepad drive the identical
// FelInput events so all three input paths behave the same.

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

// WATCHDOG BUDGETS — no phase may outlive its budget. When one expires the
// attempt auto-resolves as a miss and play continues. Stalling is impossible.
const BUDGET_SEC: Record<Phase, number> = {
  approach: 30,          // dawdling on approach → gentle hint, then auto-gather
  charge: 5,             // held forever → auto-launch at current charge
  cinematic: 4,          // clip/timing failure → force resolve
  resolve: 3,            // physics failure → force miss
  rivalTurn: 6,          // rival AI failure → skip rival's turn
};

export const DunkMode: ModeDefinition = (() => {
  let player: SpawnedCharacter, rival: SpawnedCharacter;
  let ball: AbstractMesh, ballSim: BallSim, replay: DunkReplayRecorder;
  let phase: Phase = 'approach';
  let phaseSec = 0;                                       // watchdog clock
  let style: Style = 'power';
  let charge = 0, clipTime = 0, qteHit = false, qteWindowOpen = false;
  let sinceRelease = 0, releasePos = new Vector3();
  let myScore = 0, rivalScore = 0;
  let finishing = false;                                  // re-entry guard
  const rim = new Vector3(0, CFG.rimHeight, CFG.rimZ);
  const ebState = { inLeftHand: false };
  let stickX = 0, stickY = 0;

  function setPhase(p: Phase): void { phase = p; phaseSec = 0; }

  const def: ModeDefinition = {
    modeId: 'dunk', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, CFG.startZ), yawRad: Math.PI,
        startClip: 'idle_stand',
      });
      neverBindPose(player.animator, 'idle_stand');
      ctx.groundLock?.track(player.root, player.skeleton);
      rival = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(3.2, 0, CFG.rimZ + 3), tint: '#ff2d78',
        startClip: 'idle_stand',
      });
      neverBindPose(rival.animator, 'idle_stand');
      ctx.groundLock?.track(rival.root, rival.skeleton);

      // BALL FROM SPAWN — visible in the player's hand on frame one.
      ball = MeshBuilder.CreateSphere('ball', { diameter: 0.24 }, ctx.scene);
      ballSim = new BallSim(ball, 0.12);
      attachBallToHand(ball, player.skeleton, 'RightHand');
      replay = new DunkReplayRecorder(ctx.scene, player.root, ball, ctx.camera as never);

      myScore = 0; rivalScore = 0; finishing = false;
      setPhase('approach');
      ctx.setHud({
        score: `${myScore} – ${rivalScore}`,
        style: STYLE_LABEL[style],
        hint: 'Drive the lane · HOLD CHARGE to load your jump',
      });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }

      // STYLE pre-select: overlay STYLE button (B) cycles; keyboard dpad picks
      // directly. Both land in the same `style` var — full parity.
      if (e.t === 'button' && e.btn === 'B' && e.pressed && phase !== 'cinematic') {
        style = STYLES[(STYLES.indexOf(style) + 1) % STYLES.length];
        ctx.setHud({ style: STYLE_LABEL[style] });
      }
      if (e.t === 'dpad' && e.pressed) {
        style = e.dir === 'up' ? 'power' : e.dir === 'down' ? 'sig' : 'flashy';
        ctx.setHud({ style: STYLE_LABEL[style] });
      }

      // CHARGE: TouchOverlay's hold button streams trigger R 0→1 and emits a
      // final 0 on release — identical to a gamepad trigger. Release = launch.
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

      // SLAM: only counts inside the window the HUD pulses for.
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
        // jump arc rises with charge; GroundLock never fights this (it only
        // clamps BELOW the floor, and the arc stays above it)
        const k = Math.min(1, clipTime / EASTBAY_TIMING.duration);
        player.root.position.y = Math.sin(k * Math.PI) * (1.05 + charge * 0.55);
        player.root.position.z += (rim.z + 0.6 - player.root.position.z) * 1.6 * dt;

        const wasOpen = qteWindowOpen;
        qteWindowOpen = clipTime >= EASTBAY_TIMING.extend - CFG.qteWindowSec / 2
          && clipTime <= EASTBAY_TIMING.extend + CFG.qteWindowSec / 2;
        // slamPulse drives the overlay's SLAM button glow (TouchOverlay reads
        // it from the HUD stream) — the player SEES the window open.
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

      ctx.camDirector.update(player.root.position, vel, phase === 'approach' ? rim : ball.position);
    },

    dispose() { player?.dispose(); rival?.dispose(); replay?.dispose(); ball?.dispose(); },
  };

  // CINEMATIC WATCHDOG — the core anti-stall guarantee. Whatever breaks
  // (missing clip, physics NaN, an await that never returns), the attempt
  // resolves and play continues. Every trip is logged loudly for the audit.
  function watchdog(ctx: ModeContext): void {
    if (phaseSec <= BUDGET_SEC[phase] || finishing) return;
    console.warn(`[FEL-DUNK] watchdog tripped in phase "${phase}" after ${phaseSec.toFixed(1)}s — auto-resolving`);
    switch (phase) {
      case 'approach':                  // idle too long → nudge into position
        player.root.position.set(0, 0, CFG.gatherZ);
        ctx.setHud({ hint: 'HOLD CHARGE — load your jump' });
        phaseSec = 0;
        break;
      case 'charge': launchDunk(ctx); break;                    // auto-launch
      case 'cinematic': resolveDunk(ctx); break;                // force resolve
      case 'resolve': void finishAttempt(ctx, qteHit); break;   // force finish
      case 'rivalTurn':                                         // skip rival
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
    // onEnd intentionally empty: root motion is driven in update(); the
    // watchdog guarantees resolve even if the clip never fires onEnd.
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
    if (finishing) return;                                // re-entry guard
    finishing = true;
    if (made) {
      myScore += STYLE_PTS[style];
      ctx.setHud({ score: `${myScore} – ${rivalScore}`, hint: 'FLUSH! — replay' });
      ctx.camDirector.suspended = true;
      // replay is best-effort: capped so a broken recorder can't hang the game
      await Promise.race([replay.play(rim), new Promise((r) => setTimeout(r, 4000))]);
      ctx.camDirector.suspended = false;
    } else {
      ctx.setHud({ hint: 'MISS — rival ball' });
    }
    player.animator.play('dunk_land_crouch', {
      onEnd: () => player.animator.play('idle_stand', { loop: true }),
    });
    if (myScore >= CFG.target) return ctx.end('WIN', myScore, { rivalScore, styleUsed: STYLE_PTS[style] });
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
    setPhase('approach');
    ctx.setHud({ hint: 'Your ball — drive the lane', charge: 0, slamPulse: false });
  }

  async function rivalAttempt(ctx: ModeContext): Promise<void> {
    setPhase('rivalTurn');
    rival.animator.play('dunk_launch', {
      onEnd: () => rival.animator.play('idle_stand', { loop: true }),
    });
    await new Promise((r) => setTimeout(r, 1400));
    if (Math.random() < CFG.rivalMakeChance) {
      rivalScore += 1.5;
      rival.animator.play('bball_score_celebrate', {
        onEnd: () => rival.animator.play('idle_stand', { loop: true }),
      });
    }
    ctx.setHud({ score: `${myScore} – ${rivalScore}` });
  }

  return def;
})();

// HUD CONTRACT ADDITIONS (harness HUD component):
//   charge: number (0–100)  → thin charge bar above the deck while charging
//   slamPulse: boolean      → TouchOverlay pulses/glows the SLAM button
// TouchOverlay may read slamPulse via the same setHud stream the HUD uses.
