// SkateRunMode v4 — REPLACES the M42 file. No new mechanic here (the manual
// window lives in boardCore.ts, shared by all three ride modes) — this file
// adds SoundKit: unlock on first input, park ambient bed, pop/land/grind
// audio cues layered on top of TrickMachine's own sounds.

import { Vector3 } from '@babylonjs/core';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { buildRig, TrickMachine, TRICKS, type BoardRig } from './boardCore';
import { buildSkatepark, type RideWorld } from './rideWorlds';
import { assertSpawned } from '../core/FrameGuard';
import { SPORT_CLIP } from '../anim/clipRegistry';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import { CoinField } from '../core/Pickups';
import { RIDE_CONFIG as CFG } from './modeConfigs';

const RUN_SEC = 90;

export const SkateRunMode: ModeDefinition = (() => {
  let world: RideWorld, rig: BoardRig, tricks: TrickMachine;
  let coins: CoinField;
  let timeLeft = RUN_SEC;
  let stickX = 0, pump = 0;
  let ended = false;

  return {
    modeId: 'skateboard', mood: 'goldenHour', camPreset: 'board',

    async load(ctx: ModeContext) {
      world = buildSkatepark(ctx.scene);
      rig = await buildRig(ctx, CFG.heroUrl, new Vector3(0, 0, -16), 0, world.ground, '#22d3ee');
      rig.char.animator.play(SPORT_CLIP.boardIdle, { loop: true });
      tricks = new TrickMachine(rig, (h) => ctx.setHud(h));
      assertSpawned(ctx.scene, { hero: rig.char.root, minWorldMeshes: 4, modeId: 'skateboard' });
      timeLeft = RUN_SEC; ended = false; stickX = 0; pump = 0;
      SoundKit.startAmbient('stadium');
      EffectsKit.ambient(ctx.scene, 'park');
      // THE ITEMS FIX: coins scattered across the park + one air arc off the
      // funbox (rewards the risk line, per Pickups.ts's own design intent)
      coins = new CoinField(ctx.scene);
      coins.line(new Vector3(-16, 0.4, -16), new Vector3(16, 0.4, 16), 10);
      coins.line(new Vector3(16, 0.4, -16), new Vector3(-16, 0.4, 16), 10);
      coins.arc(new Vector3(-3, 1.2, -2), new Vector3(3, 1.2, -2), 2.4, 6);
      ctx.setHud({ score: 0, combo: '', time: RUN_SEC, hint: 'PUMP for speed · POP to ollie · flip in the air' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') stickX = e.x;
      if (e.t === 'trigger' && e.side === 'R') pump = e.value;
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A') {
          if (rig.rider.grounded) { rig.rider.jump(0.55 + pump * 0.45); rig.char.animator.play(SPORT_CLIP.boardAir, {}); SoundKit.play('whoosh', { pitch: 1.3, volume: 0.4 }); }
          else if (rig.rider.tryGrind(world.grindLines)) {
            tricks.bankGrind(world.grindLines[0]);
            ctx.setHud({ banner: 'GRIND!' });
            SoundKit.play('powerUp', { volume: 0.4 });
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
        SoundKit.play('whistle');
        return ctx.end('RUN_COMPLETE', tricks.score + coins.collected * 5, { runSec: RUN_SEC, coinsCollected: coins.collected });
      }
      const gained = coins.update(dt, rig.char.root.position);
      if (gained > 0) { SoundKit.play('uiTick', { pitch: 1.4 }); ctx.setHud({ coins: coins.collected }); }
      if (rig.rider.grinding && Math.abs(stickX) > 0.7) rig.rider.dismount();
      rig.rider.update(dt, stickX, pump);
      rig.char.animator.play(
        rig.rider.grinding ? SPORT_CLIP.boardGrind : rig.rider.grounded ? SPORT_CLIP.boardIdle : SPORT_CLIP.boardAir,
        { loop: true });
      const banner = tricks.update(dt);
      if (banner) {
        ctx.setHud({ banner });
        if (banner !== 'BAILED') ctx.feel?.impact?.(0.25);
        setTimeout(() => ctx.setHud({ banner: '' }), 900);
      }
      rig.char.root.position.x = Math.max(-21, Math.min(21, rig.char.root.position.x));
      rig.char.root.position.z = Math.max(-21, Math.min(21, rig.char.root.position.z));
      ctx.setHud({ time: Math.ceil(timeLeft) });
      ctx.camDirector.update(rig.char.root.position, rig.rider.vel, null);
    },

    dispose() { rig?.dispose(); world?.dispose(); coins?.dispose(); SoundKit.stopAmbient(); },
  };
})();
