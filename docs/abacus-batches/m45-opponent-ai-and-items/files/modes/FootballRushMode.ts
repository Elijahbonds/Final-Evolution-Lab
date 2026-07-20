// FootballRushMode v4 — REPLACES the M42 file. Adds BREAKAWAY: string
// together 3 evasions in one drive without being tackled and the runner
// gets a temporary speed boost plus a score multiplier on the next score —
// the same "the defense can't touch you" high the Madden truck-stick/
// juke-string moments chase. Also wires SoundKit (whoosh on jukes, impact on
// tackles/evades — this mode never called ctx.feel?.impact for evades until
// now, crowd cheer on touchdowns, stadium ambient bed).

import { Vector3 } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import { Mob, MobPool, STEERING_PRESETS } from '../core/MobSteering';
import { CoinField } from '../core/Pickups';
import { neverBindPose } from '../anim/importSanitizer';
import { installSafePlay, SPORT_CLIP } from '../anim/clipRegistry';
import { assertSpawned } from '../core/FrameGuard';
import { SoundKit } from '../audio/SoundKit';
import { EffectsKit } from '../visual/EffectsKit';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { FOOTBALL_CONFIG as CFG } from './modeConfigs';

const FIELD_HALF_X = 9;
// MAP-SIZE FIX: VenueKit.buildGridiron's ground is only 90 units long
// (z ∈ [-45, 45]) — the old touchdown trigger at z>=91.44 (a full 100-yard
// field) required the runner to cross TWICE the venue's actual length,
// running off the visible field and into/through the back wall well before
// any touchdown could fire, and defenders could spawn up to 61 units ahead
// of the runner — past the wall, off the rendered field. FIELD_LENGTH now
// matches the real venue with a safety margin before the wall.
const FIELD_LENGTH = 40;                      // ≈ 43.7 yards — fits inside the 45-unit half-field
const DEFENDER_MAX_DEPTH = 22;                // never spawns past what's left of the field
const BREAKAWAY_THRESHOLD = 3;
const BREAKAWAY_SPEED_MULT = 1.25;
const BREAKAWAY_SEC = 4;
const DODGES = {
  X: { gesture: 'footballJukeLeft' as const,  dx: -3.2, iframes: 0.45, pts: 15 },
  Y: { gesture: 'footballJukeRight' as const, dx: 3.2,  iframes: 0.45, pts: 15 },
  B: { gesture: 'footballSpin' as const,      dx: 0,    iframes: 0.6,  pts: 25 },
  A: { gesture: 'footballHurdle' as const,    dx: 0,    iframes: 0.5,  pts: 20 },
} as const;

