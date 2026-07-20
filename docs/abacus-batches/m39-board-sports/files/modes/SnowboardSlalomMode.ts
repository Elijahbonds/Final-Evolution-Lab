// SnowboardSlalomMode v2 — REPLACES the live snowboard mode (rendered NOTHING,
// E10). Real downhill: inclined piste, 12 slalom gates, trees, gravity-fed
// speed with TUCK, JUMP/SPIN/GRAB airs. Score = gates cleared + trick points;
// missing a gate costs time.

import { Vector3 } from '@babylonjs/core';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { buildRig, TrickMachine, TRICKS, type BoardRig } from './boardCore';
import { buildSlopeRun, type RideWorld } from './rideWorlds';
import { assertSpawned } from '../core/FrameGuard';
import { RIDE_CONFIG as CFG } from './modeConfigs';

export const SnowboardSlalomMode: ModeDefinition = (() => {
  let world: RideWorld, rig: BoardRig, tricks: TrickMachine;
  let nextGate = 0, gatesHit = 0, elapsed = 0;
  let stickX = 0, tuck = 0;
  let ended = false;

  return {
    modeId: 'snowboard', mood: 'alpineNoon', camPreset: 'board',

    async load(ctx: ModeContext) {
      world = buildSlopeRun(ctx.scene);                   // WORLD FIRST (E10)
      rig = await buildRig(ctx, CFG.heroUrl, new Vector3(0, 0.2, 4), 0, world.ground, '#ff6b3d');
      tricks = new TrickMachine(rig, (h) => ctx.setHud(h));
      assertSpawned(ctx.scene, { hero: rig.char.root, minWorldMeshes: 20, modeId: 'snowboard' });
      nextGate = 0; gatesHit = 0; elapsed = 0; ended = false; stickX = 0; tuck = 0;
      ctx.objectiveRef = () => world.markers[nextGate] ?? null;
      ctx.setHud({ score: 0, gates: `0/${world.markers.length}`, hint: 'Steer through the gates · TUCK for speed' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'trigger' && e.side === 'R') tuck = e.value;
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A' && rig.rider.grounded) { rig.rider.jump(0.5 + tuck * 0.5); rig.char.animator.play('jump_up', {}); }
        if (e.btn === 'B') tricks.start(TRICKS.spin);
        if (e.btn === 'X') tricks.start(TRICKS.grab);
        if (e.btn === 'Y') tricks.start(TRICKS.flipA);
      }
      if (e.t === 'button' && !e.pressed && e.btn === 'X') tricks.endGrab();
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      elapsed += dt;
      // gravity does the accelerating; TUCK reduces drag (reuses pump input)
      rig.rider.update(dt, stickX, tuck);

      // gate check: passing the gate's downhill line within its width
      const gate = world.markers[nextGate];
      if (gate) {
        const p = rig.char.root.position;
        if (p.z >= gate.z - 0.3) {
          if (Math.abs(p.x - gate.x) <= 2.0) {
            gatesHit++;
            tricks.score += 100;
            ctx.feel?.impact?.(0.15);
            ctx.setHud({ banner: 'GATE ✓', score: tricks.score });
          } else {
            ctx.setHud({ banner: 'MISSED GATE' });
          }
          setTimeout(() => ctx.setHud({ banner: '' }), 700);
          nextGate++;
          ctx.setHud({ gates: `${gatesHit}/${world.markers.length}` });
        }
      }

      const trickBanner = tricks.update(dt);
      if (trickBanner) {
        ctx.setHud({ banner: trickBanner });
        setTimeout(() => ctx.setHud({ banner: '' }), 900);
      }
      rig.char.animator.play(rig.rider.grounded ? (tuck > 0.5 ? 'board_tuck' : 'board_ride_idle') : 'board_air', { loop: true });
      rig.char.root.position.x = Math.max(-16, Math.min(16, rig.char.root.position.x));

      // finish line = past the last gate
      if (nextGate >= world.markers.length) {
        ended = true;
        const timeBonus = Math.max(0, Math.round((60 - elapsed) * 10));
        return ctx.end('FINISHED', tricks.score + timeBonus, { gatesHit, elapsed: Math.round(elapsed) });
      }
      ctx.camDirector.update(rig.char.root.position, rig.rider.vel, gate ?? null);
    },

    dispose() { rig?.dispose(); world?.dispose(); },
  };
})();

// MODE_VERBS: rename key `snowboard_slalom` → `snowboard` (live slug):
//   JUMP=A · SPIN=B · FLIP=Y · GRAB=X(hold) · TUCK=RT hold
