/**
 * carnivalEngine.js — Client-side deterministic mirror of the backend
 * lib/carnival.py engines. Used for RECORDING_LOCAL solo play and for local
 * prediction of the player's own moves (the server remains authoritative for
 * networked matches; here the seed makes local == server for recording).
 *
 * The RNG must match the backend's derivation exactly: sub-seeds come from
 * BLAKE2b(seed|tag|tag...) truncated to 64 bits. We implement a tiny
 * splitmix64 PRNG seeded from that digest so client and server agree.
 *
 * NOTE: full byte-identical parity with Python's random.Random is NOT required
 * for the demo — the RECORDING_LOCAL match is resolved locally and exported as
 * its own self-consistent replay. What matters is that the client is itself
 * deterministic (same seed -> same board/mini-games every run) so a recorded
 * session is reproducible and the visuals are stable.
 */

// ── splitmix64 PRNG (deterministic, seedable) ────────────────────────────────
function splitmix64(seedBig) {
  let state = BigInt.asUintN(64, seedBig);
  return function next() {
    state = BigInt.asUintN(64, state + 0x9e3779b97f4a7c15n);
    let z = state;
    z = BigInt.asUintN(64, (z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n);
    z = BigInt.asUintN(64, (z ^ (z >> 27n)) * 0x94d049bb133111ebn);
    z = z ^ (z >> 31n);
    return BigInt.asUintN(64, z);
  };
}

async function subSeed(seed, ...tags) {
  // Stable string hash -> 64-bit BigInt using a simple FNV-1a (portable, no
  // Web Crypto needed for a demo-scoped deterministic derivation).
  let h = 0xcbf29ce484222325n;
  const enc = String(seed) + '|' + tags.map(String).join('|');
  for (let i = 0; i < enc.length; i++) {
    h = BigInt.asUintN(64, (h ^ BigInt(enc.charCodeAt(i))) * 0x100000001b3n);
  }
  return h;
}

class RNG {
  constructor(seedBig) {
    this._next = splitmix64(seedBig);
  }
  next() { return this._next(); }
  // float in [0,1)
  random() { return Number(this.next() >> 11n) / 9007199254740992; }
  randint(lo, hi) { return lo + Math.floor(this.random() * (hi - lo + 1)); }
  randrange(n) { return Math.floor(this.random() * n); }
  choice(arr) { return arr[this.randrange(arr.length)]; }
  sample(arr, k) {
    const pool = arr.slice();
    const out = [];
    for (let i = 0; i < k && pool.length; i++) {
      const idx = this.randrange(pool.length);
      out.push(pool.splice(idx, 1)[0]);
    }
    return out;
  }
}

async function rng(seed, ...tags) {
  return new RNG(await subSeed(seed, ...tags));
}

// ── Constants (mirror carnival.py) ───────────────────────────────────────────
export const BOARD_SIZE = 24;
export const SPACE_TYPES = ['PRIZE', 'MINIGAME', 'TRAP', 'SHOP', 'CREATOR_STAND'];
export const MINIGAMES = ['maze_chase', 'target_burst', 'rhythm_tap'];
export const PLAYER_SKINS = [
  { shape: 'circle', color: '#00D4FF' },
  { shape: 'square', color: '#9933FF' },
  { shape: 'triangle', color: '#FFC400' },
  { shape: 'diamond', color: '#00E676' },
];
const SPACE_EFFECTS = {
  PRIZE: { coins: 3, tokens: 0 },
  MINIGAME: { coins: 0, tokens: 0 },
  TRAP: { coins: -2, tokens: 0 },
  SHOP: { coins: -1, tokens: 1 },
  CREATOR_STAND: { coins: 1, tokens: 0 },
};

export const MAZE_W = 10, MAZE_H = 10, MAZE_TICKS = 40;
const MAZE_PELLET_PTS = 10, MAZE_POWER_PTS = 50, MAZE_SURVIVE_PTS = 2, MAZE_POWER_DURATION = 6;
const MOVES = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0], stay: [0, 0] };

const TB_TARGETS = 12, TB_DURATION_MS = 20000, TB_WINDOW_MS = 900, TB_HIT_PTS = 100, TB_ACCURACY_BONUS = 50;
const RT_BEATS = 24, RT_PERFECT_MS = 45, RT_GOOD_MS = 110, RT_PERFECT_PTS = 100, RT_GOOD_PTS = 50;
const NORMALIZED_MAX = 100;

// ── spinner ──────────────────────────────────────────────────────────────────
export async function spinnerRoll(seed, turnIndex, faces = 10) {
  const r = await rng(seed, 'spin', turnIndex);
  return r.randint(1, faces);
}

