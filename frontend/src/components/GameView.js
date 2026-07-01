/**
 * GameView — Nexus-ready match UI component
 *
 * Props:
 *   matchId  {string}  — existing match ID to join/observe
 *   userId   {string}  — authenticated user ID
 *   onExit   {fn}      — callback when user leaves match
 *
 * Features:
 *   - Creates or joins a match via REST API
 *   - Connects to /ws/match/{matchId} for live events
 *   - Renders players, live scoreboard, Creator Card loadouts, event log
 *   - Handles match_start, score_event, match_end messages
 */
import React, { useEffect, useRef, useState, useCallback } from 'react';

const API_BASE = process.env.REACT_APP_BACKEND_URL || '';
const WS_BASE = API_BASE.replace(/^http/, 'ws');

const styles = {
  container: {
    background: '#08090b',
    color: '#e8eaf0',
    minHeight: '100vh',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
    padding: '24px',
  },
  header: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: '24px',
  },
  title: { fontSize: '1.4rem', fontWeight: 800, color: '#00e5ff', margin: 0 },
  badge: (color) => ({
    padding: '4px 12px',
    borderRadius: '20px',
    fontSize: '0.75rem',
    fontWeight: 700,
    letterSpacing: '0.1em',
    textTransform: 'uppercase',
    background: color === 'active' ? 'rgba(0,229,255,0.15)' : 'rgba(255,215,0,0.1)',
    color: color === 'active' ? '#00e5ff' : '#ffd700',
    border: `1px solid ${color === 'active' ? 'rgba(0,229,255,0.3)' : 'rgba(255,215,0,0.2)'}`,
  }),
  grid: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '24px' },
  card: {
    background: '#0d1018',
    border: '1px solid rgba(0,229,255,0.15)',
    borderRadius: '16px',
    padding: '16px 20px',
  },
  cardTitle: { fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '0.1em', color: '#6b7280', marginBottom: '8px' },
  score: { fontSize: '3rem', fontWeight: 800, color: '#00e5ff', lineHeight: 1 },
  playerName: { fontSize: '0.9rem', color: '#9ca3af', marginTop: '4px' },
  loadoutBadge: {
    display: 'inline-block',
    padding: '2px 8px',
    borderRadius: '20px',
    fontSize: '0.68rem',
    background: 'rgba(192,132,252,0.12)',
    color: '#c084fc',
    border: '1px solid rgba(192,132,252,0.2)',
    margin: '2px 4px 2px 0',
  },
  eventLog: {
    background: '#0d1018',
    border: '1px solid rgba(0,229,255,0.1)',
    borderRadius: '16px',
    padding: '16px 20px',
    maxHeight: '280px',
    overflowY: 'auto',
  },
  eventItem: (type) => ({
    padding: '6px 10px',
    marginBottom: '4px',
    borderRadius: '8px',
    fontSize: '0.82rem',
    background: type === 'score_event' ? 'rgba(0,229,255,0.06)'
      : type === 'match_start' ? 'rgba(52,211,153,0.08)'
      : 'rgba(255,255,255,0.03)',
    borderLeft: `3px solid ${
      type === 'score_event' ? '#00e5ff'
      : type === 'match_start' ? '#34d399'
      : '#374151'
    }`,
  }),
  statusLine: { color: '#6b7280', fontSize: '0.82rem', marginBottom: '8px' },
  debugPanel: {
    background: '#0a0c10',
    border: '1px solid rgba(255,215,0,0.18)',
    borderRadius: '12px',
    padding: '12px 16px',
    marginBottom: '16px',
    fontSize: '0.78rem',
    color: '#ffd700',
    fontFamily: 'monospace',
  },
  debugTitle: { fontSize: '0.68rem', textTransform: 'uppercase', letterSpacing: '0.1em', color: '#6b7280', marginBottom: '6px' },
  btn: {
    padding: '10px 24px',
    borderRadius: '8px',
    border: 'none',
    fontWeight: 700,
    cursor: 'pointer',
    fontSize: '0.9rem',
  },
};

// ── Sub-components ──────────────────────────────────────────────────────────

function PlayerCard({ player, score, loadout = [] }) {
  return (
    <div style={styles.card}>
      <div style={styles.cardTitle}>Player</div>
      <div style={styles.score}>{score}</div>
      <div style={styles.playerName}>{player}</div>
      {loadout.length > 0 && (
        <div style={{ marginTop: '10px' }}>
          <div style={{ ...styles.cardTitle, marginBottom: '4px' }}>Cards</div>
          {loadout.map((c, i) => (
            <span key={i} style={styles.loadoutBadge}>{c.title || c.id}</span>
          ))}
        </div>
      )}
    </div>
  );
}

