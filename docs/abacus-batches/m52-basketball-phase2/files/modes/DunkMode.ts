// DunkMode v4 — REPLACES the M47 file. Two broadcast/feel additions on top
// of the judged-contest overhaul (everything from v3 is kept unchanged:
// props, 3-judge scorecard, hype meter, watchdogs, replay):
//   RIM-CAM CUT — as the dunk reaches its rise, the camera CUTS to a
//     baseline angle under the rim for the flush, the way a real contest
//     broadcast cuts from the wide follow to the under-basket camera. Uses
//     the existing camDirector.snapTo API (no new camera code), and the
//     normal follow resumes automatically on resolve.
//   CHAIN METER — back-to-back big scores (24+ from the judges) build a
//     visible CHAIN xN multiplier that pumps extra hype per link (hype
//     already feeds the judges' style score, so chains have real scoring
//     teeth, THPS-combo style). A miss breaks the chain.
// Both additions are animation-independent on purpose — they land whether
// or not the E25 skinning question (see M51) is resolved on your device.

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
import { EffectsKit } from '../visual/EffectsKit';
import { DUNK_CONFIG as CFG } from './modeConfigs';

type Phase = 'approach' | 'charge' | 'cinematic' | 'resolve' | 'judging' | 'rivalTurn' | 'contestOver';
const STYLES = ['power', 'flashy', 'sig'] as const;
type Style = (typeof STYLES)[number];
const PROPS = ['none', 'alleyoop', 'obstacle'] as const;
type Prop = (typeof PROPS)[number];

const STYLE_CLIP: Record<Style, string> = {
  power: SPORT_CLIP.dunkLaunchPower, flashy: SPORT_CLIP.dunkLaunchFlashy, sig: SPORT_CLIP.dunkLaunchSig,
};
const STYLE_LABEL: Record<Style, string> = { power: 'POWER', flashy: 'FLASHY', sig: 'SIGNATURE' };
const PROP_LABEL: Record<Prop, string> = { none: 'NO PROP', alleyoop: 'ALLEY-OOP', obstacle: 'OBSTACLE' };
const STYLE_TIER: Record<Style, number> = { power: 3, flashy: 5.5, sig: 8 };
const PROP_BONUS: Record<Prop, number> = { none: 0, alleyoop: 2, obstacle: 2 };

const DUNKS_PER_ROUND = 2;
const TOTAL_ROUNDS = 2;
const CHAIN_THRESHOLD = 24;                  // judge total that keeps a chain alive

// Three judges, three lenses — same persona trio the Cash Arena uses, tuned
// here for a live single-player reveal (deterministic, no network/LLM dep).
const JUDGES = [
  { id: 'silk', name: 'Silk', w: { difficulty: 0.2, execution: 0.3, style: 0.5 } },
  { id: 'doc', name: 'Doc', w: { difficulty: 0.3, execution: 0.5, style: 0.2 } },
  { id: 'prime', name: 'Prime', w: { difficulty: 0.5, execution: 0.3, style: 0.2 } },
] as const;

interface JudgeScore { name: string; score: number; line: string }
function cannedLine(name: string, score: number): string {
  if (score >= 10) return `${name}: THAT'S A TEN. Hand me the mic.`;
  if (score >= 9) return `${name}: about as good as it gets.`;
  if (score >= 7) return `${name}: real difficulty, clean finish.`;
  return `${name}: gets it done — I've seen bigger.`;
}
function judgeDunk(difficulty: number, execution: number, style: number): JudgeScore[] {
  return JUDGES.map((j) => {
    const raw = difficulty * j.w.difficulty + execution * j.w.execution + style * j.w.style; // 0..10
    const score = Math.max(6, Math.min(10, Math.round(6 + raw * 0.4)));
    return { name: j.name, score, line: cannedLine(j.name, score) };
  });
}

const BUDGET_SEC: Record<Phase, number> = {
  approach: 30, charge: 5, cinematic: 4, resolve: 3, judging: 6, rivalTurn: 8, contestOver: 999,
};

