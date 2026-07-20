// FootballRushMode v3 — REPLACES the M41 file. Three fixes from the live
// audit:
//   1. CLIP NAMES routed through SPORT_CLIP (T-pose fix, same as every other
//      mode in this batch).
//   2. DEFENSE RESPAWN no longer depends on MobPool.disposeAll() — that
//      method's real implementation lives in Abacus's own MobSteering.ts and
//      this repo can't verify what it touches. The live audit saw the field
//      disappear and the runner float in an empty void for roughly a second
//      around a down transition, which is consistent with a bulk-dispose
//      call reaching further than intended. This version tracks its OWN
//      defender list and disposes exactly those characters, one at a time,
//      never calling into a shared bulk-dispose path.
//   3. HUD FIELD DUPLICATION: the live bezel has its own "N YD · M EVA"
//      readout keyed on `yards`/`evades`. This mode was ALSO writing that
//      exact text into the same field ("7 YD · 0 EVA YD · 0 EVA" on the live
//      HUD). Fixed by passing bare numbers and letting the bezel format them.

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Mob, MobPool, STEERING_PRESETS } from '../core/MobSteering';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { assertSpawned } from '../core/FrameGuard';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { FOOTBALL_CONFIG as CFG } from './modeConfigs';

const FIELD_HALF_X = 9;
const DODGES = {
  X: { gesture: 'footballJukeLeft' as const,  dx: -3.2, iframes: 0.45, pts: 15 },
  Y: { gesture: 'footballJukeRight' as const, dx: 3.2,  iframes: 0.45, pts: 15 },
  B: { gesture: 'footballSpin' as const,      dx: 0,    iframes: 0.6,  pts: 25 },
  A: { gesture: 'footballHurdle' as const,    dx: 0,    iframes: 0.5,  pts: 20 },
} as const;

