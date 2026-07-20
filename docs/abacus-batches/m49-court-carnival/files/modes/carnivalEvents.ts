// carnivalEvents — the four quick bursts Court Carnival rotates through.
// Each event is deliberately SIMPLE (a Mario Party minigame is 15-20
// seconds of one clear verb, not a full mode) and, to keep this reliable,
// each one reuses infrastructure this project already owns and has proven
// out: the skatepark world + trick machine from board sports, the goal prop
// + aim/power core from precision sports, the hoop from basketball, and a
// stationary target character from the shared character pipeline. Nothing
// here is a new physics or rendering system — it's the existing toolkit
// pointed at short, punchy objectives.

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh, Scene } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { VenueKit } from '../visual/VenueKit';
import { buildSkatepark } from './rideWorlds';
import { buildRig, TrickMachine, TRICKS, type BoardRig } from './boardCore';
import { buildGoal, Reticle, PowerMeter, Flight } from './aimSwingCore';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import type { ModeContext } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { DUNK_CONFIG as SHARED_CFG } from './modeConfigs';

export interface CarnivalEvent {
  id: string;
  title: string;
  durationSec: number;
  pointsPerUnit: number;         // raw score → Carnival Points
  rivalRange: [number, number];  // plausible raw-score range for the simulated rival
  build(ctx: ModeContext): Promise<void>;
  onInput(ctx: ModeContext, e: FelInput): void;
  /** advance the event; return the current raw score. */
  tick(ctx: ModeContext, dt: number): number;
  teardown(): void;
}

const cfg = { heroUrl: SHARED_CFG.heroUrl };

// ── SLAM RUSH — as many dunks as you can charge-and-release in the clock ──
export function slamRush(): CarnivalEvent {
  let player: SpawnedCharacter, ball: AbstractMesh;
  let charging = false, charge = 0, makes = 0, cooldown = 0;
  const rim = new Vector3(0, 3.05, -0.6);

  return {
    id: 'slam_rush', title: 'SLAM RUSH', durationSec: 20, pointsPerUnit: 12, rivalRange: [4, 9],
    async build(ctx) {
      VenueKit.buildCourt(ctx.scene, 'venice');
      player = await CharacterLibrary.spawn(ctx.scene, cfg.heroUrl, { position: new Vector3(0, 0, 2.2), yawRad: Math.PI, startClip: SPORT_CLIP.idle });
      neverBindPose(player.animator, SPORT_CLIP.idle); installSafePlay(player.animator, 'carnival-slam');
      ctx.groundLock?.track(player.root, player.skeleton);
      ball = MeshBuilder.CreateSphere('carn_ball', { diameter: 0.24 }, ctx.scene);
      makes = 0; charging = false; charge = 0; cooldown = 0;
      ctx.heroRef = () => player.root;
      ctx.objectiveRef = () => rim;
      ctx.camDirector.setPreset('court');
      ctx.camDirector.snapTo(player.root.position, rim);
      ctx.setHud({ hint: 'HOLD CHARGE, release near the top for a make' });
    },
    onInput(ctx, e) {
      if (e.t === 'trigger' && e.side === 'R') {
        if (e.value > 0.02) { charging = true; charge = Math.max(charge, e.value); player.animator.play(SPORT_CLIP.dunkChargeGather, { loop: true }); }
        if (e.value === 0 && charging && cooldown <= 0) {
          charging = false;
          const quality = 1 - Math.abs(charge - 0.85);   // sweet spot near-full charge
          const made = Math.random() < Math.max(0.15, Math.min(0.95, quality * 1.3));
          player.animator.play(SPORT_CLIP.dunkLaunchPower, { onEnd: () => player.animator.play(SPORT_CLIP.idle, { loop: true }) });
          if (made) {
            makes++;
            SoundKit.play('score', { pitch: 1.1 }); EffectsKit.burst(ctx.scene, rim, 'net');
            ctx.setHud({ banner: `MAKE ${makes}` });
          } else { SoundKit.play('miss'); ctx.setHud({ banner: 'MISS' }); }
          setTimeout(() => ctx.setHud({ banner: '' }), 400);
          charge = 0; cooldown = 0.5;
        }
      }
    },
    tick(_ctx, dt) { cooldown = Math.max(0, cooldown - dt); return makes; },
    teardown() { player?.dispose(); ball?.dispose(); },
  };
}