function EventLog({ events }) {
  const bottomRef = useRef(null);
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [events]);

  return (
    <div style={styles.eventLog}>
      <div style={styles.cardTitle}>Live Event Log</div>
      {events.length === 0 && <div style={styles.statusLine}>Waiting for events…</div>}
      {events.map((ev, i) => (
        <div key={i} style={styles.eventItem(ev.type)}>
          <strong>{ev.type}</strong>
          {ev.player_id && ` — ${ev.player_id}`}
          {ev.points !== undefined && ` +${ev.points}pts`}
          {ev.seq !== undefined && <span style={{ color: '#6b7280' }}> #{ev.seq}</span>}
        </div>
      ))}
      <div ref={bottomRef} />
    </div>
  );
}

// ── Main component ──────────────────────────────────────────────────────────

export default function GameView({ matchId: initialMatchId, userId, onExit }) {
  const [matchId, setMatchId] = useState(initialMatchId || null);
  const [status, setStatus] = useState('idle');
  const [players, setPlayers] = useState([]);
  const [score, setScore] = useState({});
  const [loadouts, setLoadouts] = useState({});
  const [events, setEvents] = useState([]);
  const [wsStatus, setWsStatus] = useState('disconnected');
  const [error, setError] = useState(null);
  const [seed, setSeed] = useState(null);
  const [judgeOffsets, setJudgeOffsets] = useState([]);
  const [ghostPublished, setGhostPublished] = useState(null);
  const [ghostFeed, setGhostFeed] = useState([]);
  const [ghostFeedVisible, setGhostFeedVisible] = useState(false);
  const [activeChallenge, setActiveChallenge] = useState(null);
  const wsRef = useRef(null);

  const addEvent = useCallback((ev) => {
    setEvents((prev) => [...prev.slice(-99), ev]);
  }, []);

  // ── WebSocket connection ────────────────────────────────────────────────
  const connectWs = useCallback((mid) => {
    if (wsRef.current) wsRef.current.close();
    const url = `${WS_BASE}/ws/match/${mid}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => setWsStatus('connected');
    ws.onclose = () => setWsStatus('disconnected');
    ws.onerror = () => setWsStatus('error');

    ws.onmessage = (e) => {
      let msg;
      try { msg = JSON.parse(e.data); } catch { return; }

      addEvent(msg);

      switch (msg.type) {
        case 'match_state':
          setStatus(msg.match.status);
          setPlayers(msg.match.players || []);
          setScore(msg.match.score || {});
          break;
        case 'match_start':
          setStatus('active');
          setPlayers(msg.players.map((p) => p.user_id));
          if (msg.seed != null) setSeed(msg.seed);
          if (msg.judge_offsets) setJudgeOffsets(msg.judge_offsets);
          const newLoadouts = {};
          msg.players.forEach((p) => { newLoadouts[p.user_id] = p.loadout || []; });
          setLoadouts(newLoadouts);
          break;
        case 'score_event':
          setScore((prev) => ({
            ...prev,
            [msg.player_id]: (prev[msg.player_id] || 0) + (msg.points || 0),
          }));
          break;
        case 'match_end':
          setStatus('finished');
          if (msg.score) setScore(msg.score);
          break;
        default:
          break;
      }
    };
  }, [addEvent]);

  // ── REST helpers ────────────────────────────────────────────────────────
  const createMatch = async () => {
    setError(null);
    try {
      const r = await fetch(`${API_BASE}/api/matches/create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ mode_id: 'basketball_h2h' }),
      });
      if (!r.ok) throw new Error(await r.text());
      const data = await r.json();
      setMatchId(data.match_id);
      setStatus(data.status);
      connectWs(data.match_id);
    } catch (err) {
      setError(err.message);
    }
  };

  const downloadReplay = async () => {
    if (!matchId) return;
    try {
      const r = await fetch(`${API_BASE}/api/matches/${matchId}/export-replay`, { credentials: 'include' });
      if (!r.ok) throw new Error(await r.text());
      const data = await r.json();
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `replay-${matchId}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(`Replay export failed: ${err.message}`);
    }
  };

  const publishGhost = async () => {
    if (!matchId || !seed) return;
    try {
      const exportR = await fetch(`${API_BASE}/api/matches/${matchId}/export-replay`, { credentials: 'include' });
      if (!exportR.ok) throw new Error(await exportR.text());
      const replay = await exportR.json();
      const r = await fetch(`${API_BASE}/api/ghost/publish`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          mode_id: replay.mode_id || 'basketball_h2h',
          seed: replay.seed,
          judge_offsets: replay.judge_offsets || [],
          events: replay.events || [],
          final_score: Object.fromEntries(
            (replay.players || []).map((p) => [p, Object.values(score)[0] || 0])
          ),
          match_id: matchId,
        }),
      });
      if (!r.ok) throw new Error(await r.text());
      const data = await r.json();
      setGhostPublished(data);
    } catch (err) {
      setError(`Ghost publish failed: ${err.message}`);
    }
  };

  const loadGhostFeed = async (modeId) => {
    try {
      const url = modeId
        ? `${API_BASE}/api/ghost?mode_id=${encodeURIComponent(modeId)}&limit=10`
        : `${API_BASE}/api/ghost?limit=10`;
      const r = await fetch(url, { credentials: 'include' });
      if (!r.ok) throw new Error(await r.text());
      setGhostFeed(await r.json());
      setGhostFeedVisible(true);
    } catch (err) {
      setError(`Ghost feed failed: ${err.message}`);
    }
  };

  const startGhostChallenge = async (ghostId) => {
    try {
      const r = await fetch(`${API_BASE}/api/ghost/${ghostId}/challenge`, {
        method: 'POST',
        credentials: 'include',
      });
      if (!r.ok) throw new Error(await r.text());
      setActiveChallenge(await r.json());
    } catch (err) {
      setError(`Challenge start failed: ${err.message}`);
    }
  };

  const joinMatch = async (mid) => {
    setError(null);
    try {
      const r = await fetch(`${API_BASE}/api/matches/join`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ match_id: mid }),
      });
      if (!r.ok) throw new Error(await r.text());
      const data = await r.json();
      setStatus(data.status);
      setPlayers(data.players || []);
    } catch (err) {
      setError(err.message);
    }
  };

  // ── Auto-connect WS if matchId provided ────────────────────────────────
  useEffect(() => {
    if (matchId) {
      connectWs(matchId);
      fetch(`${API_BASE}/api/matches/${matchId}`, { credentials: 'include' })
        .then((r) => r.ok ? r.json() : null)
        .then((data) => {
          if (!data) return;
          setStatus(data.status);
          setPlayers(data.players?.map((p) => p.user_id) || []);
          setScore(data.score || {});
          setLoadouts(data.loadouts || {});
          setEvents(data.events || []);
          if (data.seed != null) setSeed(data.seed);
          if (data.judge_offsets) setJudgeOffsets(data.judge_offsets);
        })
        .catch(() => {});
    }
    return () => wsRef.current?.close();
  }, [matchId, connectWs]);

  // ── Render ──────────────────────────────────────────────────────────────
  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>
          {matchId ? `Match ${matchId}` : 'Game View'}
        </h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          {status !== 'idle' && (
            <span style={styles.badge(status)}>
              {status} · WS {wsStatus}
            </span>
          )}
          {onExit && (
            <button
              style={{ ...styles.btn, background: '#1f2937', color: '#9ca3af' }}
              onClick={onExit}
            >
              Exit
            </button>
          )}
        </div>
      </div>

      {error && (
        <div style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)',
          borderRadius: '10px', padding: '12px 16px', marginBottom: '16px', color: '#f87171' }}>
          {error}
        </div>
      )}

      {!matchId && (
        <div style={{ ...styles.card, marginBottom: '24px' }}>
          <div style={{ marginBottom: '16px', color: '#9ca3af' }}>No active match. Create one or enter a Match ID to join.</div>
          <button
            style={{ ...styles.btn, background: '#00e5ff', color: '#08090b', marginRight: '12px' }}
            onClick={createMatch}
          >
            Create Match
          </button>
        </div>
      )}

      {matchId && seed != null && (
        <div style={styles.debugPanel}>
          <div style={styles.debugTitle}>Nexus QA — Match Seed &amp; Judge Offsets</div>
          <div>seed: <strong>{String(seed)}</strong></div>
          <div>judge_offsets: <strong>[{judgeOffsets.join(', ')}]</strong></div>
          <button
            style={{ ...styles.btn, marginTop: '8px', padding: '6px 14px', fontSize: '0.75rem',
              background: 'rgba(255,215,0,0.12)', color: '#ffd700', border: '1px solid rgba(255,215,0,0.3)' }}
            onClick={downloadReplay}
          >
            Download Replay JSON
          </button>
          {status === 'finished' && !ghostPublished && (
            <button
              style={{ ...styles.btn, marginTop: '8px', marginLeft: '8px', padding: '6px 14px', fontSize: '0.75rem',
                background: 'rgba(0,229,255,0.12)', color: '#00e5ff', border: '1px solid rgba(0,229,255,0.3)' }}
              onClick={publishGhost}
            >
              👻 Save as Ghost Challenge
            </button>
          )}
          {ghostPublished && (
            <div style={{ marginTop: '8px', fontSize: '0.75rem', color: '#00e5ff' }}>
              ✓ Ghost published — ID: <strong>{ghostPublished.ghost_id}</strong>
            </div>
          )}
        </div>
      )}

      <div style={{ marginBottom: '16px', display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
        <button
          style={{ ...styles.btn, padding: '6px 14px', fontSize: '0.75rem',
            background: 'rgba(139,92,246,0.15)', color: '#a78bfa', border: '1px solid rgba(139,92,246,0.3)' }}
          onClick={() => ghostFeedVisible ? setGhostFeedVisible(false) : loadGhostFeed()}
        >
          {ghostFeedVisible ? 'Hide Ghost Feed' : '👻 Ghost Challenge Feed'}
        </button>
      </div>

      {ghostFeedVisible && (
        <div style={{ ...styles.card, marginBottom: '24px' }}>
          <div style={styles.cardTitle}>Ghost Challenge Feed</div>
          {ghostFeed.length === 0 && (
            <div style={{ color: '#6b7280', fontSize: '0.85rem' }}>No ghosts published yet. Finish a match and save it!</div>
          )}
          {ghostFeed.map((g) => (
            <div key={g.ghost_id} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center',
              padding: '8px 12px', marginBottom: '6px', background: 'rgba(139,92,246,0.08)',
              borderRadius: '8px', border: '1px solid rgba(139,92,246,0.2)' }}>
              <div>
                <strong style={{ color: '#a78bfa' }}>{g.publisher_name}</strong>
                <span style={{ color: '#6b7280', fontSize: '0.8rem', marginLeft: '8px' }}>
                  PRQ {g.publisher_prq} · {g.mode_id} · Beat rate: {g.beat_rate_pct}%
                </span>
                {g.top_moment && (
                  <div style={{ color: '#9ca3af', fontSize: '0.75rem' }}>
                    Top moment: {g.top_moment.type} {g.top_moment.total ? `— ${g.top_moment.total}pts` : ''}
                  </div>
                )}
              </div>
              <button
                style={{ ...styles.btn, padding: '4px 12px', fontSize: '0.75rem',
                  background: 'rgba(139,92,246,0.2)', color: '#a78bfa' }}
                onClick={() => startGhostChallenge(g.ghost_id)}
              >
                Challenge
              </button>
            </div>
          ))}
        </div>
      )}

      {activeChallenge && (
        <div style={{ ...styles.card, marginBottom: '24px', borderColor: 'rgba(139,92,246,0.4)' }}>
          <div style={styles.cardTitle}>👻 Active Ghost Challenge</div>
          <div style={{ fontSize: '0.85rem', color: '#9ca3af' }}>
            <div>Ghost seed: <strong style={{ color: '#a78bfa' }}>{String(activeChallenge.seed)}</strong></div>
            <div>Judge offsets: <strong>[{(activeChallenge.judge_offsets || []).join(', ')}]</strong></div>
            <div style={{ marginTop: '6px', color: '#7c3aed' }}>{activeChallenge.instructions?.overlay}</div>
          </div>
        </div>
      )}

      {matchId && (
        <>
          <div style={styles.grid}>
            {players.length === 0 && (
              <div style={{ ...styles.card, gridColumn: '1/-1', color: '#6b7280' }}>
                Waiting for players to join…
                <button
                  style={{ ...styles.btn, background: '#00e5ff', color: '#08090b', marginLeft: '16px' }}
                  onClick={() => joinMatch(matchId)}
                >
                  Join as 2nd Player
                </button>
              </div>
            )}
            {players.map((p) => (
              <PlayerCard
                key={p}
                player={p}
                score={score[p] || 0}
                loadout={loadouts[p] || []}
              />
            ))}
          </div>
          <EventLog events={events} />
        </>
      )}
    </div>
  );
}
