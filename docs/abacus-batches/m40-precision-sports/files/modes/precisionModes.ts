// precisionModes — tennis / golf / baseball / soccer v2, REPLACING the live
// versions (E11: ball logic with no athlete, no furniture, no readable loop).
// All four are built on aimSwingCore; each is a tight, juicy scoring loop
// with a real character swinging, framed by CameraDirector v2 fixed presets.

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh } from '@babylonjs/core';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import type { SpawnedCharacter } from '../core/CharacterLibrary';
import { assertSpawned } from '../core/FrameGuard';
import {
  spawnAthlete, Reticle, PowerMeter, Flight, swingQuality,
  buildTennisNet, buildGolfGreen, buildPlateAndMound, buildGoal,
} from './aimSwingCore';
import { PRECISION_CONFIG as CFG } from './modeConfigs';

// ════════════════════════════════════════════════════════════════ TENNIS ══
// REACT: 7 returns. Ball arrives with varied pace/placement; SWING on time;
// stick at contact steers the return. Depth in court = points.
export const TennisMode: ModeDefinition = (() => {
  let me: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight;
  let round = 0, pts = 0, stickX = 0;
  let incoming = false, swung = false, ended = false;

  function serve(ctx: ModeContext): void {
    round++;
    swung = false; incoming = true;
    const targetX = ((round * 37) % 7) - 3;               // varied placement
    ball.position.set(targetX * 0.4, 1.2, 11);
    flight.launch(ball.position, new Vector3((targetX - ball.position.x) * 0.12, 2.2, -10.5 - round * 0.4));
    ctx.setHud({ round: `RD ${round}/7`, hint: 'SWING as the ball reaches you' });
  }

  return {
    modeId: 'tennis', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      furniture = buildTennisNet(ctx.scene);
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(0, 0, -10.5), 0, 'idle_stand');
      ball = MeshBuilder.CreateSphere('tball', { diameter: 0.14 }, ctx.scene);
      flight = new Flight(ball, -8.5);
      ctx.objectiveRef = () => ball.position;
      ctx.camDirector.setFixedBehind(me.root.position, 0, 'swing');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 5, modeId: 'tennis' });
      round = 0; pts = 0; ended = false;
      ctx.setHud({ score: 0 });
      serve(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'button' && e.btn === 'A' && e.pressed && incoming && !swung) {
        swung = true;
        me.animator.play('tennis_forehand', {});
        const q = swingQuality(ball.position.z, me.root.position.z + 0.8, 10.5, 0.34);
        if (q <= 0) return;                               // early whiff — ball still coming
        incoming = false;
        ctx.feel?.impact?.(0.2 + q * 0.3);
        const gained = Math.round(5 + q * 20);
        pts += gained;
        flight.launch(ball.position, new Vector3(stickX * 4.5, 4 + q * 2.5, 13 + q * 5));
        ctx.setHud({ score: pts, banner: q > 0.8 ? `SWEET SPOT +${gained}` : `+${gained}` });
        setTimeout(() => ctx.setHud({ banner: '' }), 800);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      const flying = flight.step(dt);
      // side-shuffle to meet the ball
      me.root.position.x += (ball.position.x - me.root.position.x) * (incoming ? 2.2 : 0) * dt + stickX * 3 * dt;
      me.root.position.x = Math.max(-5, Math.min(5, me.root.position.x));
      if (incoming && ball.position.z <= me.root.position.z - 0.6) {  // missed it
        incoming = false;
        ctx.setHud({ banner: 'MISS' });
        setTimeout(() => ctx.setHud({ banner: '' }), 700);
      }
      if (!flying && !incoming) {
        if (round >= 7) { ended = true; return ctx.end('MATCH_END', pts, { rounds: 7 }); }
        setTimeout(() => { if (!ended && !incoming) serve(ctx); }, 700);
        incoming = true;                                  // guard double-serve
        ctx.camDirector.update(me.root.position, Vector3.Zero(), ball.position);
        return;
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), ball.position);
    },

    dispose() { me?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); },
  };
})();

