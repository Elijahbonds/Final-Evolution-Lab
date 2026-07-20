// precisionModes v4 — REPLACES the M42 file. Adds CLUTCH: the final
// round/shot/pitch/kick of every mode is flagged as pressure — succeed on it
// and the payout is boosted (1.5x) with a distinct "CLUTCH!" banner and
// sound, mirroring the stakes real sports games put on a match/game point.
// Also wires SoundKit throughout: swing whoosh, make/goal chime, miss/save
// buzz, and a venue-appropriate ambient bed (crowd for stadium sports, quiet
// wind for golf).

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
import { SPORT_CLIP } from '../anim/clipRegistry';
import { SoundKit } from '../audio/SoundKit';
import { PRECISION_CONFIG as CFG } from './modeConfigs';

const CLUTCH_MULT = 1.5;

// ════════════════════════════════════════════════════════════════ TENNIS ══
export const TennisMode: ModeDefinition = (() => {
  let me: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight;
  let round = 0, pts = 0, stickX = 0;
  let incoming = false, swung = false, ended = false;
  const TOTAL = 7;

  function serve(ctx: ModeContext): void {
    round++;
    swung = false; incoming = true;
    const clutch = round === TOTAL;
    const targetX = ((round * 37) % 7) - 3;
    ball.position.set(targetX * 0.4, 1.2, 11);
    flight.launch(ball.position, new Vector3((targetX - ball.position.x) * 0.12, 2.2, -10.5 - round * 0.4));
    ctx.setHud({ round: `${round}/${TOTAL}`, hint: clutch ? 'MATCH POINT — SWING as the ball reaches you' : 'SWING as the ball reaches you' });
  }

  return {
    modeId: 'tennis', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      furniture = buildTennisNet(ctx.scene);
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(0, 0, -10.5), 0, SPORT_CLIP.tennisIdle);
      ball = MeshBuilder.CreateSphere('tball', { diameter: 0.14 }, ctx.scene);
      flight = new Flight(ball, -8.5);
      ctx.objectiveRef = () => ball.position;
      ctx.camDirector.setFixedBehind(me.root.position, 0, 'swing');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 5, modeId: 'tennis' });
      round = 0; pts = 0; ended = false;
      SoundKit.startAmbient('stadium');
      ctx.setHud({ score: 0 });
      serve(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'button' && e.btn === 'A' && e.pressed && incoming && !swung) {
        swung = true;
        SoundKit.play('whoosh');
        me.animator.play(SPORT_CLIP.tennisForehand, {});
        const q = swingQuality(ball.position.z, me.root.position.z + 0.8, 10.5, 0.34);
        if (q <= 0) return;
        incoming = false;
        ctx.feel?.impact?.(0.2 + q * 0.3);
        const clutch = round === TOTAL;
        const gained = Math.round((5 + q * 20) * (clutch ? CLUTCH_MULT : 1));
        pts += gained;
        SoundKit.play('score', { pitch: q > 0.8 ? 1.2 : 1 });
        flight.launch(ball.position, new Vector3(stickX * 4.5, 4 + q * 2.5, 13 + q * 5));
        ctx.setHud({ score: pts, banner: clutch ? `CLUTCH! +${gained}` : q > 0.8 ? `SWEET SPOT +${gained}` : `+${gained}` });
        setTimeout(() => ctx.setHud({ banner: '' }), 800);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      const flying = flight.step(dt);
      me.root.position.x += (ball.position.x - me.root.position.x) * (incoming ? 2.2 : 0) * dt + stickX * 3 * dt;
      me.root.position.x = Math.max(-5, Math.min(5, me.root.position.x));
      if (incoming && ball.position.z <= me.root.position.z - 0.6) {
        incoming = false;
        SoundKit.play('miss');
        ctx.setHud({ banner: 'MISS' });
        setTimeout(() => ctx.setHud({ banner: '' }), 700);
      }
      if (!flying && !incoming) {
        if (round >= TOTAL) { ended = true; SoundKit.play('whistle'); return ctx.end('MATCH_END', pts, { rounds: TOTAL }); }
        setTimeout(() => { if (!ended && !incoming) serve(ctx); }, 700);
        incoming = true;
        ctx.camDirector.update(me.root.position, Vector3.Zero(), ball.position);
        return;
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), ball.position);
    },

    dispose() { me?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); SoundKit.stopAmbient(); },
  };
})();