export const DunkMode: ModeDefinition = (() => {
  let player: SpawnedCharacter, rival: SpawnedCharacter, teammate: SpawnedCharacter | null = null;
  let obstacle: AbstractMesh | null = null;
  let ball: AbstractMesh, ballSim: BallSim, replay: DunkReplayRecorder;
  let phase: Phase = 'approach';
  let phaseSec = 0;
  let style: Style = 'power';
  let prop: Prop = 'none';
  let charge = 0, clipTime = 0, qteHit = false, qteWindowOpen = false, qteAccuracy = 0;
  let sinceRelease = 0, releasePos = new Vector3();
  let round = 1, dunkInRound = 0;
  let playerTotal = 0, rivalTotal = 0, hype = 0, chain = 0;
  let lastScores: JudgeScore[] = [];
  let finishing = false;
  let rimCamCut = false;                     // broadcast cut latch (per attempt)
  const rim = new Vector3(0, CFG.rimHeight, CFG.rimZ);
  const ebState = { inLeftHand: false };
  let stickX = 0, stickY = 0;

  function setPhase(p: Phase): void { phase = p; phaseSec = 0; }
  const obstacleClearHeight = 1.35;

  function clearProps(): void {
    obstacle?.dispose(); obstacle = null;
    teammate?.dispose(); teammate = null;
  }

  async function setupProp(ctx: ModeContext): Promise<void> {
    clearProps();
    if (prop === 'obstacle') {
      obstacle = MeshBuilder.CreateBox('dunk_obstacle', { width: 1.1, height: obstacleClearHeight, depth: 0.5 }, ctx.scene);
      obstacle.position.set(0, obstacleClearHeight / 2, CFG.rimZ + 1.4);
    }
    if (prop === 'alleyoop') {
      teammate = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(-3.4, 0, CFG.rimZ + 1.6), tint: '#22d3ee', startClip: SPORT_CLIP.teammateIdle,
      });
      neverBindPose(teammate.animator, SPORT_CLIP.teammateIdle);
      installSafePlay(teammate.animator, 'dunk-teammate');
    }
  }

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
      EffectsKit.ambient(ctx.scene, 'venice');
      EffectsKit.ballTrail(ctx.scene, ball);

      round = 1; dunkInRound = 0; playerTotal = 0; rivalTotal = 0; hype = 0; chain = 0; finishing = false;
      style = 'power'; prop = 'none'; rimCamCut = false;
      setPhase('approach');
      ctx.setHud({
        round: `${round}/${TOTAL_ROUNDS}`, dunkNum: `${dunkInRound + 1}/${DUNKS_PER_ROUND}`,
        score: playerTotal, rivalScore: rivalTotal, style: STYLE_LABEL[style], prop: PROP_LABEL[prop], hype: 0, chain: 0,
        hint: 'Pick your PROP (d-pad) · STYLE to cycle · HOLD CHARGE to load your jump',
      });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }

      if (e.t === 'button' && e.btn === 'B' && e.pressed && phase === 'approach') {
        style = STYLES[(STYLES.indexOf(style) + 1) % STYLES.length];
        ctx.setHud({ style: STYLE_LABEL[style] });
        SoundKit.play('uiTick');
      }
      // d-pad now cycles PROP (repurposed — no new input plumbing needed):
      // up=none, right=alley-oop, down=obstacle
      if (e.t === 'dpad' && e.pressed && phase === 'approach') {
        prop = e.dir === 'up' ? 'none' : e.dir === 'right' ? 'alleyoop' : 'obstacle';
        ctx.setHud({ prop: PROP_LABEL[prop] });
        SoundKit.play('uiTick', { pitch: 1.3 });
        void setupProp(ctx);
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

      if (e.t === 'button' && e.btn === 'A' && e.pressed && qteWindowOpen) {
        qteHit = true;
        const center = EASTBAY_TIMING.extend;
        qteAccuracy = Math.max(0, 1 - Math.abs(clipTime - center) / (CFG.qteWindowSec / 2));
      }
    },

    update(ctx: ModeContext, dt: number) {
      phaseSec += dt;
      watchdog(ctx);
      hype = Math.max(0, hype - dt * 1.5);       // slow decay between dunks

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

        // BROADCAST RIM-CAM CUT: one hard cut to a baseline angle as the
        // rise crests, exactly like the wide→under-basket cut on TV. One
        // snapTo, latched; the normal follow resumes on resolve.
        if (!rimCamCut && clipTime >= EASTBAY_TIMING.extend * 0.55) {
          rimCamCut = true;
          const baseline = new Vector3(rim.x + 2.6, 0.4, rim.z - 1.2);
          ctx.camDirector.snapTo(baseline, player.root.position.add(new Vector3(0, 1.4, 0)));
        }

        // alley-oop: teammate releases the toss partway through the rise;
        // ball arcs from their hand to the player's, deterministic timing —
        // cannot desync, cannot stall.
        if (prop === 'alleyoop' && teammate) {
          const tossAt = EASTBAY_TIMING.extend * 0.45;
          const catchAt = EASTBAY_TIMING.extend * 0.85;
          if (clipTime >= tossAt && clipTime < catchAt) {
            teammate.animator.play(SPORT_CLIP.teammateToss, {});
            const tt = Math.min(1, (clipTime - tossAt) / (catchAt - tossAt));
            ball.position = Vector3.Lerp(
              teammate.root.position.add(new Vector3(0, 1.6, 0)),
              player.root.position.add(new Vector3(0, 1.9, 0)), tt,
            );
          } else if (clipTime >= catchAt) {
            attachBallToHand(ball, player.skeleton, 'RightHand');
          }
        }

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
      } else if (phase === 'cinematic' && rimCamCut) {
        // hold the rim-cam angle through the flush — no per-frame follow
      } else if (phase !== 'judging' && phase !== 'contestOver') {
        ctx.camDirector.update(player.root.position, vel, phase === 'approach' ? rim : ball.position);
      }
    },

    dispose() {
      player?.dispose(); rival?.dispose(); replay?.dispose(); ball?.dispose();
      clearProps(); SoundKit.stopAmbient();
    },
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
      case 'judging': void advanceAfterJudging(ctx); break;
      case 'rivalTurn': void advanceAfterRivalTurn(ctx); break;
    }
  }

  function launchDunk(ctx: ModeContext): void {
    if (phase === 'cinematic') return;
    setPhase('cinematic');
    clipTime = 0; qteHit = false; qteWindowOpen = false; qteAccuracy = 0; ebState.inLeftHand = false;
    rimCamCut = false;
    if (prop !== 'alleyoop') attachBallToHand(ball, player.skeleton, 'RightHand');
    else releaseBall(ball);   // ball waits at the teammate's hand until the toss beat
    SoundKit.play('whoosh', { pitch: 0.85 });
    player.animator.play(STYLE_CLIP[style], { speedRatio: 1, onEnd: () => {} });
  }

  function resolveDunk(ctx: ModeContext): void {
    if (phase === 'resolve') return;
    setPhase('resolve');
    sinceRelease = 0;
    qteWindowOpen = false;
    rimCamCut = false;
    ctx.camDirector.snapTo(player.root.position, rim);   // back to the follow after the cut
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

    if (!made) {
      SoundKit.play('miss');
      hype = Math.max(0, hype - 15);
      chain = 0;                                          // a miss breaks the chain
      lastScores = [];
      ctx.setHud({ banner: 'MISSED — 0 pts this attempt', judgeReveal: null, chain });
      player.animator.play(SPORT_CLIP.dunkLandCrouch, { onEnd: () => player.animator.play(SPORT_CLIP.idle, { loop: true }) });
      setPhase('judging');
      setTimeout(() => { ctx.setHud({ banner: '' }); void advanceAfterJudging(ctx); }, 1400);
      finishing = false;
      return;
    }

    // clear the obstacle? (checked once, at the flush moment — apex already happened)
    let clippedObstacle = false;
    if (prop === 'obstacle' && obstacle) {
      const clearedIt = player.root.position.y + 1.0 >= obstacleClearHeight;
      clippedObstacle = !clearedIt;
    }

    const difficulty = Math.max(0, Math.min(10,
      STYLE_TIER[style] + PROP_BONUS[prop] * (clippedObstacle ? 0.4 : 1) + charge * 2));
    const execution = Math.max(0, Math.min(10, qteAccuracy * 10));
    const styleScore = Math.max(0, Math.min(10, STYLE_TIER[style] * 0.6 + Math.min(2, hype / 50)));

    const scores = judgeDunk(difficulty, execution, styleScore);
    lastScores = scores;
    const dunkTotal = scores.reduce((s, j) => s + j.score, 0);   // 18..30

    // CHAIN: consecutive 24+ dunks build the multiplier; each link pumps
    // extra hype (which feeds the NEXT dunk's style score — real teeth)
    if (dunkTotal >= CHAIN_THRESHOLD) {
      chain++;
      if (chain >= 2) {
        hype = Math.min(100, hype + chain * 5);
        ctx.setHud({ banner: `CHAIN x${chain}!` });
        SoundKit.play('uiTick', { pitch: 1 + chain * 0.15 });
      }
    } else {
      chain = 0;
    }

    playerTotal += dunkTotal;
    hype = Math.min(100, hype + dunkTotal * 2);

    ctx.feel?.impact?.(0.2 + execution / 15);
    SoundKit.play('score', { pitch: 1 + Math.min(1, hype / 100) });
    EffectsKit.burst(ctx.scene, rim, 'net');
    if (dunkTotal >= 27) { SoundKit.play('crowdCheer'); EffectsKit.burst(ctx.scene, player.root.position.add(new Vector3(0, 1.8, 0)), 'confetti'); }
    if (clippedObstacle) ctx.setHud({ banner: 'CLIPPED THE PROP — flushed anyway' });

    ctx.setHud({ score: playerTotal, hype: Math.round(hype), chain, judgeReveal: scores });
    player.animator.play(SPORT_CLIP.dunkLandCrouch, { onEnd: () => player.animator.play(SPORT_CLIP.idle, { loop: true }) });

    ctx.camDirector.suspended = true;
    await Promise.race([replay.play(rim), new Promise((r) => setTimeout(r, 3500))]);
    ctx.camDirector.suspended = false;

    setPhase('judging');
    setTimeout(() => void advanceAfterJudging(ctx), 2600);
    finishing = false;
  }

  async function advanceAfterJudging(ctx: ModeContext): Promise<void> {
    if (phase !== 'judging') return;   // already advanced (watchdog vs normal path race)
    ctx.setHud({ judgeReveal: null, banner: '' });
    dunkInRound++;
    if (dunkInRound < DUNKS_PER_ROUND) {
      resetForNextAttempt(ctx);
      return;
    }
    dunkInRound = 0;
    await rivalRound(ctx);
  }

  function resetForNextAttempt(ctx: ModeContext): void {
    player.root.position.set(0, 0, CFG.startZ);
    player.root.rotation.y = Math.PI;
    player.animator.play(SPORT_CLIP.idle, { loop: true });
    charge = 0; qteHit = false; qteWindowOpen = false; qteAccuracy = 0; rimCamCut = false;
    void setupProp(ctx);
    ctx.camDirector.snapTo(player.root.position, rim);
    setPhase('approach');
    ctx.setHud({
      dunkNum: `${dunkInRound + 1}/${DUNKS_PER_ROUND}`,
      hint: 'Pick your PROP (d-pad) · STYLE to cycle · HOLD CHARGE to load your jump',
      charge: 0, slamPulse: false,
    });
  }

  async function rivalRound(ctx: ModeContext): Promise<void> {
    setPhase('rivalTurn');
    ctx.setHud({ hint: 'RIVAL ROUND', judgeReveal: null });
    for (let i = 0; i < DUNKS_PER_ROUND; i++) {
      ctx.camDirector.snapTo(rival.root.position, rim);
      rival.animator.play(SPORT_CLIP.dunkLaunchPower, { onEnd: () => rival.animator.play(SPORT_CLIP.idle, { loop: true }) });
      const t0 = performance.now();
      const from = rival.root.position.clone();
      await new Promise<void>((res) => {
        const obs = ctx.scene.onBeforeRenderObservable.add(() => {
          const k = Math.min(1, (performance.now() - t0) / 1300);
          rival.root.position.x = from.x + (rim.x - from.x) * k;
          rival.root.position.z = from.z + (rim.z + 0.7 - from.z) * k;
          rival.root.position.y = Math.sin(k * Math.PI) * 1.2;
          if (k >= 1) { ctx.scene.onBeforeRenderObservable.remove(obs); res(); }
        });
      });
      // simulated judged score — comparable range to a real player attempt
      const rDiff = 4 + Math.random() * 5, rExec = 5 + Math.random() * 5, rStyle = 3 + Math.random() * 4;
      const rScores = judgeDunk(rDiff, rExec, rStyle);
      const rTotal = rScores.reduce((s, j) => s + j.score, 0);
      rivalTotal += rTotal;
      SoundKit.play('crowdGroan', { volume: 0.35 });
      rival.animator.play(SPORT_CLIP.scoreCelebrate, { onEnd: () => rival.animator.play(SPORT_CLIP.idle, { loop: true }) });
      ctx.setHud({ rivalScore: rivalTotal, banner: `RIVAL SCORES ${rTotal}` });
      rival.root.position.set(3.2, 0, CFG.rimZ + 3);
      await new Promise((r) => setTimeout(r, 1200));
    }
    ctx.setHud({ banner: '' });
    await advanceAfterRivalTurn(ctx);
  }

  async function advanceAfterRivalTurn(ctx: ModeContext): Promise<void> {
    if (round < TOTAL_ROUNDS) {
      round++;
      ctx.setHud({ round: `${round}/${TOTAL_ROUNDS}`, banner: `ROUND ${round}` });
      setTimeout(() => ctx.setHud({ banner: '' }), 1400);
      resetForNextAttempt(ctx);
      return;
    }
    setPhase('contestOver');
    SoundKit.play('whistle');
    const won = playerTotal >= rivalTotal;
    if (won) { SoundKit.play('crowdCheer'); EffectsKit.burst(ctx.scene, player.root.position.add(new Vector3(0, 2, 0)), 'confetti'); }
    ctx.end(won ? 'CONTEST_WON' : 'CONTEST_LOST', playerTotal, { rivalTotal, rounds: TOTAL_ROUNDS });
  }

  return def;
})();

// HUD CONTRACT — same as M47 (round, dunkNum, score, rivalScore, style, prop,
// hype, charge, slamPulse, hint, banner, judgeReveal) plus NEW:
//   chain: number — 0 when no chain; the bezel should show "CHAIN xN" when ≥2
