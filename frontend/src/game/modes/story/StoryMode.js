import { GameModeInterface, ModePhase } from '../GameModeInterface.js';
import { feelConfig } from '../../systems/feelConfig.js';
import { FixedStepLoop } from '../../core/FixedStepLoop.js';
import { StateMachine } from '../../systems/StateMachine.js';
import { ArcDrive } from '../../systems/ArcDrive.js';
import { SensoryBus } from '../../systems/SensoryBus.js';
import { BOARD_SPACES, ZONE_BOSSES, SpaceType } from '../../data/storyBoard.js';
import StoryBoardScene from './StoryBoardScene.js';

/** Donor StoryPhase, folded for v1 (rail/flight sections = space bonuses). */
export const StoryPhase = Object.freeze({
  TRAVERSAL: 'BoardTraversal',
  MOVING:    'TokenMoving',
  BOSS:      'BossFight',
  DEFEATED:  'BossDefeated',
  COMPLETE:  'StoryComplete',
});

/**
 * Story Mode — the C++ donor board engine on the shared systems: roll and
 * move around the 20-space Venice board (ArcDrive token hops), space
 * effects (shards, obstacles, carnival extra rolls), and zone boss fights
 * (timed strike exchanges vs donor boss configs). Defeat all four bosses —
 * The Architect last — to complete the story.
 */
export class StoryMode extends GameModeInterface {
  constructor(modeIdOrCanvas, maybeCanvas, container) {
    const hasExplicitModeId = typeof modeIdOrCanvas === 'string';
    const modeId = hasExplicitModeId ? modeIdOrCanvas : 'story';
    const canvas = hasExplicitModeId ? maybeCanvas : modeIdOrCanvas;
    super(modeId, canvas);

    this.container = container ?? null;
    this.scene = null;
    this._disposed = false;
    this._loop = null;
    this._rafId = null;
    this._lastRafTs = 0;
    this._sensory = null;
    this._hop = new ArcDrive();
    this.tokenPosition = { ...BOARD_SPACES[0].pos };
    this._prevPos = { ...this.tokenPosition };
    this._renderPos = { ...this.tokenPosition };

    this._tokenIndex = 0;
    this._hopsLeft = 0;
    this._cleared = new Set();  // boss zones defeated
    this._boss = null;          // { name, hp, maxHp, aggression, shard, final }
    this._bossNextIn = 0;
    this._strikeCooldown = 0;
    this._extraRoll = false;

    this._fsm = new StateMachine({
      initial: StoryPhase.TRAVERSAL,
      states: {
        [StoryPhase.TRAVERSAL]: {},
        [StoryPhase.MOVING]: {},
        [StoryPhase.BOSS]: {},
        [StoryPhase.DEFEATED]: {},
        [StoryPhase.COMPLETE]: {},
      },
    });

    this.state = this._createInitialState();
  }

  _createInitialState() {
    return {
      phase: ModePhase.WARMUP,
      shards: 0,
      hp: 100,
      lastRoll: 0,
      lastEvent: 'Roll to begin your evolution',
      bossesDefeated: 0,
      bossesTotal: Object.keys(ZONE_BOSSES).length,
    };
  }

  async start(container) {
    this.dispose();
    this._disposed = false;
    this.container = container ?? this.container;

    this.scene = new StoryBoardScene(this.canvas);
    await this.scene.init();
    if (this._disposed) {
      this.scene.dispose();
      this.scene = null;
      return this.getState();
    }

    this._tokenIndex = 0;
    Object.assign(this.tokenPosition, BOARD_SPACES[0].pos);
    Object.assign(this._prevPos, this.tokenPosition);
    this._cleared.clear();
    this._boss = null;
    this._extraRoll = false;
    this._hop.cancel();
    this._fsm.transition(StoryPhase.TRAVERSAL);
    this.state = { ...this._createInitialState(), phase: ModePhase.ACTIVE };

    this._loop = new FixedStepLoop({
      hz: feelConfig.timestepHz,
      maxAccumulatedMs: feelConfig.maxAccumulatedMs,
      update: (dt) => this._fixedUpdate(dt),
      render: (alpha) => this._renderInterpolate(alpha),
    });
    this._loop.start();
    if (this.scene && !this.scene.isFallback && this.scene.setFrameCallback) {
      this.scene.setFrameCallback((dtMs) => this._loop.tick(dtMs));
    } else {
      this._startFallbackDriver();
    }

    this._sensory = new SensoryBus({
      camera: this.scene && !this.scene.isFallback ? this.scene : null,
      loop: this._loop,
      sfx: {
        impact: '/audio/sfx_punch_impact.mp3',
        swoosh: '/audio/sfx_basketball_swoosh.mp3',
        crowd:  '/audio/sfx_crowd_cheer.mp3',
      },
    });

    return this.getState();
  }

  getGamepadProps() {
    return {
      onFaceButton: (id) => {
        if (id === 'cross') {
          if (this._fsm.current === StoryPhase.TRAVERSAL) this.update({ type: 'roll' });
        }
        if (id === 'square' && this._fsm.current === StoryPhase.BOSS) {
          this.update({ type: 'strike' });
        }
      },
    };
  }

