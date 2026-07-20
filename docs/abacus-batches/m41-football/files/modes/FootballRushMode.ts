// FootballRushMode v2 — REPLACES the live street football mode. The July
// audit's strangest result: the game LOGIC works (downs advance, touchdowns
// score) while the RUNNER AND DEFENDERS are never on screen — the game plays
// itself invisibly (E9 + missing defender spawns). v2: chase camera locked to
// the runner from frame one, visible pursuit defenders (MobSteering with
// team tints), juke/spin/hurdle evasions with real dodge windows + i-frames,
// first-down chain, 4-down drives, TD celebration the camera actually shows.

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Mob, MobPool, STEERING_PRESETS } from '../core/MobSteering';
import { neverBindPose } from '../anim/importSanitizer';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { FOOTBALL_CONFIG as CFG } from './modeConfigs';

const FIELD_HALF_X = 9;
const DODGES = {
  X: { clip: 'football_juke_left',  dx: -3.2, iframes: 0.45, pts: 15 },   // JUKE L
  Y: { clip: 'football_juke_right', dx: 3.2,  iframes: 0.45, pts: 15 },   // JUKE R
  B: { clip: 'football_spin_move',  dx: 0,    iframes: 0.6,  pts: 25 },   // SPIN
  A: { clip: 'jump_up',             dx: 0,    iframes: 0.5,  pts: 20 },   // HURDLE
} as const;