export const FootballRushMode: ModeDefinition = (() => {
  let runner: SpawnedCharacter;
  let pool = new MobPool();
  let defenders: Mob[] = [];
  let coins: CoinField | null = null;
  let down = 1, toGo = 10, lineOfScrimmage = 0, yards = 0, score = 0, evades = 0;
  let driveEvades = 0, breakawaySec = 0;
  let iframeSec = 0, dodging = false, ended = false;
  let stickX = 0, stickY = 0;

  // THE ITEMS FIX: Pickups/CoinField has existed since M26 and was never
  // instantiated by any mode. A zig-zag coin line down the lane gives the
  // runner a reason to weave, not just sprint straight — reports through
  // the existing SessionResult.stats contract (coinsCollected), same reward
  // pipeline shards/XP already use.
  function layCoins(ctx: ModeContext, fromZ: number): void {
    coins?.dispose();
    coins = new CoinField(ctx.scene);
    const toZ = Math.min(FIELD_LENGTH - 2, fromZ + 24);
    coins.line(new Vector3(-3, 0.4, fromZ + 4), new Vector3(3, 0.4, toZ), 8);
  }

  async function spawnDefense(ctx: ModeContext): Promise<void> {
    for (const mob of defenders) mob.char.dispose();
    defenders = [];
    pool = new MobPool();

    // escalate with total field progress, not just the current set of downs
    // (yards resets every first down, so this used to never really ramp up)
    const progress = Math.max(0, runner.root.position.z);
    const count = Math.min(3 + Math.floor(progress / (FIELD_LENGTH / 3)), 6);
    const remaining = Math.max(6, FIELD_LENGTH - progress);
    for (let i = 0; i < count; i++) {
      const lane = ((i * 2 + down) % 5) - 2;
      const rawDepth = 6 + i * 5 + (i % 2) * 3;
      const depth = Math.min(rawDepth, DEFENDER_MAX_DEPTH, remaining * 0.85);
      const char = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(lane * 3.4, 0, runner.root.position.z + depth),
        yawRad: Math.PI,
        tint: i % 2 ? '#8b1e2d' : '#5a1220',
        startClip: SPORT_CLIP.idle,
      });
      neverBindPose(char.animator, SPORT_CLIP.idle);
      installSafePlay(char.animator, 'football-defender');
      ctx.groundLock?.track(char.root, char.skeleton);
      // THE FIX: football was reusing karate's striker/rusher presets.
      // 'defender' is the purpose-built cut-off preset; mixing in 'flanker'
      // for every third defender means the defense doesn't read as a single
      // straight-line chase — some cut an angle instead.
      const archetype = i % 3 === 2 ? 'flanker' : 'defender';
      const mob = new Mob(char, STEERING_PRESETS[archetype]);
      mob.startPursuit();
      pool.add(mob);
      defenders.push(mob);
    }
  }

  function newDrive(ctx: ModeContext, banner: string): void {
    down = 1; toGo = 10;
    lineOfScrimmage = 0; yards = 0; driveEvades = 0; breakawaySec = 0;
    runner.root.position.set(0, 0, 0);
    runner.root.rotation.y = 0;
    runner.animator.play(SPORT_CLIP.idle, { loop: true });
    ctx.camDirector.snapTo(runner.root.position, runner.root.position.add(new Vector3(0, 0, 12)));
    ctx.setHud({ down, toGo, banner, breakaway: false });
    setTimeout(() => ctx.setHud({ banner: '' }), 1400);
    void spawnDefense(ctx);
    layCoins(ctx, 0);
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
      driveEvades = 0; breakawaySec = 0;
      ctx.camDirector.snapTo(runner.root.position, runner.root.position.add(new Vector3(0, 0, 12)));
      assertSpawned(ctx.scene, { hero: runner.root, minWorldMeshes: 6, modeId: 'football' });
      SoundKit.startAmbient('stadium');
      EffectsKit.ambient(ctx.scene, 'gridiron');
      newDrive(ctx, 'TAKE THE FIELD');
      ctx.setHud({ score: 0, yards: 0, evades: 0, hint: 'Run! Juke, spin, hurdle past the defense' });
    },

    onInput(ctx: ModeContext, e: FelInput) {
      SoundKit.unlock();
      if (e.t === 'stick' && e.side === 'L') { stickX = e.x; stickY = e.y; }
      if (e.t === 'button' && e.pressed && !dodging && !ended) {
        const d = DODGES[e.btn as keyof typeof DODGES];
        if (!d) return;
        dodging = true;
        iframeSec = d.iframes;
        SoundKit.play('whoosh', { pitch: 1.15 });
        runner.animator.play(SPORT_CLIP[d.gesture], { onEnd: () => { dodging = false; } });
        if (d.dx) runner.root.position.x = Math.max(-FIELD_HALF_X, Math.min(FIELD_HALF_X, runner.root.position.x + d.dx));
        ctx.feel?.impact?.(0.12);
      }
    },

    update(ctx: ModeContext, dt: number) {
      if (ended) return;
      iframeSec = Math.max(0, iframeSec - dt);
      breakawaySec = Math.max(0, breakawaySec - dt);
      if (breakawaySec === 0) ctx.setHud({ breakaway: false });

      const boost = breakawaySec > 0 ? BREAKAWAY_SPEED_MULT : 1;
      const speed = (5.5 + Math.max(0, -stickY) * 2.5) * boost;
      const vel = new Vector3(stickX * 5 * boost, 0, speed);
      runner.root.position.addInPlace(vel.scale(dt));
      runner.root.position.x = Math.max(-FIELD_HALF_X, Math.min(FIELD_HALF_X, runner.root.position.x));
      if (!dodging) {
        runner.root.rotation.y = Math.atan2(vel.x, vel.z) * 0.5;
        runner.animator.play(SPORT_CLIP.moveLoop, { loop: true });
      }

      yards = Math.max(yards, Math.floor((runner.root.position.z - lineOfScrimmage) / 0.9144));
      ctx.setHud({ yards, evades });

      const gained = coins?.update(dt, runner.root.position) ?? 0;
      if (gained > 0) {
        score += gained * 5;
        SoundKit.play('uiTick', { pitch: 1.4 });
        ctx.setHud({ score, coins: coins?.collected ?? 0 });
      }

      const contacts = pool.update(dt, runner.root.position, vel);
      for (const mob of contacts) {
        if (iframeSec > 0) {
          evades++; driveEvades++;
          const mult = breakawaySec > 0 ? 2 : 1;
          score += 20 * mult;
          mob.onContactResolved();
          ctx.feel?.impact?.(0.3);
          SoundKit.play('impact', { pitch: 1.3, volume: 0.35 });
          if (driveEvades >= BREAKAWAY_THRESHOLD && breakawaySec <= 0) {
            breakawaySec = BREAKAWAY_SEC;
            SoundKit.play('powerUp');
            ctx.setHud({ banner: 'BREAKAWAY!', breakaway: true });
            setTimeout(() => ctx.setHud({ banner: '' }), 900);
          } else {
            ctx.setHud({ banner: 'EVADED!', score });
            setTimeout(() => ctx.setHud({ banner: '' }), 500);
          }
          continue;
        }
        ctx.feel?.impact?.(0.7);
        SoundKit.play('impact', { pitch: 0.8 });
        EffectsKit.burst(ctx.scene, runner.root.position.add(new Vector3(0, 0.6, 0)), 'dust');
        runner.animator.play(SPORT_CLIP.footballTackled, {});
        driveEvades = 0; breakawaySec = 0;
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
            SoundKit.play('whistle');
            return ctx.end('TURNOVER_ON_DOWNS', score, { yards, evades, coinsCollected: coins?.collected ?? 0 });
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

      if (runner.root.position.z >= FIELD_LENGTH) {
        const mult = breakawaySec > 0 ? 1.5 : 1;
        score += Math.round((100 + evades * 10) * mult);
        runner.animator.play(SPORT_CLIP.scoreCelebrate, {
          onEnd: () => runner.animator.play(SPORT_CLIP.idle, { loop: true }),
        });
        ctx.feel?.impact?.(0.6);
        SoundKit.play('score');
        SoundKit.play('crowdCheer');
        EffectsKit.burst(ctx.scene, runner.root.position.add(new Vector3(0, 1.8, 0)), 'confetti');
        ctx.setHud({ score, banner: 'TOUCHDOWN!' });
        newDrive(ctx, 'NEXT DRIVE');
      }

      ctx.camDirector.update(runner.root.position, vel, null);
    },

    dispose() {
      runner?.dispose();
      for (const mob of defenders) mob.char.dispose();
      defenders = [];
      coins?.dispose();
      SoundKit.stopAmbient();
    },
  };
})();
