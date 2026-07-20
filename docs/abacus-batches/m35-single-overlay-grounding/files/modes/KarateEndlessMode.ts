// KarateEndlessMode v2 — REPLACES the M27 file. Fixes from the live audit:
// spawn separation (no overlapping fighters), fight camera actually applied,
// grounded characters (importSanitizer + GroundLock), overlay-driven verbs,
// auto-return-to-stance (no bind pose), KO sink+despawn, KO-gated waves.

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Mob, MobPool, STEERING_PRESETS } from '../core/MobSteering';
import { neverBindPose } from '../anim/importSanitizer';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { KARATE_CONFIG as CFG } from './modeConfigs';

const STANCE = 'karate_idle_stance';
const STRIKES = {
  A: { clip: 'karate_punch_light', dmg: 12, range: 1.4 },
  B: { clip: 'karate_kick_roundhouse', dmg: 18, range: 1.8 },
  Y: { clip: 'karate_punch_heavy', dmg: 24, range: 1.5 },
} as const;

interface Enemy { mob: Mob; hp: number }

export const KarateEndlessMode: ModeDefinition = (() => {
  let player: SpawnedCharacter;
  let pool: MobPool;
  let enemies: Enemy[] = [];
  let wave = 0, kos = 0, totalKos = 0, playerHp = 100, chi = 0;
  let striking = false, blocking = false;
  let stickX = 0, stickY = 0;

  async function spawnWave(ctx: ModeContext): Promise<void> {
    wave++; kos = 0;
    const count = Math.min(CFG.baseEnemies + Math.floor(wave / 2), CFG.maxEnemies);
    for (let i = 0; i < count; i++) {
      // RING SPAWN — enemies enter on a radius, never on top of the player
      const angle = (i / count) * Math.PI * 2 + wave;
      const pos = new Vector3(Math.sin(angle) * 5.5, 0, Math.cos(angle) * 5.5);
      const archetype = (['striker', 'rusher', 'striker'] as const)[i % 3];
      const char = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: pos, yawRad: Math.atan2(-pos.x, -pos.z),   // face the center
        tint: CFG.enemyTints[(wave + i) % CFG.enemyTints.length],
        scale: 0.92 + ((wave * 7 + i * 13) % 17) / 100,
        startClip: STANCE,
      });
      neverBindPose(char.animator, STANCE);
      ctx.groundLock?.track(char.root, char.skeleton);
      const mob = new Mob(char, STEERING_PRESETS[archetype]);
      mob.startPursuit();
      pool.add(mob);
      enemies.push({ mob, hp: CFG.enemyHp + wave * 6 });
    }
    ctx.setHud({ wave, enemies: count, hp: playerHp, chi });
  }

  const nearest = (): Enemy | null =>
    enemies.reduce<Enemy | null>((best, e) =>
      !best || Vector3.Distance(e.mob.char.root.position, player.root.position)
        < Vector3.Distance(best.mob.char.root.position, player.root.position) ? e : best, null);

  function strike(ctx: ModeContext, key: keyof typeof STRIKES): void {
    if (striking || blocking) return;
    striking = true;
    const s = STRIKES[key];
    const target = nearest();
    if (target) {                                        // square up before the clip
      const to = target.mob.char.root.position.subtract(player.root.position);
      player.root.rotation.y = Math.atan2(to.x, to.z);
    }
    player.animator.play(s.clip, { onEnd: () => {
      striking = false;
      player.animator.play(STANCE, { loop: true, fadeSec: 0.12 });
    }});
    setTimeout(() => {                                   // contact at clip midpoint
      const t = nearest();
      if (!t || Vector3.Distance(t.mob.char.root.position, player.root.position) > s.range) return;
      t.hp -= s.dmg;
      chi = Math.min(100, chi + 8);
      ctx.setHud({ chi });
      if (t.hp <= 0) ko(ctx, t);
      else t.mob.char.animator.play('karate_hit_react', {});
    }, 150);
  }

  function ko(ctx: ModeContext, e: Enemy): void {
    enemies = enemies.filter((x) => x !== e);
    kos++; totalKos++;
    e.mob.down();                                        // knockdown clip
    ctx.groundLock?.release(e.mob.char.root);            // allow the despawn sink
    const root = e.mob.char.root;
    const sink = ctx.scene.onBeforeRenderObservable.add(() => {
      root.position.y -= 0.01;
      if (root.position.y < -1.6) {
        ctx.scene.onBeforeRenderObservable.remove(sink);
        e.mob.char.dispose();
      }
    });
    ctx.setHud({ kos: totalKos });
    if (enemies.length === 0) {                          // KO-GATED wave clear
      ctx.setHud({ banner: `WAVE ${wave} CLEAR · ${kos} KO` });
      setTimeout(() => { ctx.setHud({ banner: '' }); void spawnWave(ctx); }, CFG.waveClearBeatMs);
    }
  }

  return {
    modeId: 'karate', mood: 'dojoWarm', camPreset: 'fight',

    async load(ctx) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, 1.5), startClip: STANCE,
      });
      neverBindPose(player.animator, STANCE);
      ctx.groundLock?.track(player.root, player.skeleton);
      pool = new MobPool();
      wave = 0; totalKos = 0; playerHp = 100; chi = 0; enemies = [];
      striking = false; blocking = false;
      await spawnWave(ctx);
    },

    onInput(ctx, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A' || e.btn === 'B' || e.btn === 'Y') strike(ctx, e.btn);
        if (e.btn === 'X') { blocking = true; player.animator.play('karate_block', { loop: true }); }
      }
      if (e.t === 'button' && !e.pressed && e.btn === 'X') {
        blocking = false;
        player.animator.play(STANCE, { loop: true });
      }
    },

    update(ctx, dt) {
      const vel = new Vector3(stickX * 3, 0, -stickY * 3);
      if (!striking && !blocking && vel.lengthSquared() > 0.05) {
        player.root.position.addInPlace(vel.scale(dt));
        // keep the fight on the mat
        player.root.position.x = Math.max(-8, Math.min(8, player.root.position.x));
        player.root.position.z = Math.max(-8, Math.min(8, player.root.position.z));
        player.root.rotation.y = Math.atan2(vel.x, vel.z);
        player.animator.play('walk_forward', { loop: true });
      } else if (!striking && !blocking && vel.lengthSquared() <= 0.05) {
        player.animator.play(STANCE, { loop: true });
      }

      const contacts = pool.update(dt, player.root.position, vel);
      for (const mob of contacts) {
        playerHp -= blocking ? 3 : 10;
        chi = Math.min(100, chi + 4);
        mob.onContactResolved();
        if (!blocking) player.animator.play('karate_hit_react', {});
        ctx.setHud({ hp: Math.max(0, playerHp), chi });
        if (playerHp <= 0) {
          player.animator.play('karate_knockdown', { onEnd: () => {} });   // stay down — run over
          return ctx.end(`WAVE_${wave}`, totalKos * 100 + wave * 50, { wave, kos: totalKos });
        }
      }
      ctx.camDirector.update(player.root.position, vel,
        nearest()?.mob.char.root.position ?? null);
    },

    dispose() { player?.dispose(); pool?.dispose(); },
  };
})();

// NOTE: ModeContext gains `groundLock` (see importSanitizer wiring in README).
// Declare it optional on the interface: `groundLock?: GroundLock`.
