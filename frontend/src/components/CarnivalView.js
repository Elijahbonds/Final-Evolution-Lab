/**
 * CarnivalView.js — Court Carnival hybrid party-mode UI (/nexus/carnival).
 *
 * Bright festival look on the premium dark base (cyan #00D4FF / purple
 * #9933FF accents). Board meta + three playable deterministic mini-games,
 * with a RECORDING_LOCAL solo mode (?recording=1) that auto-advances AI
 * opponents so one person can record a full match.
 *
 * The match is driven locally by lib/carnivalEngine.js (a deterministic
 * mirror of the backend), so the whole session is reproducible from the seed
 * and needs no live backend for the investor recording.
 */
import React, { useState, useEffect, useRef, useCallback } from 'react';
import * as E from '@/lib/carnivalEngine';

const CYAN = '#00D4FF';
const PURPLE = '#9933FF';
const AMBER = '#FFC400';
const GREEN = '#00E676';

const SFX = {
  transition: '/assets/carnival/sfx/transition.wav',
  minigame_start: '/assets/carnival/sfx/minigame_start.wav',
  reward: '/assets/carnival/sfx/reward.wav',
};
function playSfx(name) {
  try {
    const a = new Audio(SFX[name]);
    a.volume = 0.5;
    a.play().catch(() => {});
  } catch (_e) { /* ignore autoplay blocks */ }
}

// ── Shape marker (colorblind-safe: shape + color) ────────────────────────────
function ShapeMarker({ shape, color, size = 18 }) {
  const s = size;
  if (shape === 'square') return <rect x={-s / 2} y={-s / 2} width={s} height={s} fill={color} stroke="#0b0f1a" strokeWidth={2} />;
  if (shape === 'triangle') return <polygon points={`0,${-s / 2} ${s / 2},${s / 2} ${-s / 2},${s / 2}`} fill={color} stroke="#0b0f1a" strokeWidth={2} />;
  if (shape === 'diamond') return <polygon points={`0,${-s / 2} ${s / 2},0 0,${s / 2} ${-s / 2},0`} fill={color} stroke="#0b0f1a" strokeWidth={2} />;
  return <circle r={s / 2} fill={color} stroke="#0b0f1a" strokeWidth={2} />;
}