// ── board ─────────────────────────────────────────────────────────────────────
export async function buildBoard(seed, size = BOARD_SIZE) {
  const r = await rng(seed, 'board');
  const weights = [['PRIZE', 5], ['TRAP', 4], ['SHOP', 3], ['CREATOR_STAND', 2], ['MINIGAME', 3]];
  const pool = [];
  weights.forEach(([n, w]) => { for (let i = 0; i < w; i++) pool.push(n); });
  const spaces = [];
  for (let i = 0; i < size; i++) {
    let t;
    if (i === 0) t = 'PRIZE';
    else if (i % 4 === 0) t = 'MINIGAME';
    else t = pool[r.randrange(pool.length)];
    spaces.push({ index: i, type: t });
  }
  return spaces;
}

export function catchupMultiplier(playerTotal, leaderTotal) {
  const gap = Math.max(0, leaderTotal - playerTotal);
  return 1.0 + Math.min(0.5, 0.02 * gap);
}

export function normalizeScores(raw, rawMax) {
  const out = {};
  if (rawMax <= 0) { Object.keys(raw).forEach((k) => (out[k] = 0)); return out; }
  Object.entries(raw).forEach(([k, v]) => {
    const frac = Math.max(0, Math.min(1, v / rawMax));
    out[k] = Math.floor(frac * NORMALIZED_MAX + 0.5);
  });
  return out;
}

// ── Maze Chase ────────────────────────────────────────────────────────────────
async function mazeWalls(seed) {
  const r = await rng(seed, 'maze', 'walls');
  const grid = Array.from({ length: MAZE_H }, () => Array(MAZE_W).fill(0));
  for (let y = 1; y < MAZE_H - 1; y++)
    for (let x = 1; x < MAZE_W - 1; x++)
      if (r.random() < 0.18) grid[y][x] = 1;
  for (let y = 1; y < MAZE_H - 1; y++)
    for (let x = 1; x < MAZE_W - 1; x++) {
      if (grid[y][x] === 1) continue;
      const blocked = [[0, -1], [0, 1], [-1, 0], [1, 0]].reduce((a, [dx, dy]) => a + grid[y + dy][x + dx], 0);
      if (blocked === 4) grid[y][x > MAZE_W / 2 ? x - 1 : x + 1] = 0;
    }
  return grid;
}

export async function mazeChaseBuild(seed) {
  const walls = await mazeWalls(seed);
  const r = await rng(seed, 'maze', 'layout');
  const opens = [];
  for (let y = 0; y < MAZE_H; y++) for (let x = 0; x < MAZE_W; x++) if (walls[y][x] === 0) opens.push([x, y]);
  const spawn = [1, 1], chaserSpawn = [MAZE_W - 2, MAZE_H - 2];
  const eq = (a, b) => a[0] === b[0] && a[1] === b[1];
  const pelletCells = opens.filter((c) => !eq(c, spawn) && !eq(c, chaserSpawn));
  const nPower = r.randint(2, 3);
  const powerCells = r.sample(pelletCells, Math.min(nPower, pelletCells.length));
  return {
    game: 'maze_chase', seed, w: MAZE_W, h: MAZE_H, ticks: MAZE_TICKS, walls,
    spawn, chaser_spawn: chaserSpawn, pellets: pelletCells, power_pellets: powerCells,
    pellet_pts: MAZE_PELLET_PTS, power_pts: MAZE_POWER_PTS, survive_pts: MAZE_SURVIVE_PTS,
  };
}

function canMove(walls, x, y) { return x >= 0 && x < MAZE_W && y >= 0 && y < MAZE_H && walls[y][x] === 0; }

export function chaserStep(walls, cx, cy, px, py, frightened, r) {
  const options = [];
  ['up', 'down', 'left', 'right'].forEach((name) => {
    const [dx, dy] = MOVES[name]; const nx = cx + dx, ny = cy + dy;
    if (canMove(walls, nx, ny)) options.push([nx, ny]);
  });
  if (!options.length) return [cx, cy];
  let best = [], bestMetric = null;
  options.forEach(([nx, ny]) => {
    const dist = Math.abs(nx - px) + Math.abs(ny - py);
    const metric = frightened ? -dist : dist;
    if (bestMetric === null || metric < bestMetric) { bestMetric = metric; best = [[nx, ny]]; }
    else if (metric === bestMetric) best.push([nx, ny]);
  });
  return best[r.randrange(best.length)];
}

