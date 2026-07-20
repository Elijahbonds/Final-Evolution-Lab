// KarateEndlessMode — KO-gated waves (fixes "WAVE CLEAR · 0 KO"), randomized
// mob variety, engagement facing, strikes/hit-reacts/knockdowns via animator.

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../../core/CharacterLibrary';
import { Mob, MobPool, STEERING_PRESETS } from '../../core/MobSteering';
import type { ModeContext, ModeDefinition } from '../../core/ModeHarness';
import type { FelInput } from '../../core/InputBus';
import { KARATE_CONFIG as CFG } from './modeConfigs';

const STRIKES = {
  A: { clip: 'karate_punch_light', dmg: 12, range: 1.3 },
  B: { clip: 'karate_kick_roundhouse', dmg: 18, range: 1.7 },
  Y: { clip: 'karate_punch_heavy', dmg: 24, range: 1.4 },
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
    wave++;
    kos = 0;
    const count = Math.min(CFG.baseEnemies + Math.floor(wave / 2), CFG.maxEnemies);
    for (let i = 0; i < count; i++) {
      const archetype = (['striker', 'rusher', 'striker'] as const)[i % 3];
      const char = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(Math.sin(i * 2.1) * 4, 0, 4 + Math.cos(i * 1.7) * 3),
        tint: CFG.enemyTints[(wave + i) % CFG.enemyTints.length],   // model variety
        scale: 0.92 + ((wave * 7 + i * 13) % 17) / 100,             // size variety
      });
      const mob = new Mob(char, STEERING_PRESETS[archetype]);
      mob.startPursuit();
      pool.add(mob);
      enemies.push({ mob, hp: CFG.enemyHp + wave * 6 });
    }
    ctx.setHud({ wave, enemies: count, hp: playerHp, chi });
  }

  function strike(ctx: ModeContext, key: keyof typeof STRIKES): void {
    if (striking || blocking) return;
    striking = true;
    const s = STRIKES[key];
    // engagement facing: square up to the nearest live enemy before the clip
    const target = nearest();
    if (target) {
      const to = target.mob.char.root.position.subtract(player.root.position);
      player.root.rotation.y = Math.atan2(to.x, to.z);
    }
    player.animator.play(s.clip, {
      onEnd: () => { striking = false; player.animator.play('karate_idle_stance', { loop: true }); },
    });
    // contact lands at the clip's midpoint
    setTimeout(() => {
      const t = nearest();
      if (!t) return;
      const dist = Vector3.Distance(t.mob.char.root.position, player.root.position);
      if (dist > s.range) return;
      t.hp -= s.dmg;
      chi = Math.min(100, chi + 8);
      if (t.hp <= 0) ko(ctx, t);
      else t.mob.char.animator.play('karate_hit_react', {
        onEnd: () => t.mob.char.animator.play('run_forward', { loop: true }),
      });
    }, 140);
  }

  function ko(ctx: ModeContext, e: Enemy): void {
    e.mob.down();                                  // plays karate_knockdown
    enemies = enemies.filter((x) => x !== e);
    kos++; totalKos++;
    ctx.setHud({ kos: totalKos, chi });
    // THE WAVE GATE: advance ONLY when every enemy is KO'd
    if (enemies.length === 0) {
      ctx.setHud({ banner: `WAVE ${wave} CLEAR · ${kos} KO` });
      setTimeout(() => { ctx.setHud({ banner: '' }); void spawnWave(ctx); }, CFG.waveClearBeatMs);
    }
  }

  const nearest = (): Enemy | null =>
    enemies.reduce<Enemy | null>((best, e) => {
      const d = Vector3.Distance(e.mob.char.root.position, player!.root.position);
      return !best || d < Vector3.Distance(best.mob.char.root.position, player!.root.position) ? e : best;
    }, null);

  return {
    modeId: 'karate', mood: 'dojoWarm', camPreset: 'fight',

    async load(ctx) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, { startClip: 'karate_idle_stance' });
      pool = new MobPool();
      wave = 0; totalKos = 0; playerHp = 100; chi = 0; enemies = [];
      await spawnWave(ctx);
    },

    onInput(ctx, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A' || e.btn === 'B' || e.btn === 'Y') strike(ctx, e.btn);
        if (e.btn === 'X') { blocking = true; player.animator.play('karate_block', { loop: true }); }
      }
      if (e.t === 'button' && !e.pressed && e.btn === 'X') {
        blocking = false; player.animator.play('karate_idle_stance', { loop: true });
      }
    },

    update(ctx, dt) {
      const vel = new Vector3(stickX * 3, 0, -stickY * 3);
      if (!striking && !blocking) {
        player.root.position.addInPlace(vel.scale(dt));
        if (vel.lengthSquared() > 0.2) {
          player.root.rotation.y = Math.atan2(vel.x, vel.z);
          player.animator.play('walk_forward', { loop: true });
        }
      }
      const contacts = pool.update(dt, player.root.position, vel);
      for (const mob of contacts) {
        const dmg = blocking ? 3 : 10;
        playerHp -= dmg;
        chi = Math.min(100, chi + 4);
        mob.onContactResolved();
        if (!blocking) player.animator.play('karate_hit_react', {
          onEnd: () => player.animator.play('karate_idle_stance', { loop: true }),
        });
        ctx.setHud({ hp: Math.max(0, playerHp) });
        if (playerHp <= 0) {
          player.animator.play('karate_knockdown', {});
          return ctx.end(`WAVE_${wave}`, totalKos * 100 + wave * 50, { wave, kos: totalKos });
        }
      }
      ctx.camDirector.update(player.root.position, vel,
        nearest()?.mob.char.root.position ?? null);
    },

    dispose() { player?.dispose(); pool?.dispose(); },
  };
})();
