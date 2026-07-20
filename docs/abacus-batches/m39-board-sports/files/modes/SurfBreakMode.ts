// SurfBreakMode v2 — REPLACES the live surf mode (rendered NOTHING, E10).
// Ride a travelling wave: stay in the pocket (just ahead of the lip) to build
// FLOW; CUTBACK snaps turn for points; AIR off the lip when it pulses; wipeout
// if the lip catches you. 90-second sessions.

import { Vector3 } from '@babylonjs/core';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { buildRig, TrickMachine, TRICKS, type BoardRig } from './boardCore';
import { buildSurfBreak, type RideWorld } from './rideWorlds';
import { assertSpawned } from '../core/FrameGuard';
import { RIDE_CONFIG as CFG } from './modeConfigs';

const RUN_SEC = 90;
const POCKET = { min: 2, max: 9 };                       // meters ahead of the lip

export const SurfBreakMode: ModeDefinition = (() => {
  let world: RideWorld, waveLipAt: (t: number) => Vector3;
  let rig: BoardRig, tricks: TrickMachine;
  let t = 0, timeLeft = RUN_SEC, flow = 0;
  let stickX = 0, carve = 0;
  let ended = false, wipedOut = false;

  return {
    modeId: 'surf', mood: 'goldenHour', camPreset: 'board',

    async load(ctx: ModeContext) {
      const built = buildSurfBreak(ctx.scene);            // WORLD FIRST (E10)
      world = built.world; waveLipAt = built.waveLipAt;
      rig = await buildRig(ctx, CFG.heroUrl, new Vector3(0, 0, -22), 0, world.ground, '#ffd75e');
      tricks = new TrickMachine(rig, (h) => ctx.setHud(h));
      assertSpawned(ctx.scene, { hero: rig.char.root, minWorldMeshes: 3, modeId: 'surf' });
      t = 0; timeLeft = RUN_SEC; flow = 0; ended = false; wipedOut = false;
      ctx.objectiveRef = () => waveLipAt(t);
      ctx.setHud({ score: 0, flow: 0, time: RUN_SEC, hint: 'Stay in the pocket ahead of the wave · CUTBACK for points' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'trigger' && e.side === 'R') carve = e.value;
      if (e.t === 'button' && e.pressed && !wipedOut) {
        if (e.btn === 'A') {                              // AIR off the lip
          if (rig.rider.grounded) { rig.rider.jump(0.5 + flow / 200); rig.char.animator.play('jump_up', {}); }
        }
        if (e.btn === 'B') {                              // CUTBACK — snap turn, pays with flow
          rig.char.root.rotation.y += Math.PI * 0.5 * (stickX >= 0 ? 1 : -1);
          tricks.score += 40 + Math.round(flow / 4);
          ctx.feel?.impact?.(0.12);
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

      if (timeLeft <= 0) {
        ended = true;
        return ctx.end('SESSION_END', tricks.score, { bestFlow: Math.round(flow) });
      }

      if (!wipedOut) {
        // the wave carries the rider shoreward; carve adds push
        rig.rider.vel.z += (2.8 + carve * 2.2) * dt;
        rig.rider.update(dt, stickX, carve);

        const ahead = rig.char.root.position.z - lip.z;
        if (ahead < -0.5) {                               // lip caught you
          wipedOut = true;
          tricks.bail();
          ctx.feel?.impact?.(0.5);
          ctx.setHud({ banner: 'WIPEOUT', flow: 0 });
          flow = 0;
          setTimeout(() => {                              // paddle back out
            rig.char.root.position.set(rig.char.root.position.x, 0, lip.z + 6);
            rig.rider.vel.set(0, 0, 0);
            wipedOut = false;
            ctx.setHud({ banner: '' });
          }, 1600);
        } else if (ahead >= POCKET.min && ahead <= POCKET.max) {
          flow = Math.min(200, flow + dt * 22);           // in the pocket
          tricks.score += Math.round(dt * (10 + flow / 10));
          ctx.setHud({ score: tricks.score, flow: Math.round(flow) });
        } else {
          flow = Math.max(0, flow - dt * 30);             // out on the shoulder
          ctx.setHud({ flow: Math.round(flow) });
        }

        const banner = tricks.update(dt);
        if (banner) {
          ctx.setHud({ banner });
          setTimeout(() => ctx.setHud({ banner: '' }), 900);
        }
        rig.char.animator.play(rig.rider.grounded ? (carve > 0.5 ? 'board_tuck' : 'board_ride_idle') : 'board_air', { loop: true });
        rig.char.root.position.x = Math.max(-40, Math.min(40, rig.char.root.position.x));
      }

      ctx.setHud({ time: Math.ceil(timeLeft) });
      ctx.camDirector.update(rig.char.root.position, rig.rider.vel, lip);
    },

    dispose() { rig?.dispose(); world?.dispose(); },
  };
})();

// MODE_VERBS key `surf`: AIR=A · CUTBACK=B · GRAB=X(hold) · CARVE=RT hold
// modeConfigs addition (one line): export const RIDE_CONFIG = { heroUrl: HERO_URL };
