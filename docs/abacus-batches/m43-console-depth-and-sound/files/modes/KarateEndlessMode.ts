// KarateEndlessMode v4 — REPLACES the M42 file. Adds the console-fighting-
// game mechanic this mode was missing: the chi meter has been visibly
// tracked since M27 but never DID anything — every real fighting game gives
// its meter a payoff. At 100 chi, the HEAVY input (Y) becomes a FINISHER: a
// screen-shaking, crowd-popping special that hits every nearby enemy hard
// and resets the meter. Also wires SoundKit (whoosh on every swing, impact
// bundle on every landed hit — this mode never called ctx.feel?.impact until
// now — dojo ambient bed, crowd cheer on KOs and finishers).

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Mob, MobPool, STEERING_PRESETS } from '../core/MobSteering';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { SoundKit } from '../audio/SoundKit';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { KARATE_CONFIG as CFG } from './modeConfigs';

const STANCE = SPORT_CLIP.karateStance;
const CHI_MAX = 100;
const STRIKES = {
  A: { clip: SPORT_CLIP.karateJab,  dmg: 12, range: 1.4 },
  B: { clip: SPORT_CLIP.karateKick, dmg: 18, range: 1.8 },
  Y: { clip: SPORT_CLIP.karateHeavy, dmg: 24, range: 1.5 },
} as const;
const FINISHER = { dmg: 60, range: 2.6 };

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
      const angle = (i / count) * Math.PI * 2 + wave;
      const pos = new Vector3(Math.sin(angle) * 5.5, 0, Math.cos(angle) * 5.5);
      const archetype = (['striker', 'rusher', 'striker'] as const)[i % 3];
      const char = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: pos, yawRad: Math.atan2(-pos.x, -pos.z),
        tint: CFG.enemyTints[(wave + i) % CFG.enemyTints.length],
        scale: 0.92 + ((wave * 7 + i * 13) % 17) / 100,
        startClip: STANCE,
      });
      neverBindPose(char.animator, STANCE);
      installSafePlay(char.animator, 'karate-enemy');
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

  function gainChi(ctx: ModeContext, amount: number): void {
    const was = chi >= CHI_MAX;
    chi = Math.min(CHI_MAX, chi + amount);
    ctx.setHud({ chi });
    if (chi >= CHI_MAX && !was) {
      SoundKit.play('powerUp');
      ctx.setHud({ hint: 'FINISHER READY — HEAVY to unleash' });
    }
  }

  function strike(ctx: ModeContext, key: keyof typeof STRIKES): void {
    if (striking || blocking) return;
    striking = true;
    const finisherReady = key === 'Y' && chi >= CHI_MAX;
    const s = STRIKES[key];
    const target = nearest();
    if (target) {
      const to = target.mob.char.root.position.subtract(player.root.position);
      player.root.rotation.y = Math.atan2(to.x, to.z);
    }
    SoundKit.play('whoosh', { pitch: finisherReady ? 0.75 : 1 });
    player.animator.play(s.clip, { onEnd: () => {
      striking = false;
      player.animator.play(STANCE, { loop: true, fadeSec: 0.12 });
    }});
    setTimeout(() => {
      if (finisherReady) {
        // FINISHER: hits every enemy in range, resets chi, big feedback
        const hit = enemies.filter((e) => Vector3.Distance(e.mob.char.root.position, player.root.position) <= FINISHER.range);
        if (hit.length) {
          ctx.setHud({ banner: 'FINISHER!' });
          SoundKit.play('crowdCheer');
          ctx.feel?.impact?.(1.0);
          setTimeout(() => ctx.setHud({ banner: '' }), 900);
          for (const t of hit.slice()) {
            t.hp -= FINISHER.dmg;
            if (t.hp <= 0) ko(ctx, t); else t.mob.char.animator.play(SPORT_CLIP.karateHitReact, {});
          }
        }
        chi = 0;
        ctx.setHud({ chi, hint: '' });
        return;
      }
      const t = nearest();
      if (!t || Vector3.Distance(t.mob.char.root.position, player.root.position) > s.range) return;
      t.hp -= s.dmg;
      ctx.feel?.impact?.(key === 'Y' ? 0.5 : 0.3);
      gainChi(ctx, 8);
      if (t.hp <= 0) ko(ctx, t);
      else t.mob.char.animator.play(SPORT_CLIP.karateHitReact, {});
    }, 150);
  }

  function ko(ctx: ModeContext, e: Enemy): void {
    enemies = enemies.filter((x) => x !== e);
    kos++; totalKos++;
    e.mob.down();
    ctx.groundLock?.release(e.mob.char.root);
    const root = e.mob.char.root;
    const sink = ctx.scene.onBeforeRenderObservable.add(() => {
      root.position.y -= 0.01;
      if (root.position.y < -1.6) {
        ctx.scene.onBeforeRenderObservable.remove(sink);
        e.mob.char.dispose();
      }
    });
    SoundKit.play('crowdCheer', { volume: 0.6 });
    ctx.setHud({ kos: totalKos });
    if (enemies.length === 0) {
      SoundKit.play('whistle');
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
      installSafePlay(player.animator, 'karate-player');
      ctx.groundLock?.track(player.root, player.skeleton);
      ctx.heroRef = () => player.root;
      pool = new MobPool();
      wave = 0; totalKos = 0; playerHp = 100; chi = 0; enemies = [];
      striking = false; blocking = false;
      ctx.camDirector.snapTo(player.root.position, null);
      SoundKit.startAmbient('dojo');
      await spawnWave(ctx);
    },

    onInput(ctx, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.pressed) {
        if (e.btn === 'A' || e.btn === 'B' || e.btn === 'Y') strike(ctx, e.btn);
        if (e.btn === 'X') { blocking = true; player.animator.play(SPORT_CLIP.karateBlock, { loop: true }); }
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
        player.root.position.x = Math.max(-8, Math.min(8, player.root.position.x));
        player.root.position.z = Math.max(-8, Math.min(8, player.root.position.z));
        player.root.rotation.y = Math.atan2(vel.x, vel.z);
        player.animator.play(SPORT_CLIP.moveLoop, { loop: true });
      } else if (!striking && !blocking && vel.lengthSquared() <= 0.05) {
        player.animator.play(STANCE, { loop: true });
      }

      const contacts = pool.update(dt, player.root.position, vel);
      for (const mob of contacts) {
        playerHp -= blocking ? 3 : 10;
        gainChi(ctx, blocking ? 2 : 4);
        mob.onContactResolved();
        if (!blocking) { player.animator.play(SPORT_CLIP.karateHitReact, {}); ctx.feel?.impact?.(0.4); }
        ctx.setHud({ hp: Math.max(0, playerHp) });
        if (playerHp <= 0) {
          SoundKit.play('crowdGroan');
          player.animator.play(SPORT_CLIP.karateKnockdown, { onEnd: () => {} });
          return ctx.end(`WAVE_${wave}`, totalKos * 100 + wave * 50, { wave, kos: totalKos });
        }
      }
      ctx.camDirector.update(player.root.position, vel,
        nearest()?.mob.char.root.position ?? null);
    },

    dispose() { player?.dispose(); pool?.dispose(); SoundKit.stopAmbient(); },
  };
})();