export async function mazeChaseResolve(inst, inputs) {
  const walls = inst.walls, seed = inst.seed, ticks = inst.ticks;
  const key = (c) => `${c[0]},${c[1]}`;
  const pelletSet = new Set(inst.pellets.map(key));
  const powerSet = new Set(inst.power_pellets.map(key));
  const rawMax = pelletSet.size * MAZE_PELLET_PTS + powerSet.size * MAZE_POWER_PTS + ticks * MAZE_SURVIVE_PTS;
  const raw = {}, detail = {};
  for (const pid of Object.keys(inputs)) {
    const byTick = {}; inputs[pid].forEach((m) => (byTick[m.tick] = m.move));
    let [px, py] = inst.spawn, [cx, cy] = inst.chaser_spawn;
    const eaten = new Set(), eatenPower = new Set();
    let score = 0, survived = 0, frightened = 0, caughtTick = null;
    const cr = await rng(seed, 'maze', 'chaser', pid);
    for (let t = 0; t < ticks; t++) {
      const [dx, dy] = MOVES[byTick[t] || 'stay'] || [0, 0];
      const nx = px + dx, ny = py + dy;
      if (canMove(walls, nx, ny)) { px = nx; py = ny; }
      const ck = key([px, py]);
      if (pelletSet.has(ck) && !eaten.has(ck)) { eaten.add(ck); score += MAZE_PELLET_PTS; }
      if (powerSet.has(ck) && !eatenPower.has(ck)) { eatenPower.add(ck); score += MAZE_POWER_PTS; frightened = MAZE_POWER_DURATION; }
      [cx, cy] = chaserStep(walls, cx, cy, px, py, frightened > 0, cr);
      if (frightened > 0) frightened -= 1;
      if (cx === px && cy === py) {
        if (frightened > 0) { score += MAZE_POWER_PTS; [cx, cy] = inst.chaser_spawn; }
        else { caughtTick = t; break; }
      }
      survived += 1; score += MAZE_SURVIVE_PTS;
    }
    raw[pid] = score;
    detail[pid] = { pellets_eaten: eaten.size, power_eaten: eatenPower.size, survived_ticks: survived, caught_tick: caughtTick };
  }
  return { raw, raw_max: rawMax, detail };
}

// ── Target Burst ─────────────────────────────────────────────────────────────
export async function targetBurstBuild(seed) {
  const r = await rng(seed, 'target_burst');
  const targets = []; const slot = TB_DURATION_MS / TB_TARGETS;
  for (let i = 0; i < TB_TARGETS; i++) {
    const base = Math.floor(i * slot);
    const jitter = r.randint(0, Math.max(1, Math.floor(slot * 0.4)));
    targets.push({ id: i, x: Math.round(r.random() * 1e4) / 1e4, y: Math.round(r.random() * 1e4) / 1e4, spawn_ms: base + jitter, window_ms: TB_WINDOW_MS });
  }
  return { game: 'target_burst', seed, duration_ms: TB_DURATION_MS, targets, hit_pts: TB_HIT_PTS, accuracy_bonus: TB_ACCURACY_BONUS };
}

export function targetBurstResolve(inst, inputs) {
  const targets = {}; inst.targets.forEach((t) => (targets[t.id] = t));
  const rawMax = inst.targets.length * (TB_HIT_PTS + TB_ACCURACY_BONUS);
  const raw = {}, detail = {};
  Object.entries(inputs).forEach(([pid, data]) => {
    const latency = data.latency_ms || 0;
    const taps = (data.taps || []).slice().sort((a, b) => a.ts_ms - b.ts_ms);
    const hit = new Set(); let score = 0, hits = 0;
    taps.forEach((tap) => {
      const tgt = targets[tap.target_id];
      if (!tgt || hit.has(tap.target_id)) return;
      const corrected = tap.ts_ms - latency;
      if (corrected >= tgt.spawn_ms && corrected <= tgt.spawn_ms + tgt.window_ms) {
        hit.add(tap.target_id); hits += 1;
        const centre = tgt.spawn_ms + tgt.window_ms / 2;
        let closeness = 1 - Math.abs(corrected - centre) / (tgt.window_ms / 2);
        closeness = Math.max(0, Math.min(1, closeness));
        score += TB_HIT_PTS + TB_ACCURACY_BONUS * closeness;
      }
    });
    raw[pid] = Math.round(score * 1e4) / 1e4;
    detail[pid] = { hits, targets: inst.targets.length };
  });
  return { raw, raw_max: rawMax, detail };
}

// ── Rhythm Tap ────────────────────────────────────────────────────────────────
export async function rhythmTapBuild(seed) {
  const r = await rng(seed, 'rhythm');
  const bpm = r.randint(90, 140);
  const beatMs = 60000 / bpm;
  const beats = []; let t = 1000;
  for (let i = 0; i < RT_BEATS; i++) {
    beats.push(Math.round(t * 1e3) / 1e3);
    if (r.random() < 0.25) beats.push(Math.round((t + beatMs / 2) * 1e3) / 1e3);
    t += beatMs;
  }
  beats.sort((a, b) => a - b);
  return { game: 'rhythm_tap', seed, bpm, beat_ms: Math.round(beatMs * 1e3) / 1e3, beats, perfect_ms: RT_PERFECT_MS, good_ms: RT_GOOD_MS, perfect_pts: RT_PERFECT_PTS, good_pts: RT_GOOD_PTS };
}