// ══════════════════════════════════════════════════════════════════ GOLF ══
// PLACE: 3 shots at a green 40–70m out. Aim reticle → SWING starts the power
// wave → SWING again to strike. Distance-to-pin scoring; hole-out = 100.
export const GolfMode: ModeDefinition = (() => {
  let me: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight, reticle: Reticle, meter: PowerMeter;
  let holePos = new Vector3(0, 0, 55);
  let round = 0, pts = 0, stickX = 0, stickY = 0;
  let phase: 'aim' | 'power' | 'flight' = 'aim';
  let ended = false;

  function nextShot(ctx: ModeContext): void {
    round++;
    phase = 'aim';
    holePos = new Vector3(((round * 53) % 21) - 10, 0, 42 + ((round * 31) % 28));
    furniture.forEach((f) => f.dispose());
    furniture = buildGolfGreen(ctx.scene, holePos);
    ball.position.set(0, 0.05, 0.6);
    me.animator.play('golf_address', { loop: true });
    ctx.setHud({ round: `SHOT ${round}/3`, hint: 'Aim with the stick · SWING to start power · SWING again to strike' });
  }

  return {
    modeId: 'golf', mood: 'alpineNoon', camPreset: 'court',

    async load(ctx: ModeContext) {
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(-0.5, 0, 0), 0, 'golf_address');
      ball = MeshBuilder.CreateSphere('gball', { diameter: 0.1 }, ctx.scene);
      flight = new Flight(ball, -9.8);
      reticle = new Reticle(ctx.scene, new Vector3(0, 1.3, 12), { x: 5, y: 1.1 });
      meter = new PowerMeter();
      ctx.objectiveRef = () => holePos;
      ctx.camDirector.setFixedBehind(me.root.position, 0, 'swing');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 6, modeId: 'golf' });
      round = 0; pts = 0; ended = false;
      ctx.setHud({ score: 0 });
      nextShot(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.btn === 'A' && e.pressed) {
        if (phase === 'aim') { phase = 'power'; meter.start(); ctx.setHud({ hint: 'SWING at the top of the wave' }); }
        else if (phase === 'power') {
          const p = meter.stop();
          phase = 'flight';
          me.animator.play('golf_drive_swing', {});
          ctx.feel?.impact?.(0.25 + p * 0.35);
          const dir = reticle.pos.subtract(new Vector3(0, 0.4, 0)).normalize();
          flight.launch(ball.position, dir.scale(14 + p * 21).add(new Vector3(0, 6 + p * 6, 0)));
          ctx.setHud({ power: Math.round(p * 100), hint: '' });
        }
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      meter.update(dt);
      if (phase === 'power') ctx.setHud({ power: Math.round(meter.value * 100) });
      if (phase === 'aim') reticle.update(dt, stickX, stickY);
      if (phase === 'flight') {
        const flying = flight.step(dt);
        ctx.camDirector.update(ball.position, flight.vel, holePos);
        if (!flying) {
          const dist = Vector3.Distance(new Vector3(ball.position.x, 0, ball.position.z), holePos);
          const gained = dist < 0.5 ? 100 : Math.max(0, Math.round(60 - dist * 3));
          pts += gained;
          ctx.setHud({ score: pts, banner: dist < 0.5 ? 'HOLED OUT! +100' : `${dist.toFixed(1)}m out · +${gained}` });
          setTimeout(() => {
            ctx.setHud({ banner: '' });
            if (round >= 3) { ended = true; ctx.end('CARD_IN', pts, { shots: 3 }); }
            else { nextShot(ctx); ctx.camDirector.setFixedBehind(me.root.position, 0, 'swing'); }
          }, 1400);
          phase = 'aim';                                  // guard re-entry while banner shows
        }
        return;
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), reticle.pos);
    },

    dispose() { me?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); reticle?.dispose(); },
  };
})();

