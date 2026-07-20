// ArenaDunkMode — the contest variant of DunkMode v2 (M35). Differences:
// seeded conditions, THREE attempts (best one submits), every input recorded
// into the deterministic stream, rival ghost replays beside you, and on finish
// the mode hands back { telemetry, ghostData } — the screen submits them.
// The telemetry COMES FROM simulateDunkRun(seed, stream): the client scores
// itself with the exact function the server verifies with.

import { MeshBuilder, Vector3 } from '@babylonjs/core';
import type { AbstractMesh } from '@babylonjs/core';
import { CharacterLibrary, type SpawnedCharacter } from '../core/CharacterLibrary';
import type { ModeContext, ModeDefinition } from '../core/ModeHarness';
import type { FelInput } from '../core/InputBus';
import { neverBindPose } from '../anim/importSanitizer';
import { attachBallToHand, releaseBall, runEastbayPath, flushThroughRim } from '../anim/ballRig';
import { EASTBAY_TIMING } from '../anim/authored/timing';
import { GhostRecorder, GhostPlayback } from './GhostSystem';
import { simulateDunkRun, encodeStream, type SimEvent, SIM } from '../shared/deterministicSim';
import { coreAxes } from '../server/aiJudges';            // shared scoring axes (pure fn)
import { DUNK_CONFIG as CFG } from '../modes/modeConfigs';

const ATTEMPTS = 3;
const STYLES = ['power', 'flashy', 'sig'] as const;
const STYLE_CLIP = ['dunk_launch', 'dunk_360_scoop', 'dunk_360_eastbay'];

export interface ArenaModeOptions {
  seed: string;
  rivalGhostData: string | null;      // serialized GhostData or null (first entrant)
}
export interface ArenaRunResult {
  telemetry: ReturnType<typeof simulateDunkRun>;
  ghostData: string;
}