export const FootballRushMode: ModeDefinition = (() => {
  let runner: SpawnedCharacter;
  let pool: MobPool;
  let down = 1, toGo = 10, lineOfScrimmage = 0, yards = 0, score = 0, evades = 0;
  let iframeSec = 0, dodging = false, ended = false;
  let stickX = 0, stickY = 0;

  async function spawnDefense(ctx: ModeContext): Promise<void> {
    pool.disposeAll?.();
    const count = Math.min(3 + Math.floor(yards / 25), 6);
    for (let i = 0; i < count; i++) {
      const lane = ((i * 2 + down) % 5) - 2;
      const depth = 12 + i * 9 + (i % 2) * 4;
      const char = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(lane * 3.4, 0, runner.root.position.z + depth),
        yawRad: Math.PI,
        tint: i % 2 ? '#8b1e2d' : '#5a1220',              // visible defense colors
        startClip: 'idle_stand',
      });
      neverBindPose(char.animator, 'idle_stand');
      ctx.groundLock?.track(char.root, char.skeleton);
      const mob = new Mob(char, STEERING_PRESETS[i % 2 ? 'rusher' : 'striker']);
      mob.startPursuit();
      pool.add(mob);
    }
  }

  function newDrive(ctx: ModeContext, banner: string): void {
    down = 1; toGo = 10;
    lineOfScrimmage = 0; yards = 0;
    runner.root.position.set(0, 0, 0);
    runner.root.rotation.y = 0;
    runner.animator.play('idle_stand', { loop: true });
    ctx.camDirector.snapTo(runner.root.position, runner.root.position.add(new Vector3(0, 0, 12)));
    ctx.setHud({ downs: `${down} & ${toGo}`, banner });
    setTimeout(() => ctx.setHud({ banner: '' }), 1400);
    void spawnDefense(ctx);
  }

  return {
    modeId: 'football', mood: 'stadiumNight', camPreset: 'runner',

    async load(ctx: ModeContext) {
      runner = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, 0), yawRad: 0, startClip: 'idle_stand',
      });
      neverBindPose(runner.animator, 'idle_stand');
      ctx.groundLock?.track(runner.root, runner.skeleton);
      ctx.heroRef = () => runner.root;
      pool = new MobPool();
      score = 0; evades = 0; ended = false; iframeSec = 0; dodging = false;
      ctx.camDirector.snapTo(runner.root.position, runner.root.position.add(new Vector3(0, 0, 12)));
      assertSpawned(ctx.scene, { hero: runner.root, minWorldMeshes: 6, modeId: 'football' });
      newDrive(ctx, 'TAKE THE FIELD');
      ctx.setHud({ score: 0, yards: '0 YD · 0 EVA', hint: 'Run! Juke, spin, hurdle past the defense' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.pressed && !dodging && !ended) {
        const d = DODGES[e.btn as keyof typeof DODGES];
        if (!d) return;
        dodging = true;
        iframeSec = d.iframes;
        runner.animator.play(d.clip, { onEnd: () => { dodging = false; } });
        if (d.dx) runner.root.position.x = Math.max(-FIELD_HALF_X, Math.min(FIELD_HALF_X, runner.root.position.x + d.dx));
        ctx.feel?.impact?.(0.12);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      iframeSec = Math.max(0, iframeSec - dt);

      // always moving downfield; stick steers, up-stick sprints
      const speed = 5.5 + Math.max(0, -stickY) * 2.5;
      const vel = new Vector3(stickX * 5, 0, speed);
      runner.root.position.addInPlace(vel.scale(dt));
      runner.root.position.x = Math.max(-FIELD_HALF_X, Math.min(FIELD_HALF_X, runner.root.position.x));
      if (!dodging) {
        runner.root.rotation.y = Math.atan2(vel.x, vel.z) * 0.5;
        runner.animator.play('run_forward', { loop: true });
      }

      yards = Math.max(yards, Math.floor((runner.root.position.z - lineOfScrimmage) / 0.9144));
      ctx.setHud({ yards: `${yards} YD · ${evades} EVA` });

      // defender contact — i-frames from a well-timed dodge shrug it off
      const contacts = pool.update(dt, runner.root.position, vel);
      for (const mob of contacts) {
        if (iframeSec > 0) {
          evades++;
          score += 20;
          mob.onContactResolved();
          ctx.feel?.impact?.(0.3);
          ctx.setHud({ banner: 'EVADED!', score });
          setTimeout(() => ctx.setHud({ banner: '' }), 500);
          continue;
        }
        // TACKLED — advance the down
        ctx.feel?.impact?.(0.7);
        runner.animator.play('football_tackled_fall', {});
        const gained = yards;
        if (gained >= toGo) {
          down = 1; toGo = 10;
          lineOfScrimmage = runner.root.position.z;
          ctx.setHud({ downs: `${down} & ${toGo}`, banner: 'FIRST DOWN!' });
        } else {
          down++;
          toGo -= gained;
          if (down > 4) {
            ended = true;
            return ctx.end('TURNOVER_ON_DOWNS', score, { yards, evades });
          }
          ctx.setHud({ downs: `${down} & ${toGo}`, banner: `TACKLED — DOWN ${down}` });
        }
        mob.onContactResolved();
        setTimeout(() => {
          ctx.setHud({ banner: '' });
          runner.root.position.x = 0;
          void spawnDefense(ctx);
        }, 1000);
        yards = 0;
        lineOfScrimmage = runner.root.position.z;
      }

      // TOUCHDOWN at 100 total yards from drive start
      if (runner.root.position.z - 0 >= 91.44 || yards >= 100) {
        score += 100 + evades * 10;
        runner.animator.play('bball_score_celebrate', {
          onEnd: () => runner.animator.play('idle_stand', { loop: true }),
        });
        ctx.feel?.impact?.(0.6);
        ctx.setHud({ score, banner: 'TOUCHDOWN!' });
        newDrive(ctx, 'NEXT DRIVE');
      }

      ctx.camDirector.update(runner.root.position, vel, null);
    },

    dispose() { runner?.dispose(); pool?.dispose(); },
  };
})();

// MobPool needs disposeAll() (three lines) if it lacks it: dispose each mob,
// clear the list. MODE_VERBS key `football`: HURDLE=A · SPIN=B · JUKE L=X ·
// JUKE R=Y. Keyboard: J/K/L/I. FOOTBALL_CONFIG = { heroUrl: HERO_URL }.