// ── Scoreboard (persistent top bar) ──────────────────────────────────────────
function Scoreboard({ players, activeId }) {
  const ranked = E.standings(players);
  return (
    <div style={{ display: 'flex', gap: 12, padding: '10px 14px', background: 'rgba(11,15,26,0.85)', borderBottom: `2px solid ${PURPLE}`, flexWrap: 'wrap' }}>
      {ranked.map((p) => (
        <div key={p.player_id} style={{
          display: 'flex', alignItems: 'center', gap: 8, padding: '6px 12px', borderRadius: 10,
          background: p.player_id === activeId ? 'rgba(0,212,255,0.18)' : 'rgba(255,255,255,0.04)',
          border: p.player_id === activeId ? `1.5px solid ${CYAN}` : '1.5px solid transparent',
        }}>
          <svg width={22} height={22} viewBox="-12 -12 24 24"><ShapeMarker shape={p.shape} color={p.color} /></svg>
          <div style={{ lineHeight: 1.1 }}>
            <div style={{ color: '#fff', fontWeight: 700, fontSize: 13 }}>{p.display_name}{p.is_ai ? ' (CPU)' : ''}</div>
            <div style={{ color: AMBER, fontSize: 12 }}>🪙 {p.coins} · 🎟️ {p.tokens} · <b style={{ color: '#fff' }}>{p.total}</b></div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ── Board ring view ──────────────────────────────────────────────────────────
const SPACE_COLORS = { PRIZE: GREEN, MINIGAME: CYAN, TRAP: '#FF5252', SHOP: AMBER, CREATOR_STAND: PURPLE };
const SPACE_ICON = { PRIZE: '🎁', MINIGAME: '🎮', TRAP: '💥', SHOP: '🛒', CREATOR_STAND: '⭐' };

function BoardRing({ board, players, spinning }) {
  const n = board.length;
  const cx = 250, cy = 250, R = 205;
  const pos = (i) => {
    const a = (i / n) * 2 * Math.PI - Math.PI / 2;
    return [cx + R * Math.cos(a), cy + R * Math.sin(a)];
  };
  return (
    <svg width="100%" viewBox="0 0 500 500" style={{ maxWidth: 500 }}>
      <defs>
        <radialGradient id="cfelt" cx="50%" cy="50%" r="60%">
          <stop offset="0%" stopColor="#141a2e" />
          <stop offset="100%" stopColor="#0b0f1a" />
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={R + 30} fill="url(#cfelt)" stroke={PURPLE} strokeWidth={2} />
      <text x={cx} y={cy - 8} textAnchor="middle" fill={CYAN} fontSize={26} fontWeight={800} style={{ letterSpacing: 2 }}>COURT</text>
      <text x={cx} y={cy + 22} textAnchor="middle" fill={AMBER} fontSize={26} fontWeight={800} style={{ letterSpacing: 2 }}>CARNIVAL</text>
      {board.map((sp) => {
        const [x, y] = pos(sp.index);
        return (
          <g key={sp.index}>
            <circle cx={x} cy={y} r={16} fill={SPACE_COLORS[sp.type]} opacity={0.9} stroke="#0b0f1a" strokeWidth={1.5} />
            <text x={x} y={y + 5} textAnchor="middle" fontSize={14}>{SPACE_ICON[sp.type]}</text>
          </g>
        );
      })}
      {players.map((p, pi) => {
        const [x, y] = pos(p.position);
        const off = pi * 7 - 10;
        return (
          <g key={p.player_id} transform={`translate(${x + off},${y - 24}) ${spinning && p.__active ? '' : ''}`}>
            <svg width={20} height={20} viewBox="-12 -12 24 24" x={-10} y={-10}><ShapeMarker shape={p.shape} color={p.color} size={16} /></svg>
          </g>
        );
      })}
    </svg>
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  MINI-GAME: Maze Chase (fully playable)
// ════════════════════════════════════════════════════════════════════════════
function MazeChaseGame({ inst, humanId, onFinish }) {
  const [tick, setTick] = useState(0);
  const [pos, setPos] = useState(inst.spawn);
  const [chaser, setChaser] = useState(inst.chaser_spawn);
  const [eaten, setEaten] = useState(new Set());
  const [frightened, setFrightened] = useState(0);
  const [score, setScore] = useState(0);
  const [dead, setDead] = useState(false);
  const movesRef = useRef([]);
  const nextMove = useRef('stay');
  const chaserRngRef = useRef(null);
  const pelletSet = useRef(new Set(inst.pellets.map((c) => `${c[0]},${c[1]}`)));
  const powerSet = useRef(new Set(inst.power_pellets.map((c) => `${c[0]},${c[1]}`)));
  const finished = useRef(false);

  useEffect(() => {
    (async () => { chaserRngRef.current = null; })();
    const onKey = (e) => {
      const k = e.key.toLowerCase();
      if (['arrowup', 'w'].includes(k)) nextMove.current = 'up';
      else if (['arrowdown', 's'].includes(k)) nextMove.current = 'down';
      else if (['arrowleft', 'a'].includes(k)) nextMove.current = 'left';
      else if (['arrowright', 'd'].includes(k)) nextMove.current = 'right';
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  // touch swipe
  const touchStart = useRef(null);
  const onTouchStart = (e) => { const t = e.touches[0]; touchStart.current = [t.clientX, t.clientY]; };
  const onTouchEnd = (e) => {
    if (!touchStart.current) return;
    const t = e.changedTouches[0];
    const dx = t.clientX - touchStart.current[0], dy = t.clientY - touchStart.current[1];
    if (Math.abs(dx) > Math.abs(dy)) nextMove.current = dx > 0 ? 'right' : 'left';
    else nextMove.current = dy > 0 ? 'down' : 'up';
  };

  const canMove = (x, y) => x >= 0 && x < E.MAZE_W && y >= 0 && y < E.MAZE_H && inst.walls[y][x] === 0;

  useEffect(() => {
    if (dead || finished.current) return;
    if (tick >= inst.ticks) { finishGame(); return; }
    const id = setTimeout(async () => {
      // local prediction of own move; deterministic chaser
      const mv = nextMove.current; nextMove.current = 'stay';
      movesRef.current.push({ tick, move: mv });
      const MOVES = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0], stay: [0, 0] };
      let [px, py] = pos; const [dx, dy] = MOVES[mv];
      if (canMove(px + dx, py + dy)) { px += dx; py += dy; }
      let s = score, fr = frightened;
      const ck = `${px},${py}`;
      const newEaten = new Set(eaten);
      if (pelletSet.current.has(ck) && !eaten.has(ck)) { newEaten.add(ck); s += inst.pellet_pts; }
      if (powerSet.current.has(ck) && !eaten.has(ck)) { newEaten.add(ck); s += inst.power_pts; fr = 6; playSfx('reward'); }
      // chaser
      if (!chaserRngRef.current) chaserRngRef.current = true;
      const cr = { randrange: (m) => (px + py + tick) % m }; // light deterministic tiebreak for UI
      let [cx, cy] = E.chaserStep(inst.walls, chaser[0], chaser[1], px, py, fr > 0, cr);
      let ded = false;
      if (fr > 0) fr -= 1;
      if (cx === px && cy === py) {
        if (fr > 0) { s += inst.power_pts; [cx, cy] = inst.chaser_spawn; }
        else ded = true;
      }
      if (!ded) s += inst.survive_pts;
      setPos([px, py]); setChaser([cx, cy]); setEaten(newEaten); setScore(s); setFrightened(fr);
      if (ded) { setDead(true); finishGame(newEaten, s); } else setTick(tick + 1);
    }, 200);
    return () => clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick, dead]);

  const finishGame = (finalEaten = eaten, finalScore = score) => {
    if (finished.current) return; finished.current = true;
    onFinish({ moves: movesRef.current });
  };

  const cell = 30;
  return (
    <div style={{ textAlign: 'center' }} onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
      <div style={{ color: CYAN, fontWeight: 700, marginBottom: 6 }}>
        MAZE CHASE · Tick {tick}/{inst.ticks} · 🟡 {eaten.size}/{inst.pellets.length} · Score {score}
      </div>
      <svg width={E.MAZE_W * cell} height={E.MAZE_H * cell} style={{ background: '#0b0f1a', borderRadius: 10, border: `2px solid ${PURPLE}`, maxWidth: '100%' }} viewBox={`0 0 ${E.MAZE_W * cell} ${E.MAZE_H * cell}`}>
        {inst.walls.map((row, y) => row.map((w, x) => w ? <rect key={`${x},${y}`} x={x * cell} y={y * cell} width={cell} height={cell} fill={PURPLE} opacity={0.35} /> : null))}
        {inst.pellets.map((c) => !eaten.has(`${c[0]},${c[1]}`) && <circle key={`p${c}`} cx={c[0] * cell + cell / 2} cy={c[1] * cell + cell / 2} r={3} fill="#fff" />)}
        {inst.power_pellets.map((c) => !eaten.has(`${c[0]},${c[1]}`) && <circle key={`pp${c}`} cx={c[0] * cell + cell / 2} cy={c[1] * cell + cell / 2} r={7} fill={AMBER} />)}
        <g transform={`translate(${pos[0] * cell + cell / 2},${pos[1] * cell + cell / 2})`}><ShapeMarker shape="circle" color={CYAN} size={20} /></g>
        <g transform={`translate(${chaser[0] * cell + cell / 2},${chaser[1] * cell + cell / 2})`}><circle r={11} fill={frightened > 0 ? '#4488ff' : '#FF5252'} /><text y={4} textAnchor="middle" fontSize={12}>{frightened > 0 ? '😱' : '👻'}</text></g>
      </svg>
      <div style={{ color: '#7f8fb0', marginTop: 8, fontSize: 13 }}>Arrows / WASD to move · swipe on touch · eat pellets, dodge the chaser</div>
      {dead && <div style={{ color: '#FF5252', fontWeight: 800, marginTop: 6 }}>CAUGHT! Resolving…</div>}
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  MINI-GAME: Target Burst (tap targets in their window)
// ════════════════════════════════════════════════════════════════════════════
function TargetBurstGame({ inst, onFinish }) {
  const [now, setNow] = useState(0);
  const [flash, setFlash] = useState(null);
  const tapsRef = useRef([]);
  const start = useRef(performance.now());
  const finished = useRef(false);

  useEffect(() => {
    let raf;
    const loop = () => {
      const t = performance.now() - start.current;
      setNow(t);
      if (t >= inst.duration_ms + 500) { if (!finished.current) { finished.current = true; onFinish({ latency_ms: 0, taps: tapsRef.current }); } return; }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const active = inst.targets.filter((t) => now >= t.spawn_ms && now <= t.spawn_ms + t.window_ms && !tapsRef.current.some((x) => x.target_id === t.id));
  const onTap = (tgt) => {
    tapsRef.current.push({ target_id: tgt.id, ts_ms: now });
    const centre = tgt.spawn_ms + tgt.window_ms / 2;
    const closeness = 1 - Math.abs(now - centre) / (tgt.window_ms / 2);
    setFlash({ id: tgt.id, label: closeness > 0.6 ? 'PERFECT' : 'GOOD', color: closeness > 0.6 ? GREEN : AMBER });
    playSfx('reward');
    setTimeout(() => setFlash(null), 300);
  };

  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ color: CYAN, fontWeight: 700, marginBottom: 6 }}>TARGET BURST · {(Math.max(0, (inst.duration_ms - now) / 1000)).toFixed(1)}s · Hits {tapsRef.current.length}</div>
      <div style={{ position: 'relative', width: 320, height: 320, margin: '0 auto', background: '#0b0f1a', borderRadius: 12, border: `2px solid ${PURPLE}`, overflow: 'hidden' }}>
        {active.map((t) => {
          const age = (now - t.spawn_ms) / t.window_ms;
          return (
            <button key={t.id} onClick={() => onTap(t)} style={{
              position: 'absolute', left: `${t.x * 88 + 6}%`, top: `${t.y * 88 + 6}%`,
              width: 44, height: 44, borderRadius: '50%', transform: 'translate(-50%,-50%)',
              background: `radial-gradient(circle, ${AMBER}, ${PURPLE})`, border: `3px solid ${CYAN}`,
              opacity: 1 - Math.abs(age - 0.5), cursor: 'pointer', color: '#fff', fontWeight: 800,
            }}>◎</button>
          );
        })}
        {flash && <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', color: flash.color, fontWeight: 900, fontSize: 34, textShadow: '0 0 12px #000' }}>{flash.label}</div>}
      </div>
      <div style={{ color: '#7f8fb0', marginTop: 8, fontSize: 13 }}>Tap targets while they glow — centre = PERFECT</div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  MINI-GAME: Rhythm Tap
// ════════════════════════════════════════════════════════════════════════════
function RhythmTapGame({ inst, onFinish }) {
  const [now, setNow] = useState(0);
  const [flash, setFlash] = useState(null);
  const tapsRef = useRef([]);
  const start = useRef(performance.now());
  const finished = useRef(false);
  const endMs = inst.beats[inst.beats.length - 1] + 800;

  useEffect(() => {
    let raf;
    const loop = () => {
      const t = performance.now() - start.current;
      setNow(t);
      if (t >= endMs) { if (!finished.current) { finished.current = true; onFinish({ latency_ms: 0, taps: tapsRef.current }); } return; }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const tap = () => {
    tapsRef.current.push(now);
    let bestErr = Infinity;
    inst.beats.forEach((b) => { bestErr = Math.min(bestErr, Math.abs(now - b)); });
    let label = 'MISS', color = '#FF5252';
    if (bestErr <= inst.perfect_ms) { label = 'PERFECT'; color = GREEN; playSfx('reward'); }
    else if (bestErr <= inst.good_ms) { label = 'GOOD'; color = AMBER; }
    setFlash({ label, color, t: now });
    setTimeout(() => setFlash((f) => (f && f.t === now ? null : f)), 250);
  };

  useEffect(() => {
    const onKey = (e) => { if (e.code === 'Space' || e.key === ' ') { e.preventDefault(); tap(); } };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [now]);

  // approaching beats on a lane
  const lane = inst.beats.filter((b) => b - now > -300 && b - now < 1600);
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ color: CYAN, fontWeight: 700, marginBottom: 6 }}>RHYTHM TAP · {inst.bpm} BPM · Taps {tapsRef.current.length}</div>
      <div style={{ position: 'relative', width: 320, height: 260, margin: '0 auto', background: '#0b0f1a', borderRadius: 12, border: `2px solid ${PURPLE}`, overflow: 'hidden' }}>
        <div style={{ position: 'absolute', bottom: 40, left: 0, right: 0, height: 4, background: CYAN, opacity: 0.6 }} />
        <div style={{ position: 'absolute', bottom: 24, left: '50%', transform: 'translateX(-50%)', width: 60, height: 60, borderRadius: '50%', border: `3px solid ${AMBER}` }} />
        {lane.map((b, i) => {
          const y = 220 - ((b - now) / 1600) * 180;
          return <div key={i} style={{ position: 'absolute', left: '50%', top: y, transform: 'translate(-50%,-50%)', width: 40, height: 40, borderRadius: '50%', background: PURPLE, border: `2px solid ${CYAN}` }} />;
        })}
        {flash && <div style={{ position: 'absolute', top: 30, left: 0, right: 0, color: flash.color, fontWeight: 900, fontSize: 28 }}>{flash.label}</div>}
      </div>
      <button onClick={tap} style={{ marginTop: 12, padding: '14px 40px', fontSize: 18, fontWeight: 800, borderRadius: 12, background: `linear-gradient(90deg,${CYAN},${PURPLE})`, color: '#fff', border: 'none', cursor: 'pointer' }}>TAP (or Space)</button>
      <div style={{ color: '#7f8fb0', marginTop: 8, fontSize: 13 }}>Hit when a note reaches the ring</div>
    </div>
  );
}

const MINIGAME_COMPONENTS = { maze_chase: MazeChaseGame, target_burst: TargetBurstGame, rhythm_tap: RhythmTapGame };

// ════════════════════════════════════════════════════════════════════════════
//  Root CarnivalView — drives the whole local match
// ════════════════════════════════════════════════════════════════════════════
export default function CarnivalView({ recording: recordingProp }) {
  const params = typeof window !== 'undefined' ? new URLSearchParams(window.location.search) : new URLSearchParams();
  const recording = recordingProp ?? (params.get('recording') === '1');
  const seedParam = params.get('seed');
  const [seed] = useState(() => (seedParam ? Number(seedParam) : Math.floor(Math.random() * 1e9)));

  const [board, setBoard] = useState(null);
  const [players, setPlayers] = useState([]);
  const [phase, setPhase] = useState('loading'); // loading | board | transition | minigame | end
  const [activeIdx, setActiveIdx] = useState(0);
  const [turn, setTurn] = useState(0);
  const [round, setRound] = useState(0);
  const [pending, setPending] = useState(null); // {game, inst}
  const [lastSpin, setLastSpin] = useState(null);
  const [spinning, setSpinning] = useState(false);
  const [events, setEvents] = useState([]);
  const [highlights, setHighlights] = useState([]);
  const [lastResult, setLastResult] = useState(null);
  const ROUNDS = 8;

  const logEvent = useCallback((ev) => setEvents((e) => [...e, { ...ev, seq: e.length }]), []);

  // init
  useEffect(() => {
    (async () => {
      const b = await E.buildBoard(seed);
      const specs = [{ player_id: 'you', display_name: 'YOU', is_ai: false }];
      let i = 1;
      while (specs.length < 4) { specs.push({ player_id: `cpu_${i}`, display_name: `CPU ${i}`, is_ai: true }); i++; }
      const ps = specs.map((s, idx) => E.makePlayer(s, idx));
      setBoard(b); setPlayers(ps); setPhase('board');
      logEvent({ type: 'carnival_match_start', seed, rounds: ROUNDS, players: ps.map((p) => p.player_id), board: b });
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const activePlayer = players[activeIdx];

  const doSpin = useCallback(async () => {
    if (!board || phase !== 'board' || spinning) return;
    setSpinning(true);
    const roll = await E.spinnerRoll(seed, turn);
    // animate 450ms
    await new Promise((r) => setTimeout(r, 450));
    const ps = players.map((p) => ({ ...p }));
    const p = ps[activeIdx];
    const from = p.position;
    p.position = (p.position + roll) % board.length;
    const spaceType = board[p.position].type;
    E.applyLanding(p, spaceType);
    setPlayers(ps);
    setLastSpin({ player: p.display_name, roll, spaceType });
    const spinEv = { type: 'carnival_spin', turn_index: turn, player_id: p.player_id, roll, from, to: p.position, space_type: spaceType, coins: p.coins, tokens: p.tokens };
    logEvent(spinEv);
    setSpinning(false);

    const trigger = spaceType === 'MINIGAME' || (turn > 0 && turn % 3 === 0);
    const nextTurn = turn + 1;
    setTurn(nextTurn);
    if (trigger && round < ROUNDS) {
      const game = await E.pickMinigame(seed, round);
      const inst = await E.buildMinigame(game, seed, round);
      setPending({ game, inst });
      playSfx('transition');
      setPhase('transition');
      setTimeout(() => { playSfx('minigame_start'); setPhase('minigame'); }, 500);
    } else {
      setActiveIdx((activeIdx + 1) % players.length);
    }
  }, [board, phase, spinning, seed, turn, players, activeIdx, round, logEvent]);

  const onMinigameFinish = useCallback(async (humanInput) => {
    const { game, inst } = pending;
    // Normalize the human payload to the per-game input contract: maze wants a
    // bare move array (unwrap {moves}); tap games want {latency_ms, taps}.
    const you = game === 'maze_chase' ? (humanInput.moves || []) : humanInput;
    const inputs = { you };
    for (const p of players) if (p.is_ai) inputs[p.player_id] = await E.aiMinigameInputs(game, inst, p.player_id, seed);
    const result = await E.resolveMinigame(game, inst, inputs);
    const normalized = E.normalizeScores(result.raw, result.raw_max);
    const ps = players.map((p) => ({ ...p }));
    const awards = E.awardMinigameTokens(ps, normalized);
    setPlayers(ps);
    setLastResult({ game, normalized, awards, detail: result.detail });
    logEvent({ type: 'carnival_minigame_result', game, round_index: round, instance: inst, inputs, raw: result.raw, raw_max: result.raw_max, normalized, awards, detail: result.detail });
    playSfx('reward');
    const nextRound = round + 1;
    setRound(nextRound);
    setPending(null);
    playSfx('transition');
    if (nextRound >= ROUNDS) {
      const hl = buildHighlights([...events, { type: 'carnival_minigame_result', game, round_index: round, normalized, awards }]);
      setHighlights(hl);
      logEvent({ type: 'carnival_match_end', status: 'finished', standings: E.standings(ps) });
      setPhase('end');
    } else {
      setPhase('board');
      setActiveIdx((activeIdx + 1) % players.length);
    }
  }, [pending, players, seed, round, activeIdx, events, logEvent]);

  // RECORDING_LOCAL: auto-advance the board so one person can record hands-free
  // (mini-games still let the human play; AI spins auto-resolve).
  useEffect(() => {
    if (!recording || phase !== 'board' || spinning) return;
    const id = setTimeout(() => { doSpin(); }, 900);
    return () => clearTimeout(id);
  }, [recording, phase, spinning, doSpin]);

  const exportReplay = () => {
    const replay = {
      metadata: { match_id: `local_${seed}`, mode_id: 'carnival_board', seed, replay_kind: 'carnival', players: players.map((p) => p.player_id), rounds: ROUNDS, status: 'finished', event_count: events.length },
      events,
    };
    const blob = new Blob([JSON.stringify(replay, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = `carnival_replay_${seed}.json`; a.click();
  };

  if (phase === 'loading' || !board) return <div style={{ color: '#fff', padding: 40 }}>Loading Carnival…</div>;

  const MiniGame = pending ? MINIGAME_COMPONENTS[pending.game] : null;

  return (
    <div style={{ minHeight: '100vh', background: 'linear-gradient(160deg,#0b0f1a,#141024)', color: '#fff', fontFamily: 'Inter,system-ui,sans-serif' }}>
      <Scoreboard players={players} activeId={activePlayer?.player_id} />
      <div style={{ display: 'flex', justifyContent: 'space-between', padding: '6px 14px', fontSize: 13, color: '#7f8fb0' }}>
        <span>Round {Math.min(round + 1, ROUNDS)}/{ROUNDS} · Turn {turn}</span>
        {recording && <span style={{ color: AMBER }}>● REC · seed {seed}</span>}
      </div>

      {phase === 'board' && (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: 12 }}>
          <BoardRing board={board} players={players.map((p, i) => ({ ...p, __active: i === activeIdx }))} spinning={spinning} />
          {lastSpin && <div style={{ marginTop: 8, color: CYAN }}>{lastSpin.player} rolled <b>{lastSpin.roll}</b> → {SPACE_ICON[lastSpin.spaceType]} {lastSpin.spaceType}</div>}
          {!recording && <button onClick={doSpin} disabled={spinning} data-testid="spin-btn" style={{ marginTop: 14, padding: '14px 44px', fontSize: 18, fontWeight: 800, borderRadius: 12, background: spinning ? '#333' : `linear-gradient(90deg,${CYAN},${PURPLE})`, color: '#fff', border: 'none', cursor: spinning ? 'default' : 'pointer' }}>{spinning ? 'SPINNING…' : `SPIN (${activePlayer?.display_name})`}</button>}
          {recording && spinning && <div style={{ marginTop: 14, color: AMBER, fontWeight: 700 }}>SPINNING…</div>}
        </div>
      )}

      {phase === 'transition' && (
        <div style={{ textAlign: 'center', padding: 60, animation: 'pulse 0.5s' }}>
          <div style={{ fontSize: 40, fontWeight: 900, color: CYAN }}>🎮 {pending?.game?.replace('_', ' ').toUpperCase()}</div>
          <div style={{ color: '#7f8fb0', marginTop: 10 }}>Get ready…</div>
        </div>
      )}

      {phase === 'minigame' && MiniGame && (
        <div style={{ padding: 16 }}>
          <MiniGame inst={pending.inst} humanId="you" onFinish={onMinigameFinish} />
        </div>
      )}

      {phase === 'end' && (
        <EndScreen players={players} highlights={highlights} onExport={exportReplay} onReplay={() => window.location.reload()} />
      )}
    </div>
  );
}

function buildHighlights(events) {
  const plays = [];
  events.forEach((ev) => {
    if (ev.type === 'carnival_minigame_result' && ev.normalized) {
      const best = Object.keys(ev.normalized).reduce((a, b) => (ev.normalized[b] > (ev.normalized[a] ?? -1) ? b : a), null);
      if (best) plays.push({ kind: 'minigame_win', round: ev.round_index, game: ev.game, player_id: best, normalized: ev.normalized[best], awarded: ev.awards?.[best]?.awarded ?? 0, catchup_mult: ev.awards?.[best]?.catchup_mult ?? 1 });
    }
  });
  plays.sort((a, b) => (b.catchup_mult - a.catchup_mult) || (b.normalized - a.normalized));
  return plays.slice(0, 8);
}

function EndScreen({ players, highlights, onExport, onReplay }) {
  const ranked = E.standings(players);
  return (
    <div style={{ padding: 24, textAlign: 'center' }}>
      <div style={{ fontSize: 36, fontWeight: 900, color: AMBER }}>🏆 {ranked[0].display_name} WINS!</div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 16, marginTop: 20, flexWrap: 'wrap' }}>
        {ranked.map((p) => (
          <div key={p.player_id} style={{ background: 'rgba(255,255,255,0.05)', border: `2px solid ${p.rank === 1 ? AMBER : '#333'}`, borderRadius: 12, padding: 16, minWidth: 130 }}>
            <svg width={28} height={28} viewBox="-12 -12 24 24"><ShapeMarker shape={p.shape} color={p.color} /></svg>
            <div style={{ fontWeight: 800, marginTop: 6 }}>#{p.rank} {p.display_name}</div>
            <div style={{ color: CYAN }}>{p.total} pts</div>
            <div style={{ color: '#7f8fb0', fontSize: 12 }}>🪙 {p.coins} · 🎟️ {p.tokens}</div>
          </div>
        ))}
      </div>
      <h3 style={{ color: PURPLE, marginTop: 30 }}>✨ Highlight Reel</h3>
      <div style={{ maxWidth: 520, margin: '0 auto', textAlign: 'left' }}>
        {highlights.map((h, i) => (
          <div key={i} style={{ background: 'rgba(0,212,255,0.08)', borderRadius: 8, padding: '8px 12px', margin: '6px 0', display: 'flex', justifyContent: 'space-between' }}>
            <span>Round {h.round + 1} · <b style={{ color: CYAN }}>{h.game.replace('_', ' ')}</b> won by {h.player_id}</span>
            <span style={{ color: h.catchup_mult > 1 ? GREEN : '#fff' }}>{h.normalized} → +{h.awarded}{h.catchup_mult > 1 ? ` (×${h.catchup_mult} comeback!)` : ''}</span>
          </div>
        ))}
      </div>
      <div style={{ marginTop: 24, display: 'flex', gap: 12, justifyContent: 'center' }}>
        <button onClick={onExport} style={{ padding: '12px 28px', borderRadius: 10, background: PURPLE, color: '#fff', border: 'none', fontWeight: 700, cursor: 'pointer' }}>Export Replay JSON</button>
        <button onClick={onReplay} style={{ padding: '12px 28px', borderRadius: 10, background: CYAN, color: '#0b0f1a', border: 'none', fontWeight: 700, cursor: 'pointer' }}>New Match</button>
      </div>
    </div>
  );
}