// ══════════════════════════════════════════════════════════════════ GOLF ══
export const GolfMode: ModeDefinition = (() => {
  let me: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight, reticle: Reticle, meter: PowerMeter;
  let holePos = new Vector3(0, 0, 55);
  let round = 0, pts = 0, stickX = 0, stickY = 0;
  let phase: 'aim' | 'power' | 'flight' = 'aim';
  let ended = false;
  const TOTAL = 3;

  function nextShot(ctx: ModeContext): void {
    round++;
    phase = 'aim';
    holePos = new Vector3(((round * 53) % 21) - 10, 0, 42 + ((round * 31) % 28));
    furniture.forEach((f) => f.dispose());
    furniture = buildGolfGreen(ctx.scene, holePos);
    ball.position.set(0, 0.05, 0.6);
    me.animator.play(SPORT_CLIP.golfAddress, { loop: true });
    const clutch = round === TOTAL;
    ctx.setHud({ round: `${round}/${TOTAL}`, hint: clutch ? 'FINAL SHOT — aim, then SWING twice' : 'Aim with the stick · SWING to start power · SWING again to strike' });
  }

  return {
    modeId: 'golf', mood: 'alpineNoon', camPreset: 'court',

    async load(ctx: ModeContext) {
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(-0.5, 0, 0), 0, SPORT_CLIP.golfAddress);
      ball = MeshBuilder.CreateSphere('gball', { diameter: 0.1 }, ctx.scene);
      flight = new Flight(ball, -9.8);
      reticle = new Reticle(ctx.scene, new Vector3(0, 1.3, 12), { x: 5, y: 1.1 });
      meter = new PowerMeter();
      ctx.objectiveRef = () => holePos;
      ctx.camDirector.setFixedBehind(me.root.position, 0, 'swing');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 6, modeId: 'golf' });
      round = 0; pts = 0; ended = false;
      SoundKit.startAmbient('dojo');
      ctx.setHud({ score: 0 });
      nextShot(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.btn === 'A' && e.pressed) {
        if (phase === 'aim') { phase = 'power'; meter.start(); ctx.setHud({ hint: 'SWING at the top of the wave' }); }
        else if (phase === 'power') {
          const p = meter.stop();
          phase = 'flight';
          SoundKit.play('whoosh', { pitch: 0.9 });
          me.animator.play(SPORT_CLIP.golfSwing, {});
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
          const clutch = round === TOTAL;
          const gained = Math.round((dist < 0.5 ? 100 : Math.max(0, Math.round(60 - dist * 3))) * (clutch ? CLUTCH_MULT : 1));
          pts += gained;
          SoundKit.play(dist < 0.5 ? 'score' : 'uiTick');
          ctx.setHud({ score: pts, banner: dist < 0.5 ? (clutch ? `CLUTCH HOLE OUT! +${gained}` : `HOLED OUT! +${gained}`) : `${dist.toFixed(1)}m out · +${gained}` });
          setTimeout(() => {
            ctx.setHud({ banner: '' });
            if (round >= TOTAL) { ended = true; SoundKit.play('whistle'); ctx.end('CARD_IN', pts, { shots: TOTAL }); }
            else { nextShot(ctx); ctx.camDirector.setFixedBehind(me.root.position, 0, 'swing'); }
          }, 1400);
          phase = 'aim';
        }
        return;
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), reticle.pos);
    },

    dispose() { me?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); reticle?.dispose(); SoundKit.stopAmbient(); },
  };
})();