// ══════════════════════════════════════════════════════════ HOME RUN DERBY ══
// REACT: 10 pitches from a visible pitcher. STRIKE on time; launch angle from
// the stick; distance = points; 10 outs-free swings.
export const DerbyMode: ModeDefinition = (() => {
  let me: SpawnedCharacter, pitcher: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight;
  let round = 0, pts = 0, stickY = 0;
  let incoming = false, swung = false, ended = false;

  function pitch(ctx: ModeContext): void {
    round++;
    swung = false; incoming = true;
    pitcher.animator.play('derby_pitch', { onEnd: () => pitcher.animator.play('idle_stand', { loop: true }) });
    ball.position.set(0.2, 1.4, 17.5);
    flight.launch(ball.position, new Vector3(-0.1, 1.1, -14 - round * 0.5));
    ctx.setHud({ round: `PITCH ${round}/10`, hint: 'STRIKE as it crosses the plate' });
  }

  return {
    modeId: 'baseball', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      furniture = buildPlateAndMound(ctx.scene);
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(-0.7, 0, 0), Math.PI / 2, 'derby_bat_stance');
      pitcher = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(0, 0.35, 18), Math.PI, 'idle_stand');
      // heroRef points at the batter (spawnAthlete set it to pitcher last)
      ctx.heroRef = () => me.root;
      ball = MeshBuilder.CreateSphere('bball', { diameter: 0.12 }, ctx.scene);
      flight = new Flight(ball, -6);
      ctx.objectiveRef = () => ball.position;
      ctx.camDirector.setFixedBehind(me.root.position, Math.PI, 'swing');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 5, modeId: 'baseball' });
      round = 0; pts = 0; ended = false;
      ctx.setHud({ score: 0 });
      pitch(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') stickY = e.y;
      if (e.t === 'button' && e.btn === 'A' && e.pressed && incoming && !swung) {
        swung = true;
        me.animator.play('derby_swing', { onEnd: () => me.animator.play('derby_bat_stance', { loop: true }) });
        const q = swingQuality(ball.position.z, 0.3, 14, 0.3);
        if (q <= 0) return;
        incoming = false;
        ctx.feel?.impact?.(0.3 + q * 0.5);
        const launch = 0.45 - stickY * 0.3;               // stick up = higher launch
        flight.launch(ball.position, new Vector3((Math.random() - 0.5) * 4, 18 * launch * q + 4, 16 + q * 18));
        const distPts = Math.round(q * (80 + launch * 60));
        pts += distPts;
        ctx.setHud({ score: pts, banner: q > 0.85 ? `DINGER! +${distPts}` : `+${distPts}` });
        setTimeout(() => ctx.setHud({ banner: '' }), 900);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      const flying = flight.step(dt);
      if (incoming && ball.position.z <= -1.2) {
        incoming = false;
        ctx.setHud({ banner: 'WHIFF' });
        setTimeout(() => ctx.setHud({ banner: '' }), 700);
      }
      if (!flying && !incoming) {
        if (round >= 10) { ended = true; return ctx.end('DERBY_END', pts, { pitches: 10 }); }
        incoming = true;
        setTimeout(() => { if (!ended) pitch(ctx); }, 800);
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), ball.position);
    },

    dispose() { me?.dispose(); pitcher?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); },
  };
})();