// ── STRIKE STORM — land as many strikes as you can on a training bag ──────
export function strikeStorm(): CarnivalEvent {
  let player: SpawnedCharacter, bag: SpawnedCharacter;
  let hits = 0, striking = false;

  return {
    id: 'strike_storm', title: 'STRIKE STORM', durationSec: 15, pointsPerUnit: 8, rivalRange: [10, 22],
    async build(ctx) {
      VenueKit.buildDojo(ctx.scene);
      player = await CharacterLibrary.spawn(ctx.scene, cfg.heroUrl, { position: new Vector3(0, 0, 1.4), startClip: SPORT_CLIP.karateStance });
      neverBindPose(player.animator, SPORT_CLIP.karateStance); installSafePlay(player.animator, 'carnival-strike');
      ctx.groundLock?.track(player.root, player.skeleton);
      bag = await CharacterLibrary.spawn(ctx.scene, cfg.heroUrl, { position: new Vector3(0, 0, 0), tint: '#8b1e2d', startClip: SPORT_CLIP.karateStance });
      neverBindPose(bag.animator, SPORT_CLIP.karateStance); installSafePlay(bag.animator, 'carnival-bag');
      hits = 0; striking = false;
      ctx.heroRef = () => player.root;
      ctx.camDirector.setPreset('fight');
      ctx.camDirector.snapTo(player.root.position, bag.root.position);
      ctx.setHud({ hint: 'Mash JAB / KICK / HEAVY on the bag' });
    },
    onInput(ctx, e) {
      if (e.t === 'button' && e.pressed && !striking && (e.btn === 'A' || e.btn === 'B' || e.btn === 'Y')) {
        striking = true;
        const clip = e.btn === 'A' ? SPORT_CLIP.karateJab : e.btn === 'B' ? SPORT_CLIP.karateKick : SPORT_CLIP.karateHeavy;
        player.animator.play(clip, { onEnd: () => { striking = false; player.animator.play(SPORT_CLIP.karateStance, { loop: true }); } });
        hits++;
        bag.animator.play(SPORT_CLIP.karateHitReact, { onEnd: () => bag.animator.play(SPORT_CLIP.karateStance, { loop: true }) });
        SoundKit.play('impact', { pitch: 1.2, volume: 0.35 });
        EffectsKit.burst(ctx.scene, bag.root.position.add(new Vector3(0, 1.1, 0)), 'dust');
        ctx.setHud({ banner: `${hits}` });
      }
    },
    tick() { return hits; },
    teardown() { player?.dispose(); bag?.dispose(); },
  };
}

// ── TRICK GAUNTLET — chain skate tricks for score, reusing boardCore as-is ─
export function trickGauntlet(): CarnivalEvent {
  let world: ReturnType<typeof buildSkatepark>, rig: BoardRig, tricks: TrickMachine;
  let stickX = 0, pump = 0;

  return {
    id: 'trick_gauntlet', title: 'TRICK GAUNTLET', durationSec: 20, pointsPerUnit: 0.4, rivalRange: [300, 900],
    async build(ctx) {
      world = buildSkatepark(ctx.scene);
      rig = await buildRig(ctx, cfg.heroUrl, new Vector3(0, 0, -6), 0, world.ground, '#ffd75e');
      tricks = new TrickMachine(rig, (h) => ctx.setHud(h));
      stickX = 0; pump = 0;
      ctx.setHud({ hint: 'POP, flip in the air, chain combos before you land' });
    },
    onInput(ctx, e) {
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'trigger' && e.side === 'R') pump = e.value;
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A' && rig.rider.grounded) rig.rider.jump(0.6);
        if (e.btn === 'B') tricks.start(TRICKS.flipA);
        if (e.btn === 'Y') tricks.start(TRICKS.flipB);
        if (e.btn === 'X') tricks.start(TRICKS.spin);
      }
    },
    tick(ctx, dt) {
      rig.rider.update(dt, stickX, pump);
      rig.char.animator.play(rig.rider.grounded ? SPORT_CLIP.boardIdle : SPORT_CLIP.boardAir, { loop: true });
      tricks.update(dt);
      rig.char.root.position.x = Math.max(-20, Math.min(20, rig.char.root.position.x));
      rig.char.root.position.z = Math.max(-20, Math.min(20, rig.char.root.position.z));
      ctx.camDirector.update(rig.char.root.position, rig.rider.vel, null);
      return tricks.score;
    },
    teardown() { rig?.dispose(); world?.dispose(); },
  };
}

