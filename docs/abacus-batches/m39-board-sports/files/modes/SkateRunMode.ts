// SkateRunMode v2 — REPLACES the live skateboard mode, which rendered NOTHING
// (E10). Full rebuild on boardCore + rideWorlds: visible park, rider on a
// board, tricks (POP/KICKFLIP/HEELFLIP/GRAB), rail grinds, combos, 90s runs.

import { Vector3 } from '@babylonjs/core';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { buildRig, TrickMachine, TRICKS, type BoardRig } from './boardCore';
import { buildSkatepark, type RideWorld } from './rideWorlds';
import { assertSpawned } from '../core/FrameGuard';
import { RIDE_CONFIG as CFG } from './modeConfigs';

const RUN_SEC = 90;

export const SkateRunMode: ModeDefinition = (() => {
  let world: RideWorld, rig: BoardRig, tricks: TrickMachine;
  let timeLeft = RUN_SEC;
  let stickX = 0, pump = 0;
  let ended = false;

  return {
    modeId: 'skateboard', mood: 'goldenHour', camPreset: 'board',

    async load(ctx: ModeContext) {
      world = buildSkatepark(ctx.scene);                  // WORLD FIRST (E10)
      rig = await buildRig(ctx, CFG.heroUrl, new Vector3(0, 0, -16), 0, world.ground, '#22d3ee');
      tricks = new TrickMachine(rig, (h) => ctx.setHud(h));
      assertSpawned(ctx.scene, { hero: rig.char.root, minWorldMeshes: 8, modeId: 'skateboard' });
      timeLeft = RUN_SEC; ended = false; stickX = 0; pump = 0;
      ctx.setHud({ score: 0, combo: '', time: RUN_SEC, hint: 'PUMP for speed · POP to ollie · flip in the air' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'trigger' && e.side === 'R') pump = e.value;
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A') {                              // POP: ollie or (in air) start grind attempt
          if (rig.rider.grounded) { rig.rider.jump(0.55 + pump * 0.45); rig.char.animator.play('jump_up', {}); }
          else if (rig.rider.tryGrind(world.grindLines)) {
            tricks.bankGrind(world.grindLines[0]);
            ctx.setHud({ banner: 'GRIND!' });
            ctx.feel?.impact?.(0.3);
          }
        }
        if (e.btn === 'B') tricks.start(TRICKS.flipA);
        if (e.btn === 'Y') tricks.start(TRICKS.flipB);
        if (e.btn === 'X') tricks.start(TRICKS.grab);
      }
      if (e.t === 'button' && !e.pressed && e.btn === 'X') tricks.endGrab();
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      timeLeft -= dt;
      if (timeLeft <= 0) {
        ended = true;
        return ctx.end('RUN_COMPLETE', tricks.score, { runSec: RUN_SEC });
      }
      if (rig.rider.grinding && Math.abs(stickX) > 0.7) rig.rider.dismount();
      rig.rider.update(dt, stickX, pump);
      rig.char.animator.play(
        rig.rider.grinding ? 'board_grind' : rig.rider.grounded ? 'board_ride_idle' : 'board_air',
        { loop: true });
      const banner = tricks.update(dt);
      if (banner) {
        ctx.setHud({ banner });
        if (banner !== 'BAILED') ctx.feel?.impact?.(0.25);
        setTimeout(() => ctx.setHud({ banner: '' }), 900);
      }
      // keep the run inside the park
      rig.char.root.position.x = Math.max(-21, Math.min(21, rig.char.root.position.x));
      rig.char.root.position.z = Math.max(-21, Math.min(21, rig.char.root.position.z));
      ctx.setHud({ time: Math.ceil(timeLeft) });
      ctx.camDirector.update(rig.char.root.position, rig.rider.vel, null);
    },

    dispose() { rig?.dispose(); world?.dispose(); },
  };
})();

// MODE_VERBS (M35 modeVerbs.ts) — ensure the key is `skateboard` (live slug):
//   POP=A · KICKFLIP=B · HEELFLIP=Y · GRAB=X(hold) · PUMP=RT hold