// ══════════════════════════════════════════════════════════ HOME RUN DERBY ══
export const DerbyMode: ModeDefinition = (() => {
  let me: SpawnedCharacter, pitcher: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight;
  let round = 0, pts = 0, stickY = 0;
  let incoming = false, swung = false, ended = false;
  const TOTAL = 10;

  function pitch(ctx: ModeContext): void {
    round++;
    swung = false; incoming = true;
    pitcher.animator.play(SPORT_CLIP.derbyPitch, { onEnd: () => pitcher.animator.play(SPORT_CLIP.idle, { loop: true }) });
    ball.position.set(0.2, 1.4, 17.5);
    flight.launch(ball.position, new Vector3(-0.1, 1.1, -14 - round * 0.5));
    const clutch = round === TOTAL;
    ctx.setHud({ round: `${round}/${TOTAL}`, hint: clutch ? 'FINAL PITCH — STRIKE as it crosses the plate' : 'STRIKE as it crosses the plate' });
  }

  return {
    modeId: 'baseball', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      furniture = buildPlateAndMound(ctx.scene);
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(-0.7, 0, 0), Math.PI / 2, SPORT_CLIP.derbyStance);
      pitcher = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(0, 0.35, 18), Math.PI, SPORT_CLIP.idle);
      ctx.heroRef = () => me.root;
      ball = MeshBuilder.CreateSphere('bball', { diameter: 0.12 }, ctx.scene);
      flight = new Flight(ball, -6);
      ctx.objectiveRef = () => ball.position;
      ctx.camDirector.setFixedBehind(me.root.position, Math.PI, 'swing');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 5, modeId: 'baseball' });
      round = 0; pts = 0; ended = false;
      SoundKit.startAmbient('stadium');
      ctx.setHud({ score: 0 });
      pitch(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') stickY = e.y;
      if (e.t === 'button' && e.btn === 'A' && e.pressed && incoming && !swung) {
        swung = true;
        SoundKit.play('whoosh');
        me.animator.play(SPORT_CLIP.derbySwing, { onEnd: () => me.animator.play(SPORT_CLIP.derbyStance, { loop: true }) });
        const q = swingQuality(ball.position.z, 0.3, 14, 0.3);
        if (q <= 0) return;
        incoming = false;
        ctx.feel?.impact?.(0.3 + q * 0.5);
        const clutch = round === TOTAL;
        const launch = 0.45 - stickY * 0.3;
        flight.launch(ball.position, new Vector3((Math.random() - 0.5) * 4, 18 * launch * q + 4, 16 + q * 18));
        const distPts = Math.round(q * (80 + launch * 60) * (clutch ? CLUTCH_MULT : 1));
        pts += distPts;
        SoundKit.play('score', { pitch: q > 0.85 ? 1.2 : 1 });
        ctx.setHud({ score: pts, banner: clutch ? `CLUTCH DINGER! +${distPts}` : q > 0.85 ? `DINGER! +${distPts}` : `+${distPts}` });
        setTimeout(() => ctx.setHud({ banner: '' }), 900);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      const flying = flight.step(dt);
      if (incoming && ball.position.z <= -1.2) {
        incoming = false;
        SoundKit.play('miss');
        ctx.setHud({ banner: 'WHIFF' });
        setTimeout(() => ctx.setHud({ banner: '' }), 700);
      }
      if (!flying && !incoming) {
        if (round >= TOTAL) { ended = true; SoundKit.play('whistle'); return ctx.end('DERBY_END', pts, { pitches: TOTAL }); }
        incoming = true;
        setTimeout(() => { if (!ended) pitch(ctx); }, 800);
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), ball.position);
    },

    dispose() { me?.dispose(); pitcher?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); SoundKit.stopAmbient(); },
  };
})();