// ── HOT SHOT — quick-fire shots on goal, reusing aimSwingCore as-is ───────
export function hotShot(): CarnivalEvent {
  let player: SpawnedCharacter, ball: AbstractMesh, reticle: Reticle, meter: PowerMeter, flight: Flight;
  let goal: AbstractMesh[] = [];
  let goals = 0, phase: 'aim' | 'power' | 'flight' = 'aim', stickX = 0, stickY = 0;
  const goalCenter = new Vector3(0, 1.2, 11);

  return {
    id: 'hot_shot', title: 'HOT SHOT', durationSec: 15, pointsPerUnit: 15, rivalRange: [3, 7],
    async build(ctx) {
      VenueKit.buildField(ctx.scene, 'pitch');
      goal = buildGoal(ctx.scene);
      player = await CharacterLibrary.spawn(ctx.scene, cfg.heroUrl, { position: new Vector3(0, 0, 0), startClip: SPORT_CLIP.penaltyIdle });
      neverBindPose(player.animator, SPORT_CLIP.penaltyIdle); installSafePlay(player.animator, 'carnival-hotshot');
      ball = MeshBuilder.CreateSphere('carn_sball', { diameter: 0.22 }, ctx.scene);
      flight = new Flight(ball, -9.8);
      reticle = new Reticle(ctx.scene, goalCenter, { x: 3.3, y: 1.05 });
      meter = new PowerMeter();
      goals = 0; phase = 'aim';
      ctx.heroRef = () => player.root;
      ctx.camDirector.setFixedBehind(player.root.position, 0, 'flight');
      ctx.setHud({ hint: 'Aim, KICK to power, KICK to shoot — as many as you can' });
    },
    onInput(ctx, e) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.btn === 'A' && e.pressed) {
        if (phase === 'aim') { phase = 'power'; meter.start(); }
        else if (phase === 'power') {
          const p = meter.stop(); phase = 'flight';
          player.animator.play(SPORT_CLIP.penaltyStrike, { onEnd: () => player.animator.play(SPORT_CLIP.penaltyIdle, { loop: true }) });
          const to = reticle.pos.subtract(ball.position).normalize();
          flight.launch(ball.position, to.scale(13 + p * 7).add(new Vector3(0, 0, 0)));
        }
      }
    },
    tick(ctx, dt) {
      meter.update(dt);
      if (phase === 'aim') reticle.update(dt, stickX, stickY);
      if (phase === 'flight') {
        flight.step(dt);
        if (ball.position.z >= 10.9) {
          flight.active = false;
          if (Math.abs(ball.position.x) < 3.6 && ball.position.y < 2.4) { goals++; SoundKit.play('score'); EffectsKit.burst(ctx.scene, goalCenter, 'confetti'); }
          else SoundKit.play('miss');
          ball.position.set(0, 0.11, 0);
          phase = 'aim';
        }
      }
      return goals;
    },
    teardown() { player?.dispose(); ball?.dispose(); reticle?.dispose(); goal.forEach((g) => g.dispose()); },
  };
}

export function allCarnivalEvents(): CarnivalEvent[] {
  return [slamRush(), strikeStorm(), trickGauntlet(), hotShot()];
}