export const FootballRushMode: ModeDefinition = (() => {
  let runner: SpawnedCharacter;
  let pool = new MobPool();
  let defenders: Mob[] = [];                             // THE FIX: owned list, not pool.disposeAll()
  let down = 1, toGo = 10, lineOfScrimmage = 0, yards = 0, score = 0, evades = 0;
  let iframeSec = 0, dodging = false, ended = false;
  let stickX = 0, stickY = 0;

  async function spawnDefense(ctx: ModeContext): Promise<void> {
    // dispose exactly the defenders THIS mode created — nothing else
    for (const mob of defenders) mob.char.dispose();
    defenders = [];
    pool = new MobPool();

    const count = Math.min(3 + Math.floor(yards / 25), 6);
    for (let i = 0; i < count; i++) {
      const lane = ((i * 2 + down) % 5) - 2;
      const depth = 12 + i * 9 + (i % 2) * 4;
      const char = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(lane * 3.4, 0, runner.root.position.z + depth),
        yawRad: Math.PI,
        tint: i % 2 ? '#8b1e2d' : '#5a1220',
        startClip: SPORT_CLIP.idle,
      });
      neverBindPose(char.animator, SPORT_CLIP.idle);
      installSafePlay(char.animator, 'football-defender');
      ctx.groundLock?.track(char.root, char.skeleton);
      const mob = new Mob(char, STEERING_PRESETS[i % 2 ? 'rusher' : 'striker']);
      mob.startPursuit();
      pool.add(mob);
      defenders.push(mob);
    }
  }

  function newDrive(ctx: ModeContext, banner: string): void {
    down = 1; toGo = 10;
    lineOfScrimmage = 0; yards = 0;
    runner.root.position.set(0, 0, 0);
    runner.root.rotation.y = 0;
    runner.animator.play(SPORT_CLIP.idle, { loop: true });
    ctx.camDirector.snapTo(runner.root.position, runner.root.position.add(new Vector3(0, 0, 12)));
    ctx.setHud({ down, toGo, banner });
    setTimeout(() => ctx.setHud({ banner: '' }), 1400);
    void spawnDefense(ctx);
  }

  return {
    modeId: 'football', mood: 'stadiumNight', camPreset: 'runner',

    async load(ctx: ModeContext) {
      runner = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, 0), yawRad: 0, startClip: SPORT_CLIP.idle,
      });
      neverBindPose(runner.animator, SPORT_CLIP.idle);
      installSafePlay(runner.animator, 'football');
      ctx.groundLock?.track(runner.root, runner.skeleton);
      ctx.heroRef = () => runner.root;
      defenders = []; pool = new MobPool();
      score = 0; evades = 0; ended = false; iframeSec = 0; dodging = false;
      ctx.camDirector.snapTo(runner.root.position, runner.root.position.add(new Vector3(0, 0, 12)));
      assertSpawned(ctx.scene, { hero: runner.root, minWorldMeshes: 6, modeId: 'football' });
      newDrive(ctx, 'TAKE THE FIELD');
      ctx.setHud({ score: 0, yards: 0, evades: 0, hint: 'Run! Juke, spin, hurdle past the defense' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.pressed && !dodging && !ended) {
        const d = DODGES[e.btn as keyof typeof DODGES];
        if (!d) return;
        dodging = true;
        iframeSec = d.iframes;
        runner.animator.play(SPORT_CLIP[d.gesture], { onEnd: () => { dodging = false; } });
        if (d.dx) runner.root.position.x = Math.max(-FIELD_HALF_X, Math.min(FIELD_HALF_X, runner.root.position.x + d.dx));
        ctx.feel?.impact?.(0.12);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      iframeSec = Math.max(0, iframeSec - dt);

      const speed = 5.5 + Math.max(0, -stickY) * 2.5;
      const vel = new Vector3(stickX * 5, 0, speed);
      runner.root.position.addInPlace(vel.scale(dt));
      runner.root.position.x = Math.max(-FIELD_HALF_X, Math.min(FIELD_HALF_X, runner.root.position.x));
      if (!dodging) {
        runner.root.rotation.y = Math.atan2(vel.x, vel.z) * 0.5;
        runner.animator.play(SPORT_CLIP.moveLoop, { loop: true });
      }

      yards = Math.max(yards, Math.floor((runner.root.position.z - lineOfScrimmage) / 0.9144));
      ctx.setHud({ yards, evades });

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
        ctx.feel?.impact?.(0.7);
        runner.animator.play(SPORT_CLIP.footballTackled, {});
        const gained = yards;
        if (gained >= toGo) {
          down = 1; toGo = 10;
          lineOfScrimmage = runner.root.position.z;
          ctx.setHud({ down, toGo, banner: 'FIRST DOWN!' });
        } else {
          down++;
          toGo -= gained;
          if (down > 4) {
            ended = true;
            return ctx.end('TURNOVER_ON_DOWNS', score, { yards, evades });
          }
          ctx.setHud({ down, toGo, banner: `TACKLED — DOWN ${down}` });
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

      if (runner.root.position.z - 0 >= 91.44 || yards >= 100) {
        score += 100 + evades * 10;
        runner.animator.play(SPORT_CLIP.scoreCelebrate, {
          onEnd: () => runner.animator.play(SPORT_CLIP.idle, { loop: true }),
        });
        ctx.feel?.impact?.(0.6);
        ctx.setHud({ score, banner: 'TOUCHDOWN!' });
        newDrive(ctx, 'NEXT DRIVE');
      }

      ctx.camDirector.update(runner.root.position, vel, null);
    },

    dispose() {
      runner?.dispose();
      for (const mob of defenders) mob.char.dispose();
      defenders = [];
    },
  };
})();

// MODE_VERBS key `football`: HURDLE=A · SPIN=B · JUKE L=X · JUKE R=Y.
// FOOTBALL_CONFIG = { heroUrl: HERO_URL }.