// ═══════════════════════════════════════════════════════ PENALTY SHOOTOUT ══
export const PenaltyMode: ModeDefinition = (() => {
  let me: SpawnedCharacter, keeper: SpawnedCharacter;
  let furniture: AbstractMesh[] = [];
  let ball: AbstractMesh, flight: Flight, reticle: Reticle, meter: PowerMeter;
  let round = 0, goals = 0, stickX = 0, stickY = 0;
  let phase: 'aim' | 'power' | 'flight' = 'aim';
  let keeperTargetX = 0, ended = false;
  const TOTAL = 5;

  function nextKick(ctx: ModeContext): void {
    round++;
    phase = 'aim';
    ball.position.set(0, 0.11, 0);
    keeper.root.position.set(0, 0, 10.4);
    keeper.animator.play(SPORT_CLIP.keeperIdle, { loop: true });
    me.animator.play(SPORT_CLIP.penaltyIdle, { loop: true });
    const clutch = round === TOTAL;
    ctx.setHud({ round: `${round}/${TOTAL}`, hint: clutch ? 'FINAL KICK — aim, then power up' : 'Aim inside the frame · KICK to power up · KICK to shoot' });
  }

  return {
    modeId: 'soccer', mood: 'stadiumNight', camPreset: 'court',

    async load(ctx: ModeContext) {
      furniture = buildGoal(ctx.scene);
      me = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(-0.4, 0, -1.6), 0, SPORT_CLIP.penaltyIdle);
      keeper = await spawnAthlete(ctx, CFG.heroUrl, new Vector3(0, 0, 10.4), Math.PI, SPORT_CLIP.keeperIdle);
      ctx.heroRef = () => me.root;
      ball = MeshBuilder.CreateSphere('sball', { diameter: 0.22 }, ctx.scene);
      flight = new Flight(ball, -9.8);
      reticle = new Reticle(ctx.scene, new Vector3(0, 1.2, 11), { x: 3.3, y: 1.05 });
      meter = new PowerMeter();
      ctx.objectiveRef = () => new Vector3(0, 1.2, 11);
      ctx.camDirector.setFixedBehind(me.root.position, 0, 'flight');
      assertSpawned(ctx.scene, { hero: me.root, minWorldMeshes: 6, modeId: 'soccer' });
      round = 0; goals = 0; ended = false;
      SoundKit.startAmbient('stadium');
      ctx.setHud({ score: 0 });
      nextKick(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.btn === 'A' && e.pressed) {
        if (phase === 'aim') { phase = 'power'; meter.start(); ctx.setHud({ hint: 'KICK at the top of the wave' }); }
        else if (phase === 'power') {
          const p = meter.stop();
          phase = 'flight';
          SoundKit.play('whoosh');
          me.animator.play(SPORT_CLIP.penaltyStrike, { onEnd: () => me.animator.play(SPORT_CLIP.penaltyIdle, { loop: true }) });
          ctx.feel?.impact?.(0.3 + p * 0.3);
          keeperTargetX = Math.random() < 0.62 ? Math.sign(reticle.pos.x || 0.01) * 2.2 : -Math.sign(reticle.pos.x || 0.01) * 2.2;
          keeper.animator.play(SPORT_CLIP.keeperDive, {});
          const to = reticle.pos.subtract(ball.position).normalize();
          const wobble = (1 - p) * 0.5;
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
          const clutch = round === TOTAL;
          if (scored) {
            goals++;
            ctx.feel?.impact?.(0.5);
            SoundKit.play('score');
            SoundKit.play('crowdCheer');
          } else {
            SoundKit.play(saved ? 'crowdGroan' : 'miss');
          }
          ctx.setHud({
            score: goals,
            banner: scored ? (clutch ? 'CLUTCH GOOOAL!' : 'GOOOAL!') : saved ? 'SAVED' : 'OFF TARGET',
          });
          setTimeout(() => {
            ctx.setHud({ banner: '' });
            if (round >= TOTAL) { ended = true; SoundKit.play('whistle'); ctx.end('SHOOTOUT_END', goals * 20, { goals }); }
            else { nextKick(ctx); ctx.camDirector.setFixedBehind(me.root.position, 0, 'flight'); }
          }, 1300);
          phase = 'aim';
        }
        return;
      }
      ctx.camDirector.update(me.root.position, Vector3.Zero(), reticle.pos);
    },

    dispose() { me?.dispose(); keeper?.dispose(); furniture.forEach((f) => f.dispose()); ball?.dispose(); reticle?.dispose(); SoundKit.stopAmbient(); },
  };
})();
