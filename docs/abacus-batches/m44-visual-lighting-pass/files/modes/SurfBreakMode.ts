// SurfBreakMode v4 — REPLACES the M42 file. Adds SoundKit: cutback whoosh,
// wipeout impact + crowd-groan-style wave crash, flow-building score chime,
// ocean ambient bed.

import { Vector3 } from '@babylonjs/core';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { buildRig, TrickMachine, TRICKS, type BoardRig } from './boardCore';
import { buildSurfBreak, type RideWorld } from './rideWorlds';
import { assertSpawned } from '../core/FrameGuard';
import { SPORT_CLIP } from '../anim/clipRegistry';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import { RIDE_CONFIG as CFG } from './modeConfigs';

const RUN_SEC = 90;
const POCKET = { min: 2, max: 9 };
const MAX_FORWARD_SPEED = 9;
// MAP-SIZE FIX: rideWorlds' wave laps every 140 units of travel (see
// buildSurfBreak's `z = -50 + (t*4.5) % 140`) but the water plane is a
// static 220-unit mesh and, before this fix, only the WAVE's z wrapped —
// the RIDER's absolute z grew without bound. A rider skilled enough to never
// wipe out (the only thing that used to re-anchor position) would ride
// straight off the edge of the world and spend the rest of the 90s session
// coasting over empty space. Fix: wrap the rider by the same 140-unit period
// at the same moment the wave wraps, so the rider↔wave RELATIVE distance
// (the only thing gameplay/scoring actually cares about) never changes, but
// the rider's absolute position stays bounded inside the built world.
const WAVE_LAP = 140;

export const SurfBreakMode: ModeDefinition = (() => {
  let world: RideWorld, waveLipAt: (t: number) => Vector3;
  let rig: BoardRig, tricks: TrickMachine;
  let t = 0, timeLeft = RUN_SEC, flow = 0;
  let stickX = 0, carve = 0;
  let ended = false, wipedOut = false;
  let lapsSeen = 0;

  return {
    modeId: 'surf', mood: 'goldenHour', camPreset: 'board',

    async load(ctx: ModeContext) {
      const built = buildSurfBreak(ctx.scene);
      world = built.world; waveLipAt = built.waveLipAt;
      rig = await buildRig(ctx, CFG.heroUrl, new Vector3(0, 0, -22), 0, world.ground, '#ffd75e');
      tricks = new TrickMachine(rig, (h) => ctx.setHud(h));
      ctx.camDirector.setPreset('board');
      assertSpawned(ctx.scene, { hero: rig.char.root, minWorldMeshes: 4, modeId: 'surf' });
      t = 0; timeLeft = RUN_SEC; flow = 0; ended = false; wipedOut = false; lapsSeen = 0;
      ctx.objectiveRef = () => waveLipAt(t);
      SoundKit.startAmbient('stadium');
      EffectsKit.ambient(ctx.scene, 'venice');
      ctx.setHud({ score: 0, flow: 0, time: RUN_SEC, hint: 'Stay in the pocket ahead of the wave · CUTBACK for points' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'trigger' && e.side === 'R') carve = e.value;
      if (e.t === 'button' && e.pressed && !wipedOut) {
        if (e.btn === 'A') {
          if (rig.rider.grounded) { rig.rider.jump(0.5 + flow / 200); rig.char.animator.play(SPORT_CLIP.boardAir, {}); SoundKit.play('whoosh', { pitch: 1.3, volume: 0.4 }); }
        }
        if (e.btn === 'B') {
          rig.char.root.rotation.y += Math.PI * 0.5 * (stickX >= 0 ? 1 : -1);
          tricks.score += 40 + Math.round(flow / 4);
          ctx.feel?.impact?.(0.12);
          SoundKit.play('whoosh', { pitch: 1.5, volume: 0.35 });
          ctx.setHud({ score: tricks.score, banner: 'CUTBACK' });
          setTimeout(() => ctx.setHud({ banner: '' }), 600);
        }
        if (e.btn === 'X') tricks.start(TRICKS.grab);
      }
      if (e.t === 'button' && !e.pressed && e.btn === 'X') tricks.endGrab();
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      t += dt; timeLeft -= dt;
      const lip = waveLipAt(t);

      // wrap the rider in lockstep with the wave's own wrap — keeps the
      // rider↔wave distance exactly continuous while bounding world-space z
      const lap = Math.floor((t * 4.5) / WAVE_LAP);
      if (lap > lapsSeen) {
        lapsSeen = lap;
        rig.char.root.position.z -= WAVE_LAP;
      }

      if (timeLeft <= 0) {
        ended = true;
        SoundKit.play('whistle');
        return ctx.end('SESSION_END', tricks.score, { bestFlow: Math.round(flow) });
      }

      if (!wipedOut) {
        if (rig.rider.vel.z < MAX_FORWARD_SPEED) {
          rig.rider.vel.z += (2.2 + carve * 1.6) * dt;
          rig.rider.vel.z = Math.min(MAX_FORWARD_SPEED, rig.rider.vel.z);
        }
        rig.rider.update(dt, stickX, carve);

        const ahead = rig.char.root.position.z - lip.z;
        if (ahead < -0.5) {
          wipedOut = true;
          tricks.bail();
          ctx.feel?.impact?.(0.5);
          SoundKit.play('crowdGroan', { volume: 0.5 });
          EffectsKit.burst(ctx.scene, rig.char.root.position.clone(), 'dust');
          ctx.setHud({ banner: 'WIPEOUT', flow: 0 });
          flow = 0;
          setTimeout(() => {
            rig.char.root.position.set(rig.char.root.position.x, 0, lip.z + 6);
            rig.rider.vel.set(0, 0, 0);
            wipedOut = false;
            ctx.setHud({ banner: '' });
          }, 1600);
        } else if (ahead >= POCKET.min && ahead <= POCKET.max) {
          flow = Math.min(200, flow + dt * 22);
          tricks.score += Math.round(dt * (10 + flow / 10));
          ctx.setHud({ score: tricks.score, flow: Math.round(flow) });
        } else {
          flow = Math.max(0, flow - dt * 30);
          ctx.setHud({ flow: Math.round(flow) });
        }

        const banner = tricks.update(dt);
        if (banner) {
          ctx.setHud({ banner });
          setTimeout(() => ctx.setHud({ banner: '' }), 900);
        }
        rig.char.animator.play(rig.rider.grounded ? (carve > 0.5 ? SPORT_CLIP.boardTuck : SPORT_CLIP.boardIdle) : SPORT_CLIP.boardAir, { loop: true });
        rig.char.root.position.x = Math.max(-40, Math.min(40, rig.char.root.position.x));
      }

      ctx.setHud({ time: Math.ceil(timeLeft) });
      const vel = rig.rider.vel;
      const leadVel = vel.lengthSquared() > 0.01 ? vel.scale(1.6) : vel;
      ctx.camDirector.update(rig.char.root.position, leadVel, lip);
    },

    dispose() { rig?.dispose(); world?.dispose(); SoundKit.stopAmbient(); },
  };
})();