// ═══════════════════════════════════════════════════════ PENALTY SHOOTOUT ══
// PLACE: 5 kicks vs a diving keeper. Aim the reticle inside the frame, power
// wave, strike — keeper dives to a zone; beat them to score.
export const PenaltyMode: ModeDefinition = (() => {
  let me: SpawnedCharacter, keeper: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight, reticle: Reticle, meter: PowerMeter;
  let round = 0, goals = 0, stickX = 0, stickY = 0;
  let phase: 'aim' | 'power' | 'flight' = 'aim';
  let keeperTargetX = 0, ended = false;

  function nextKick(ctx: ModeContext): void {
    round++;
    phase = 'aim';
    ball.position.set(0, 0.11, 0);
    keeper.root.position.set(0, 0, 10.4);
    keeper.animator.play('idle_stand', { loop: true });
    me.animator.play('idle_stand', { loop: true });
    ctx.setHud({ round: `KICK ${round}/5`, hint: 'Aim inside the frame · KICK to power up · KICK to shoot' });
  }

  return {
    modeId: 'soccer', mood: 'stadiumNight', camPreset: 'court',

    async load(ctx: ModeContext) {
      furniture = buildGoal(ctx.scene);
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(-0.4, 0, -1.6), 0, 'idle_stand');
      keeper = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(0, 0, 10.4), Math.PI, 'idle_stand');
      ctx.heroRef = () => me.root;
      ball = MeshBuilder.CreateSphere('sball', { diameter: 0.22 }, ctx.scene);
      flight = new Flight(ball, -9.8);
      reticle = new Reticle(ctx.scene, new Vector3(0, 1.2, 11), { x: 3.3, y: 1.05 });
      meter = new PowerMeter();
      ctx.objectiveRef = () => new Vector3(0, 1.2, 11);
      ctx.camDirector.setFixedBehind(me.root.position, 0, 'flight');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 6, modeId: 'soccer' });
      round = 0; goals = 0; ended = false;
      ctx.setHud({ score: '0 GOALS' });
      nextKick(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.btn === 'A' && e.pressed) {
        if (phase === 'aim') { phase = 'power'; meter.start(); ctx.setHud({ hint: 'KICK at the top of the wave' }); }
        else if (phase === 'power') {
          const p = meter.stop();
          phase = 'flight';
          me.animator.play('penalty_strike', { onEnd: () => me.animator.play('idle_stand', { loop: true }) });
          ctx.feel?.impact?.(0.3 + p * 0.3);
          // keeper picks a dive: mostly reads YOUR aim, sometimes guesses wrong
          keeperTargetX = Math.random() < 0.62 ? Math.sign(reticle.pos.x || 0.01) * 2.2 : -Math.sign(reticle.pos.x || 0.01) * 2.2;
          keeper.animator.play(keeperTargetX < 0 ? 'keeper_dive_left' : 'keeper_dive_right', {});
          const to = reticle.pos.subtract(ball.position).normalize();
          const wobble = (1 - p) * 0.5;                   // low power = accurate, high = risky
          flight.launch(ball.position, to.scale(13 + p * 7).add(new Vector3((Math.random() - 0.5) * wobble * 4, 0, 0)));
          ctx.setHud({ power: Math.round(p * 100), hint: '' });
        }
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      meter.update(dt);
      if (phase === 'power') ctx.setHud({ power: Math.round(meter.value * 100) });
      if (phase === 'aim') reticle.update(dt, stickX, stickY);
      if (phase === 'flight') {
        keeper.root.position.x += (keeperTargetX - keeper.root.position.x) * 5 * dt;
        flight.step(dt);
        if (ball.position.z >= 10.9) {
          flight.active = false;
          const inFrame = Math.abs(ball.position.x) < 3.6 && ball.position.y < 2.4 && ball.position.y > 0;
          const saved = Math.abs(ball.position.x - keeper.root.position.x) < 0.9 && ball.position.y < 1.9;
          const scored = inFrame && !saved;
          if (scored) { goals++; ctx.feel?.impact?.(0.5); }
          ctx.setHud({
            score: `${goals} GOALS`,
            banner: scored ? 'GOOOAL!' : saved ? 'SAVED' : 'OFF TARGET',
          });
          setTimeout(() => {
            ctx.setHud({ banner: '' });
            if (round >= 5) { ended = true; ctx.end('SHOOTOUT_END', goals * 20, { goals }); }
            else { nextKick(ctx); ctx.camDirector.setFixedBehind(me.root.position, 0, 'flight'); }
          }, 1300);
          phase = 'aim';
        }
        return;
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), reticle.pos);
    },

    dispose() { me?.dispose(); keeper?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); reticle?.dispose(); },
  };
})();

// modeConfigs addition: export const PRECISION_CONFIG = { heroUrl: HERO_URL };
// Animation aliases needed (M24 alias table; fallback chain → idle_stand):
//   tennis_forehand · golf_address · golf_drive_swing · derby_bat_stance ·
//   derby_swing · derby_pitch · penalty_strike · keeper_dive_left/right
// MODE_VERBS keys (live slugs): tennis{SWING=A}, golf{SWING=A},
//   baseball{STRIKE=A}, soccer{KICK=A} — stick always aims.