  update(inputEvent = {}) {
    if (this.state.phase !== ModePhase.ACTIVE) return this.getState();
    const { type } = inputEvent;
    if (type === 'roll' && this._fsm.current === StoryPhase.TRAVERSAL) this._roll();
    if (type === 'strike' && this._fsm.current === StoryPhase.BOSS) this._strike();
    return this.getState();
  }

  /** Donor rollAndMove(): d6 roll → hop space-by-space. */
  _roll() {
    const roll = 1 + Math.floor(Math.random() * 6);
    this.state.lastRoll = roll;
    this.state.lastEvent = `Rolled ${roll}`;
    this._hopsLeft = roll;
    this._sensory?.emit({ sfx: 'swoosh', volume: 0.5 });
    this._fsm.transition(StoryPhase.MOVING);
    this._beginNextHop();
  }

  _beginNextHop() {
    if (this._hopsLeft <= 0) return;
    const next = (this._tokenIndex + 1) % BOARD_SPACES.length;
    const target = BOARD_SPACES[next].pos;
    this._hop.begin({
      start: this.tokenPosition,
      target,
      apexY: Math.max(this.tokenPosition.y, target.y) + 0.9, // TUNE(elijah) — hop arc
      durationMs: 340,                                        // TUNE(elijah)
    });
    this._tokenIndex = next;
    this._hopsLeft -= 1;
  }

  _resolveSpaceLanding() {
    const space = BOARD_SPACES[this._tokenIndex];
    const k = feelConfig.story;
    switch (space.type) {
      case SpaceType.BONUS:
        this.state.shards += space.bonus;
        this.state.lastEvent = `+${space.bonus} shards`;
        this._sensory?.emit({ sfx: 'swoosh', volume: 0.5, shake: 0.05 });
        break;
      case SpaceType.CARNIVAL:
        this.state.shards += space.bonus;
        this._extraRoll = true;
        this.state.lastEvent = `Carnival! +${space.bonus} shards and an extra roll`;
        this._sensory?.emit({ sfx: 'crowd', volume: 0.45 });
        break;
      case SpaceType.RAIL:
      case SpaceType.FLIGHT:
        this.state.shards += space.bonus;
        this.state.lastEvent = `${space.type === SpaceType.RAIL ? 'Rail' : 'Flight'} bonus +${space.bonus}`;
        this._sensory?.emit({ sfx: 'swoosh', volume: 0.55, shake: 0.05 });
        break;
      case SpaceType.OBSTACLE:
        this.state.hp = Math.max(0, this.state.hp - space.bonus);
        this.state.lastEvent = `Obstacle! -${space.bonus} HP`;
        this._sensory?.emit({ sfx: 'impact', volume: 0.7, shake: 0.1 });
        if (this.state.hp === 0) {
          // Donor retreat rule: restore and fall back to the board start
          this.state.hp = k.retreatHp;
          this._tokenIndex = 0;
          Object.assign(this.tokenPosition, BOARD_SPACES[0].pos);
          this.state.lastEvent = 'Knocked out — back to the boardwalk';
        }
        break;
      case SpaceType.BOSS: {
        if (this._cleared.has(space.zone)) {
          this.state.lastEvent = 'This zone is already liberated';
          break;
        }
        const cfg = ZONE_BOSSES[space.zone];
        this._boss = { ...cfg, hp: cfg.maxHp, zone: space.zone };
        this._bossNextIn = k.bossFirstAttackS;
        this._strikeCooldown = 0;
        this.state.lastEvent = `BOSS: ${cfg.name}`;
        this._sensory?.emit({ sfx: 'impact', volume: 0.9, shake: 0.15, hitStopMs: 80 });
        this._fsm.transition(StoryPhase.BOSS);
        return;
      }
      default:
        break;
    }
    if (this._extraRoll) {
      this._extraRoll = false;
      this.state.lastEvent += ' — roll again!';
    }
    this._fsm.transition(StoryPhase.TRAVERSAL);
  }

  _strike() {
    if (this._strikeCooldown > 0 || !this._boss) return;
    const k = feelConfig.story;
    this._strikeCooldown = k.strikeCooldownS;
    const dmg = k.strikeMin + Math.random() * (k.strikeMax - k.strikeMin);
    this._boss.hp = Math.max(0, this._boss.hp - dmg);
    this.state.lastEvent = `Hit ${this._boss.name} for ${Math.round(dmg)}`;
    this._sensory?.emit({ sfx: 'impact', volume: 0.7, shake: 0.08 });
    if (this._boss.hp === 0) {
      this._cleared.add(this._boss.zone);
      this.state.bossesDefeated = this._cleared.size;
      this.state.shards += k.bossShardBonus;
      this.state.lastEvent = `${this._boss.name} defeated! +${k.bossShardBonus} shards (${this._boss.shard})`;
      this._sensory?.emit({
        sfx: 'crowd', volume: feelConfig.sensory.crowdVolume,
        shake: 0.22, hitStopMs: 150, rumbleMs: feelConfig.sensory.rumbleMs,
      });
      const finished = this.state.bossesDefeated >= this.state.bossesTotal;
      this._boss = null;
      this._fsm.transition(finished ? StoryPhase.COMPLETE : StoryPhase.DEFEATED);
      if (finished) {
        this.state.lastEvent = 'STORY COMPLETE — Venice is free';
        this.end();
      }
    }
  }