export function makeArenaDunkMode(opts: ArenaModeOptions): ModeDefinition {
  let player: SpawnedCharacter;
  let ball: AbstractMesh;
  let ghost: GhostPlayback | null = null;
  const recorder = new GhostRecorder();

  type Phase = 'approach' | 'charge' | 'cinematic' | 'between';
  let phase: Phase = 'approach';
  let phaseSec = 0;
  let attempt = 0;
  let events: SimEvent[] = [];
  let t0 = 0;
  let style = 0, charge = 0, clipTime = 0;
  let stickX = 0, stickY = 0;
  let best: ArenaRunResult | null = null;
  let bestGrand = -1;
  const ebState = { inLeftHand: false };
  const rim = new Vector3(0, CFG.rimHeight, CFG.rimZ);

  const now = () => Math.round(performance.now() - t0);
  const rec = (e: SimEvent) => events.push(e);
  const setPhase = (p: Phase) => { phase = p; phaseSec = 0; };

  function startAttempt(ctx: ModeContext): void {
    attempt++;
    events = []; t0 = performance.now(); charge = 0; clipTime = 0;
    player.root.position.set(0, 0, SIM.startZ);
    player.root.rotation.y = Math.PI;
    player.animator.play('idle_stand', { loop: true });
    attachBallToHand(ball, player.skeleton, 'RightHand');
    recorder.start();
    if (ghost) ghost.play();                             // rival runs WITH you
    setPhase('approach');
    ctx.setHud({
      banner: `ATTEMPT ${attempt} / ${ATTEMPTS}`,
      hint: 'Seeded conditions — drive, HOLD CHARGE, release, SLAM',
      score: bestGrand >= 0 ? `best ${bestGrand}` : '—',
    });
    setTimeout(() => ctx.setHud({ banner: '' }), 1600);
  }

  function endAttempt(ctx: ModeContext): void {
    const stream = encodeStream(events);
    const telemetry = simulateDunkRun(opts.seed, stream);
    const axes = coreAxes(telemetry);
    const grand = Math.round((axes.technique + axes.difficulty + axes.style) * 3 * 10) / 10;
    if (grand > bestGrand) {
      bestGrand = grand;
      best = { telemetry, ghostData: recorder.serialize() };
    }
    ctx.setHud({ banner: `RUN SCORE ${grand}`, hint: grand === bestGrand ? 'NEW BEST' : '' });
    setPhase('between');
    setTimeout(() => {
      if (attempt >= ATTEMPTS) {
        // payload carries the submission — the Arena screen POSTs it
        ctx.end('SUBMITTED', bestGrand, best as unknown as Record<string, unknown>);
      } else startAttempt(ctx);
    }, 2000);
  }

  return {
    modeId: 'dunk_arena', mood: 'goldenHour', camPreset: 'court',

    async load(ctx: ModeContext) {
      player = await CharacterLibrary.spawn(ctx.scene, CFG.heroUrl, {
        position: new Vector3(0, 0, SIM.startZ), yawRad: Math.PI, startClip: 'idle_stand',
      });
      neverBindPose(player.animator, 'idle_stand');
      ctx.groundLock?.track(player.root, player.skeleton);
      ball = MeshBuilder.CreateSphere('arena_ball', { diameter: 0.24 }, ctx.scene);
      attachBallToHand(ball, player.skeleton, 'RightHand');
      if (opts.rivalGhostData) {
        try {
          ghost = new GhostPlayback(ctx.scene, opts.rivalGhostData);
          await ghost.spawn(CFG.heroUrl);
        } catch (e) {
          console.warn('[FEL-ARENA] rival ghost failed to load — solo run', e);
          ghost = null;
        }
      }
      attempt = 0; best = null; bestGrand = -1;
      startAttempt(ctx);
    },

    onInput(ctx: ModeContext, e: FelInput) {
      if (phase === 'between') return;
      if (e.t === 'stick' && e.side === 'L') {
        stickX = e.x; stickY = e.y;
        rec({ tMs: now(), k: 's', a: e.x, b: e.y });
      }
      if (e.t === 'button' && e.btn === 'B' && e.pressed && phase !== 'cinematic') {
        style = (style + 1) % 3;
        rec({ tMs: now(), k: 'y', a: style });
        ctx.setHud({ style: STYLES[style].toUpperCase() });
      }
      if (e.t === 'trigger' && e.side === 'R') {
        rec({ tMs: now(), k: 't', a: e.value });
        if (phase === 'approach' && e.value > 0.02) {
          setPhase('charge');
          player.animator.play('dunk_charge_gather', { loop: true });
        }
        if (phase === 'charge') {
          charge = Math.max(charge, e.value);
          ctx.setHud({ charge: Math.round(charge * 100) });
          if (e.value === 0) {
            setPhase('cinematic'); clipTime = 0; ebState.inLeftHand = false;
            player.animator.play(STYLE_CLIP[style], { onEnd: () => {} });
          }
        }
      }
      if (e.t === 'button' && e.btn === 'A' && e.pressed && phase === 'cinematic') {
        rec({ tMs: now(), k: 'a' });
      }
    },

    update(ctx: ModeContext, dt: number) {
      phaseSec += dt;
      // watchdogs mirror M35 DunkMode: nothing can stall an attempt
      if (phase === 'approach' && phaseSec > 20) { rec({ tMs: now(), k: 't', a: 0.6 }); rec({ tMs: now() + 400, k: 't', a: 0 }); endAttempt(ctx); return; }
      if (phase === 'charge' && phaseSec > 5) { rec({ tMs: now(), k: 't', a: 0 }); setPhase('cinematic'); clipTime = 0; player.animator.play(STYLE_CLIP[style], { onEnd: () => {} }); }

      const vel = new Vector3(stickX * 4, 0, -Math.max(0, -stickY) * 5 - 2);
      if (phase === 'approach') {
        player.root.position.addInPlace(vel.scale(dt));
        player.root.position.z = Math.max(player.root.position.z, SIM.gatherZ);
        player.root.position.x = Math.max(-6, Math.min(6, player.root.position.x));
        player.animator.play(Math.hypot(vel.x, vel.z) > 2.5 ? 'run_forward' : 'idle_stand', { loop: true });
      }
      if (phase === 'cinematic') {
        clipTime += dt;
        if (STYLES[style] === 'sig') runEastbayPath(ball, player.skeleton, clipTime, ebState);
        const airSec = SIM.airBase + charge * SIM.airPerCharge;
        const k = Math.min(1, clipTime / airSec);
        player.root.position.y = Math.sin(k * Math.PI) * (SIM.apexBase + charge * SIM.apexPerCharge);
        player.root.position.z += (rim.z + 0.6 - player.root.position.z) * 1.6 * dt;
        const rimBeat = airSec * SIM.extendFrac;
        const open = Math.abs(clipTime - rimBeat) <= SIM.cleanWindowMs / 1000;
        ctx.setHud({ slamPulse: open, hint: open ? 'SLAM!' : 'RISE…' });
        if (clipTime >= rimBeat + 0.3) {                 // visual resolve
          releaseBall(ball);
          flushThroughRim(ball, rim, ball.getAbsolutePosition(), 0.1);
          player.animator.play('dunk_land_crouch', {
            onEnd: () => player.animator.play('idle_stand', { loop: true }),
          });
          ctx.setHud({ slamPulse: false });
          endAttempt(ctx);
        }
      }
      recorder.sample(player);
      ctx.camDirector.update(player.root.position, vel, phase === 'approach' ? rim : ball.position);
    },

    dispose() { player?.dispose(); ghost?.dispose(); ball?.dispose(); },
  };
}

// modeVerbs: 'dunk_arena' reuses the 'dunk' verb set — add the alias:
//   MODE_VERBS.dunk_arena = MODE_VERBS.dunk;