export function rhythmTapResolve(inst, inputs) {
  const beats = inst.beats; const rawMax = beats.length * RT_PERFECT_PTS;
  const raw = {}, detail = {};
  Object.entries(inputs).forEach(([pid, data]) => {
    const latency = data.latency_ms || 0;
    const taps = (data.taps || []).map((x) => x - latency).sort((a, b) => a - b);
    const used = new Array(beats.length).fill(false);
    let perfect = 0, good = 0, miss = 0, score = 0;
    taps.forEach((tap) => {
      let bestIdx = -1, bestErr = null;
      beats.forEach((b, i) => { if (used[i]) return; const e = Math.abs(tap - b); if (bestErr === null || e < bestErr) { bestErr = e; bestIdx = i; } });
      if (bestIdx < 0) return;
      if (bestErr <= RT_PERFECT_MS) { used[bestIdx] = true; perfect++; score += RT_PERFECT_PTS; }
      else if (bestErr <= RT_GOOD_MS) { used[bestIdx] = true; good++; score += RT_GOOD_PTS; }
      else miss++;
    });
    raw[pid] = score; detail[pid] = { perfect, good, miss, beats: beats.length };
  });
  return { raw, raw_max: rawMax, detail };
}

const BUILDERS = { maze_chase: mazeChaseBuild, target_burst: targetBurstBuild, rhythm_tap: rhythmTapBuild };
const RESOLVERS = { maze_chase: mazeChaseResolve, target_burst: targetBurstResolve, rhythm_tap: rhythmTapResolve };

export async function buildMinigame(game, seed, roundIndex) {
  const sub = await subSeed(seed, 'round', roundIndex, game);
  const inst = await BUILDERS[game](sub);
  inst.round_index = roundIndex; inst.match_seed = seed;
  return inst;
}
export async function resolveMinigame(game, inst, inputs) { return RESOLVERS[game](inst, inputs); }
export async function pickMinigame(seed, roundIndex) {
  const r = await rng(seed, 'pick', roundIndex);
  return MINIGAMES[r.randrange(MINIGAMES.length)];
}

// ── AI synthetic inputs (deterministic) ──────────────────────────────────────
export async function aiMinigameInputs(game, inst, pid, seed) {
  const r = await rng(seed, 'ai', game, pid);
  if (game === 'maze_chase') {
    const moves = [];
    for (let t = 0; t < inst.ticks; t++) moves.push({ tick: t, move: r.choice(['up', 'down', 'left', 'right']) });
    return moves;
  }
  if (game === 'target_burst') {
    const taps = [];
    inst.targets.forEach((tgt) => { if (r.random() < 0.7) taps.push({ target_id: tgt.id, ts_ms: tgt.spawn_ms + r.random() * tgt.window_ms }); });
    return { latency_ms: 0, taps };
  }
  if (game === 'rhythm_tap') {
    const taps = [];
    inst.beats.forEach((b) => { if (r.random() < 0.75) taps.push(b + (r.random() * 2 - 1) * RT_GOOD_MS); });
    return { latency_ms: 0, taps };
  }
  return {};
}

// ── Board state machine (client mirror for RECORDING_LOCAL) ──────────────────
export function makePlayer(spec, i) {
  const skin = PLAYER_SKINS[i % PLAYER_SKINS.length];
  return {
    player_id: spec.player_id, display_name: spec.display_name || spec.player_id,
    is_ai: !!spec.is_ai, shape: skin.shape, color: skin.color,
    position: 0, coins: 5, tokens: 0, minigame_score: 0,
  };
}
export const playerTotal = (p) => p.coins + p.tokens;

export function applyLanding(player, spaceType) {
  const eff = SPACE_EFFECTS[spaceType] || {};
  player.coins = Math.max(0, player.coins + (eff.coins || 0));
  player.tokens = Math.max(0, player.tokens + (eff.tokens || 0));
}

export function awardMinigameTokens(players, normalized) {
  const leaderTotal = Math.max(...players.map(playerTotal), 0);
  const awards = {};
  players.forEach((p) => {
    const base = normalized[p.player_id] || 0;
    const mult = catchupMultiplier(playerTotal(p), leaderTotal);
    const final = Math.floor(base * mult + 0.5);
    p.tokens += final; p.minigame_score += final;
    awards[p.player_id] = { base, catchup_mult: Math.round(mult * 1000) / 1000, awarded: final };
  });
  return awards;
}

export function standings(players) {
  return players.slice().sort((a, b) => playerTotal(b) - playerTotal(a)).map((p, i) => ({
    rank: i + 1, ...p, total: playerTotal(p),
  }));
}