  _fixedUpdate(dt) {
    if (this.state.phase !== ModePhase.ACTIVE) return;
    const k = feelConfig.story;
    this._fsm.update(dt);
    this._strikeCooldown = Math.max(0, this._strikeCooldown - dt);

    switch (this._fsm.current) {
      case StoryPhase.MOVING: {
        this._prevPos.x = this.tokenPosition.x;
        this._prevPos.y = this.tokenPosition.y;
        this._prevPos.z = this.tokenPosition.z;
        const done = this._hop.advance(dt, this.tokenPosition);
        if (done) {
          this._sensory?.emit({ sfx: 'impact', volume: 0.25 });
          if (this._hopsLeft > 0) this._beginNextHop();
          else this._resolveSpaceLanding();
        }
        break;
      }
      case StoryPhase.BOSS: {
        this._bossNextIn -= dt;
        if (this._bossNextIn <= 0 && this._boss) {
          const dmg = k.bossDmgMin + Math.random() * (k.bossDmgMax - k.bossDmgMin);
          this.state.hp = Math.max(0, this.state.hp - dmg);
          this.state.lastEvent = `${this._boss.name} hits for ${Math.round(dmg)}`;
          this._sensory?.emit({ sfx: 'impact', volume: 0.6, shake: 0.09 });
          this._bossNextIn = k.bossAttackBaseS / this._boss.aggression;
          if (this.state.hp === 0) {
            // Retreat: heal partial, token back one zone, boss keeps its HP gone? Donor: boss resets.
            this.state.hp = k.retreatHp;
            this._boss = null;
            this._tokenIndex = 0;
            Object.assign(this.tokenPosition, BOARD_SPACES[0].pos);
            this.state.lastEvent = 'Defeated — regroup at the boardwalk';
            this._fsm.transition(StoryPhase.TRAVERSAL);
          }
        }
        break;
      }
      case StoryPhase.DEFEATED: {
        if (this._fsm.timeInState * 1000 >= 1200) this._fsm.transition(StoryPhase.TRAVERSAL);
        break;
      }
      default:
        break;
    }
  }

  _renderInterpolate(alpha) {
    const p = this._prevPos, c = this.tokenPosition, r = this._renderPos;
    r.x = p.x + (c.x - p.x) * alpha;
    r.y = p.y + (c.y - p.y) * alpha;
    r.z = p.z + (c.z - p.z) * alpha;
    this.scene?.updateTokenTransform?.(r, this._tokenIndex);
  }

  _startFallbackDriver() {
    if (typeof window === 'undefined' || !window.requestAnimationFrame) return;
    this._lastRafTs = 0;
    const step = (ts) => {
      if (!this._loop || !this._loop.running) return;
      const dtMs = this._lastRafTs ? ts - this._lastRafTs : 1000 / feelConfig.timestepHz;
      this._lastRafTs = ts;
      this._loop.tick(dtMs);
      this._rafId = window.requestAnimationFrame(step);
    };
    this._rafId = window.requestAnimationFrame(step);
  }

  getState() {
    return {
      modeId: this.getModeId(),
      phase: this.state.phase,
      storyPhase: this._fsm.current,
      tokenIndex: this._tokenIndex,
      shards: Math.round(this.state.shards),
      hp: Math.round(this.state.hp),
      lastRoll: this.state.lastRoll,
      lastEvent: this.state.lastEvent,
      bossesDefeated: this.state.bossesDefeated,
      bossesTotal: this.state.bossesTotal,
      boss: this._boss ? { name: this._boss.name, hp: Math.round(this._boss.hp), maxHp: this._boss.maxHp } : null,
      canRoll: this._fsm.current === StoryPhase.TRAVERSAL,
      complete: this._fsm.current === StoryPhase.COMPLETE,
    };
  }

  end() {
    this.state.phase = ModePhase.FINISHED;
    return this.getState();
  }

  dispose() {
    this._disposed = true;
    if (this._loop) { this._loop.stop(); this._loop = null; }
    if (this._rafId !== null && typeof window !== 'undefined') {
      window.cancelAnimationFrame(this._rafId);
      this._rafId = null;
    }
    this._sensory?.dispose();
    this._sensory = null;
    this._hop.cancel();
    this.scene?.setFrameCallback?.(null);
    this.scene?.dispose();
    this.scene = null;
    this._fsm.transition(StoryPhase.TRAVERSAL);
    this.state = this._createInitialState();
  }
}

export default StoryMode;
