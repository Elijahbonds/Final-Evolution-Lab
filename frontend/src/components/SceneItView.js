/**
 * SceneItView — "Who Scene It" buzz-in risk trivia (nexus/sceneit-demo)
 *
 * Cinematic premium-dark match UI over the /api/sceneit/* engine:
 *   - letterbox frame + gradient overlays, optional film-grain toggle
 *   - score COUNTS DOWN while nobody has buzzed (server-authoritative,
 *     client-side interpolated between polls)
 *   - options stay hidden until YOU buzz; ~4s lock-in ring after buzzing
 *   - wrong buzz loses points (risk mechanic)
 *   - reveal timeline of past questions
 *   - Creator Card deep-dive modal (bio / timeline / top works / lesson stub)
 *
 * Keyboard: SPACE = buzz, 1-4 = answer, N = next question.
 * All scene stills are original generated SVG placeholders served by the
 * backend (to be replaced with Meshy-generated stills at design sign-off).
 */
import React, { useCallback, useEffect, useRef, useState } from 'react';
import SoundtrackMenu from './SoundtrackMenu';

const API_BASE = process.env.REACT_APP_BACKEND_URL || '';
const POLL_MS = 400;
const DEFAULT_ROUNDS = ['invisibles', 'frame_freeze', 'credit_roll'];

// Film-grain via inline SVG noise (self-contained, no external assets).
const GRAIN_URI =
  'url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'160\' height=\'160\'%3E%3Cfilter id=\'n\'%3E%3CfeTurbulence type=\'fractalNoise\' baseFrequency=\'0.9\' numOctaves=\'2\'/%3E%3C/filter%3E%3Crect width=\'160\' height=\'160\' filter=\'url(%23n)\' opacity=\'0.5\'/%3E%3C/svg%3E")';

const S = {
  shell: {
    background: '#050608',
    color: '#e8eaf0',
    minHeight: '100vh',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
    display: 'flex',
    flexDirection: 'column',
    position: 'relative',
    overflow: 'hidden',
  },
  letterbox: { background: '#000', height: '42px', flexShrink: 0, zIndex: 3 },
  stage: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    padding: '18px 24px',
    background:
      'radial-gradient(ellipse at 50% 0%, rgba(0,212,255,0.07), transparent 60%), linear-gradient(180deg, #07080c 0%, #050608 100%)',
    position: 'relative',
  },
  grain: {
    position: 'absolute',
    inset: 0,
    backgroundImage: GRAIN_URI,
    opacity: 0.06,
    pointerEvents: 'none',
    mixBlendMode: 'overlay',
    zIndex: 2,
  },
  topBar: {
    width: '100%',
    maxWidth: '860px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '12px',
  },
  brand: { fontSize: '0.8rem', letterSpacing: '0.35em', color: '#00D4FF', fontWeight: 800, textTransform: 'uppercase' },
  roundTag: {
    padding: '3px 12px',
    borderRadius: '999px',
    fontSize: '0.7rem',
    fontWeight: 700,
    letterSpacing: '0.12em',
    textTransform: 'uppercase',
    color: '#ffd700',
    background: 'rgba(255,215,0,0.08)',
    border: '1px solid rgba(255,215,0,0.25)',
  },
  ghostBtn: {
    background: 'transparent',
    color: '#6b7280',
    border: '1px solid rgba(255,255,255,0.12)',
    borderRadius: '8px',
    padding: '5px 12px',
    fontSize: '0.72rem',
    cursor: 'pointer',
  },
  frame: {
    width: '100%',
    maxWidth: '700px',
    borderRadius: '10px',
    overflow: 'hidden',
    border: '1px solid rgba(0,212,255,0.18)',
    boxShadow: '0 24px 80px rgba(0,0,0,0.7), 0 0 40px rgba(0,212,255,0.06)',
    position: 'relative',
    background: '#000',
  },
  prompt: {
    maxWidth: '700px',
    textAlign: 'center',
    fontSize: '1.02rem',
    color: '#cbd5e1',
    margin: '14px 0 6px',
    lineHeight: 1.45,
  },
  potential: (danger) => ({
    fontSize: '3.6rem',
    fontWeight: 900,
    lineHeight: 1,
    fontVariantNumeric: 'tabular-nums',
    color: danger ? '#fb7185' : '#00D4FF',
    textShadow: danger ? '0 0 24px rgba(251,113,133,0.45)' : '0 0 24px rgba(0,212,255,0.35)',
    transition: 'color 0.4s',
  }),
  potentialLabel: { fontSize: '0.68rem', letterSpacing: '0.3em', color: '#6b7280', textTransform: 'uppercase' },
  buzzer: (armed) => ({
    marginTop: '10px',
    width: '108px',
    height: '108px',
    borderRadius: '50%',
    border: 'none',
    cursor: armed ? 'pointer' : 'default',
    fontWeight: 900,
    fontSize: '0.95rem',
    letterSpacing: '0.15em',
    color: '#0b0d12',
    background: armed
      ? 'radial-gradient(circle at 35% 30%, #ff8fa8, #e11d48 70%)'
      : 'radial-gradient(circle at 35% 30%, #374151, #111827 70%)',
    boxShadow: armed
      ? '0 0 0 6px rgba(225,29,72,0.18), 0 0 44px rgba(225,29,72,0.5), inset 0 -6px 14px rgba(0,0,0,0.35)'
      : 'inset 0 -6px 14px rgba(0,0,0,0.5)',
    transition: 'all 0.25s',
  }),
  options: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px', width: '100%', maxWidth: '700px', marginTop: '12px' },
  option: (state) => ({
    padding: '13px 16px',
    borderRadius: '12px',
    textAlign: 'left',
    fontSize: '0.92rem',
    fontWeight: 600,
    cursor: state === 'idle' ? 'pointer' : 'default',
    color: state === 'correct' ? '#022c22' : state === 'wrong' ? '#fff1f2' : '#e8eaf0',
    background:
      state === 'correct' ? '#34d399' : state === 'wrong' ? 'rgba(225,29,72,0.55)' : 'rgba(255,255,255,0.05)',
    border: `1px solid ${state === 'correct' ? '#34d399' : state === 'wrong' ? '#e11d48' : 'rgba(0,212,255,0.2)'}`,
    transition: 'all 0.2s',
  }),
  keyHint: {
    display: 'inline-block',
    minWidth: '20px',
    marginRight: '10px',
    padding: '1px 6px',
    borderRadius: '5px',
    background: 'rgba(0,0,0,0.35)',
    border: '1px solid rgba(255,255,255,0.18)',
    fontSize: '0.72rem',
    textAlign: 'center',
  },
  lockRing: { position: 'relative', width: '64px', height: '64px', margin: '6px auto 0' },
  timeline: {
    display: 'flex',
    gap: '8px',
    marginTop: '16px',
    flexWrap: 'wrap',
    justifyContent: 'center',
    maxWidth: '700px',
  },
  timelineChip: (won) => ({
    padding: '5px 11px',
    borderRadius: '999px',
    fontSize: '0.7rem',
    fontWeight: 700,
    background: won === true ? 'rgba(52,211,153,0.12)' : won === false ? 'rgba(225,29,72,0.12)' : 'rgba(255,255,255,0.05)',
    color: won === true ? '#34d399' : won === false ? '#fb7185' : '#6b7280',
    border: `1px solid ${won === true ? 'rgba(52,211,153,0.35)' : won === false ? 'rgba(225,29,72,0.3)' : 'rgba(255,255,255,0.1)'}`,
  }),
  scores: { display: 'flex', gap: '18px', marginTop: '4px' },
  scoreCell: (neg) => ({
    textAlign: 'center',
    minWidth: '90px',
    padding: '8px 14px',
    borderRadius: '12px',
    background: 'rgba(255,255,255,0.04)',
    border: '1px solid rgba(0,212,255,0.14)',
    color: neg ? '#fb7185' : '#e8eaf0',
  }),
  credits: {
    height: '280px',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: '14px',
    padding: '24px',
    background: 'linear-gradient(180deg, #000 0%, #0a0c14 100%)',
    fontFamily: 'Georgia, "Times New Roman", serif',
  },
  creditLine: { color: '#e5e7eb', fontSize: '1rem', letterSpacing: '0.12em', textAlign: 'center', textTransform: 'uppercase' },
  modalScrim: {
    position: 'fixed',
    inset: 0,
    background: 'rgba(0,0,0,0.78)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 50,
    backdropFilter: 'blur(6px)',
  },
  modal: {
    width: 'min(560px, 92vw)',
    maxHeight: '82vh',
    overflowY: 'auto',
    background: 'linear-gradient(160deg, #10131c 0%, #0a0c12 100%)',
    border: '1px solid rgba(153,51,255,0.35)',
    borderRadius: '18px',
    padding: '26px 28px',
    boxShadow: '0 30px 120px rgba(0,0,0,0.8)',
  },
  rarity: {
    display: 'inline-block',
    padding: '2px 10px',
    borderRadius: '999px',
    fontSize: '0.66rem',
    fontWeight: 800,
    letterSpacing: '0.18em',
    textTransform: 'uppercase',
    color: '#9933FF',
    background: 'rgba(153,51,255,0.12)',
    border: '1px solid rgba(153,51,255,0.3)',
  },
  modalSection: { fontSize: '0.7rem', letterSpacing: '0.2em', textTransform: 'uppercase', color: '#6b7280', margin: '18px 0 6px' },
  primaryBtn: {
    marginTop: '12px',
    padding: '10px 26px',
    borderRadius: '10px',
    border: 'none',
    cursor: 'pointer',
    fontWeight: 800,
    fontSize: '0.9rem',
    letterSpacing: '0.08em',
    color: '#04121f',
    background: 'linear-gradient(90deg, #00D4FF, #38bdf8)',
  },
  cardLinkBtn: {
    marginLeft: '10px',
    padding: '8px 16px',
    borderRadius: '10px',
    cursor: 'pointer',
    fontWeight: 700,
    fontSize: '0.8rem',
    color: '#9933FF',
    background: 'rgba(153,51,255,0.1)',
    border: '1px solid rgba(153,51,255,0.35)',
  },
};

function potentialAt(elapsedMs, cfg) {
  if (!cfg) return 0;
  const e = Math.max(0, elapsedMs);
  if (e >= cfg.countdown_ms) return cfg.floor_points;
  return cfg.max_points - Math.floor(((cfg.max_points - cfg.floor_points) * e) / cfg.countdown_ms);
}

function LockRing({ remainingMs, totalMs }) {
  const frac = Math.max(0, Math.min(1, remainingMs / totalMs));
  const r = 26;
  const c = 2 * Math.PI * r;
  return (
    <div style={S.lockRing}>
      <svg width="64" height="64" viewBox="0 0 64 64">
        <circle cx="32" cy="32" r={r} fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth="5" />
        <circle
          cx="32" cy="32" r={r} fill="none"
          stroke={frac < 0.3 ? '#fb7185' : '#ffd700'} strokeWidth="5" strokeLinecap="round"
          strokeDasharray={c} strokeDashoffset={c * (1 - frac)}
          transform="rotate(-90 32 32)" style={{ transition: 'stroke-dashoffset 0.1s linear' }}
        />
        <text x="32" y="37" textAnchor="middle" fill="#ffd700" fontSize="14" fontWeight="800">
          {Math.ceil(remainingMs / 1000)}
        </text>
      </svg>
    </div>
  );
}

function CreatorCardModal({ creatorId, onClose }) {
  const [card, setCard] = useState(null);
  const [err, setErr] = useState(null);
  useEffect(() => {
    fetch(`${API_BASE}/api/creators/${creatorId}`)
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then(setCard)
      .catch((e) => setErr(String(e)));
  }, [creatorId]);
  return (
    <div style={S.modalScrim} onClick={onClose} data-testid="creator-card-modal">
      <div style={S.modal} onClick={(e) => e.stopPropagation()}>
        {err && <p style={{ color: '#fb7185' }}>Failed to load creator card: {err}</p>}
        {!card && !err && <p style={{ color: '#6b7280' }}>Dealing the card…</p>}
        {card && (
          <>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
              <h2 style={{ margin: 0, fontSize: '1.5rem', color: '#f3f4f6' }}>{card.name}</h2>
              <span>
                {card.creator_type && (
                  <span style={{ ...S.rarity, color: '#00D4FF', borderColor: 'rgba(0,212,255,0.35)', background: 'rgba(0,212,255,0.08)', marginRight: '8px' }} data-testid="creator-type">
                    {card.creator_type}
                  </span>
                )}
                <span style={S.rarity}>{card.rarity}</span>
              </span>
            </div>
            <p style={{ color: '#B366FF', margin: '4px 0 0', fontStyle: 'italic', fontSize: '0.9rem' }}>
              “{card.tagline}” — {card.persona.replace('_', ' ')}
            </p>
            <div style={S.modalSection}>Bio</div>
            <p style={{ color: '#cbd5e1', fontSize: '0.9rem', lineHeight: 1.55, margin: 0 }}>{card.bio}</p>
            <div style={S.modalSection}>Timeline</div>
            {card.timeline.map((t) => (
              <div key={t.year + t.event} style={{ display: 'flex', gap: '12px', fontSize: '0.85rem', marginBottom: '5px' }}>
                <span style={{ color: '#ffd700', fontWeight: 800, minWidth: '44px' }}>{t.year}</span>
                <span style={{ color: '#9ca3af' }}>{t.event}</span>
              </div>
            ))}
            <div style={S.modalSection}>Top works</div>
            {card.top_works.map((w) => (
              <div key={w.film_id} style={{ fontSize: '0.88rem', color: '#e8eaf0', marginBottom: '4px' }}>
                {w.title} <span style={{ color: '#6b7280' }}>({w.year})</span>
              </div>
            ))}
            <div style={S.modalSection}>Did you know</div>
            {card.facts.map((f) => (
              <p key={f} style={{ color: '#9ca3af', fontSize: '0.83rem', margin: '0 0 6px' }}>• {f}</p>
            ))}
            {card.sections && card.sections.music && card.sections.music.length > 0 && (
              <>
                <div style={S.modalSection}>Soundtrack — creator discovery</div>
                <SoundtrackMenu creatorId={card.creator_id} />
              </>
            )}
            {card.sections && card.sections.dance && card.sections.dance.length > 0 && (
              <>
                <div style={S.modalSection}>Dance & choreo lessons</div>
                {card.sections.dance.map((clip) => (
                  <div key={clip.clip_id} style={{
                    display: 'flex', alignItems: 'center', gap: '10px', flexWrap: 'wrap',
                    padding: '9px 12px', borderRadius: '10px', marginBottom: '6px',
                    background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(153,51,255,0.2)',
                  }} data-testid="dance-clip">
                    <span style={{ color: '#e8eaf0', fontSize: '0.85rem', fontWeight: 600, flex: 1 }}>{clip.title}</span>
                    <span style={{ ...S.rarity, color: '#ffd700', borderColor: 'rgba(255,215,0,0.3)', background: 'rgba(255,215,0,0.07)' }}>
                      {clip.difficulty}
                    </span>
                    {clip.style_tags.map((tag) => (
                      <span key={tag} style={{ color: '#6b7280', fontSize: '0.68rem' }}>#{tag}</span>
                    ))}
                  </div>
                ))}
              </>
            )}
            {card.sections && card.sections.links && card.sections.links.length > 0 && (
              <>
                <div style={S.modalSection}>Masterclasses & links</div>
                {card.sections.links.map((link) => (
                  <a key={link.url} href={link.url} target="_blank" rel="noreferrer" style={{
                    display: 'block', padding: '8px 12px', borderRadius: '10px', marginBottom: '6px',
                    color: '#00D4FF', fontSize: '0.83rem', textDecoration: 'none',
                    background: 'rgba(0,212,255,0.05)', border: '1px solid rgba(0,212,255,0.2)',
                  }} data-testid="masterclass-link">
                    {link.title} <span style={{ color: '#4b5563', fontSize: '0.68rem' }}>· {link.provider}</span>
                  </a>
                ))}
              </>
            )}
            {card.lesson_stub && card.lesson_stub.title && (
              <>
                <div style={S.modalSection}>Linked lesson</div>
                <div style={{
                  padding: '12px 14px', borderRadius: '12px',
                  background: 'rgba(0,212,255,0.05)', border: '1px dashed rgba(0,212,255,0.3)',
                }}>
                  <div style={{ fontWeight: 700, color: '#00D4FF', fontSize: '0.9rem' }}>{card.lesson_stub.title}</div>
                  <div style={{ color: '#9ca3af', fontSize: '0.8rem', marginTop: '4px' }}>{card.lesson_stub.summary}</div>
                  <div style={{ color: '#6b7280', fontSize: '0.7rem', marginTop: '6px' }}>Lesson stub — full course lands with the education loop.</div>
                </div>
              </>
            )}
            <p style={{ color: '#374151', fontSize: '0.66rem', marginTop: '16px' }}>
              {card.source} · {card.license}
            </p>
            <button style={S.primaryBtn} onClick={onClose}>Back to the match</button>
          </>
        )}
      </div>
    </div>
  );
}

export default function SceneItView({ playerId = 'player_1', onExit }) {
  const [match, setMatch] = useState(null); // {match_id, ...}
  const [state, setState] = useState(null); // /state payload
  const [displayPotential, setDisplayPotential] = useState(0);
  const [grain, setGrain] = useState(true);
  const [cardCreator, setCardCreator] = useState(null);
  const [error, setError] = useState(null);
  const lastFetch = useRef({ at: 0, elapsed: 0 });
  const stateRef = useRef(null);
  stateRef.current = state;
  const matchRef = useRef(null);
  matchRef.current = match;

  const api = useCallback(async (path, opts) => {
    const resp = await fetch(`${API_BASE}${path}`, opts && {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(opts),
    });
    if (!resp.ok) {
      const detail = await resp.json().catch(() => ({}));
      throw new Error(detail.detail || `HTTP ${resp.status}`);
    }
    return resp.json();
  }, []);

  // Create match on mount
  useEffect(() => {
    api('/api/sceneit/match/create', {
      players: [playerId],
      round_types: DEFAULT_ROUNDS,
      num_questions: 6,
    }).then(setMatch).catch((e) => setError(String(e.message || e)));
  }, [api, playerId]);

  // Poll authoritative state
  useEffect(() => {
    if (!match) return undefined;
    let live = true;
    const poll = async () => {
      try {
        const s = await api(`/api/sceneit/match/${match.match_id}/state?player_id=${encodeURIComponent(playerId)}`);
        if (!live) return;
        lastFetch.current = { at: Date.now(), elapsed: s.elapsed_ms };
        setState(s);
      } catch (e) { /* transient poll errors are fine */ }
    };
    poll();
    const id = setInterval(poll, POLL_MS);
    return () => { live = false; clearInterval(id); };
  }, [api, match, playerId]);

  // Smooth score countdown between polls (display only; server stays authoritative)
  useEffect(() => {
    const id = setInterval(() => {
      const s = stateRef.current;
      if (!s || s.resolved || s.status !== 'active') return;
      const localElapsed = lastFetch.current.elapsed + (Date.now() - lastFetch.current.at);
      setDisplayPotential(potentialAt(localElapsed, s.scoring_config));
    }, 90);
    return () => clearInterval(id);
  }, []);

  const doBuzz = useCallback(() => {
    const m = matchRef.current; const s = stateRef.current;
    if (!m || !s || s.resolved || s.buzz || s.you_attempted || s.status !== 'active') return;
    api(`/api/sceneit/match/${m.match_id}/buzz`, { player_id: playerId })
      .then(() => {}).catch(() => {});
  }, [api, playerId]);

  const doAnswer = useCallback((optionId) => {
    const m = matchRef.current; const s = stateRef.current;
    if (!m || !s || !s.buzz || !s.buzz.you_hold_buzz) return;
    api(`/api/sceneit/match/${m.match_id}/answer`, { player_id: playerId, option_id: optionId })
      .then(() => {}).catch(() => {});
  }, [api, playerId]);

  const doNext = useCallback(() => {
    const m = matchRef.current; const s = stateRef.current;
    if (!m || !s || s.status !== 'active') return;
    api(`/api/sceneit/match/${m.match_id}/next`, {}).then(() => {}).catch(() => {});
  }, [api]);

  // Keyboard seam: space = buzz, 1-4 = answer, n = next
  useEffect(() => {
    const onKey = (e) => {
      if (e.repeat) return;
      if (e.code === 'Space') { e.preventDefault(); doBuzz(); }
      if (e.key === 'n') doNext();
      const idx = ['1', '2', '3', '4'].indexOf(e.key);
      if (idx >= 0) {
        const s = stateRef.current;
        const opts = s && s.question && s.question.options;
        if (opts && opts[idx] && s.buzz && s.buzz.you_hold_buzz) doAnswer(opts[idx].option_id);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [doBuzz, doAnswer, doNext]);

  if (error) {
    return (
      <div style={S.shell}>
        <div style={{ ...S.stage, justifyContent: 'center' }}>
          <p style={{ color: '#fb7185' }}>Could not start Who Scene It: {error}</p>
          {onExit && <button style={S.primaryBtn} onClick={onExit}>Exit</button>}
        </div>
      </div>
    );
  }
  if (!state) {
    return (
      <div style={S.shell}>
        <div style={{ ...S.stage, justifyContent: 'center' }}>
          <p style={{ color: '#6b7280', letterSpacing: '0.2em' }}>ROLLING FILM…</p>
        </div>
      </div>
    );
  }

  const q = state.question;
  const media = q.media || {};
  const pres = q.presentation || {};
  const youHoldBuzz = !!(state.buzz && state.buzz.you_hold_buzz);
  const buzzArmed = state.status === 'active' && !state.resolved && !state.buzz && !state.you_attempted;
  const reveal = state.reveal;
  const finished = state.status === 'finished';
  const stillUrl = pres.still_url || media.still_url;

  const optionState = (opt) => {
    if (!reveal) return 'idle';
    if (opt.option_id === reveal.correct_option_id) return 'correct';
    if (opt.option_id === reveal.option_id && !reveal.correct) return 'wrong';
    return 'idle';
  };

  return (
    <div style={S.shell} data-testid="sceneit-view">
      <div style={S.letterbox} />
      <div style={S.stage}>
        {grain && <div style={S.grain} />}
        <div style={S.topBar}>
          <span style={S.brand}>Who Scene It</span>
          <span style={S.roundTag}>
            {finished ? 'Final Cut' : `${(q.round_type || '').replace('_', ' ')} · Q${state.question_index + 1}/${state.question_count}`}
          </span>
          <span>
            <button style={S.ghostBtn} onClick={() => setGrain((g) => !g)}>
              grain {grain ? 'on' : 'off'}
            </button>
            {onExit && (
              <button style={{ ...S.ghostBtn, marginLeft: '8px' }} onClick={onExit}>exit</button>
            )}
          </span>
        </div>

        {!finished && (
          <>
            {media.kind === 'credit_roll' ? (
              <div style={{ ...S.frame, ...S.credits }} data-testid="credit-roll">
                {(pres.visible_credits || []).map((line) => (
                  <div key={line} style={S.creditLine}>{line}</div>
                ))}
              </div>
            ) : (
              <div style={S.frame}>
                {stillUrl && (
                  <img
                    src={`${API_BASE}${stillUrl}`}
                    alt="scene still (original placeholder)"
                    style={{ width: '100%', display: 'block' }}
                    data-testid="scene-still"
                  />
                )}
              </div>
            )}

            <p style={S.prompt}>{q.prompt}</p>

            {!state.resolved && !state.buzz && (
              <div style={{ textAlign: 'center' }}>
                <div style={S.potentialLabel}>points on the table</div>
                <div style={S.potential(displayPotential <= (state.scoring_config.floor_points + 150))} data-testid="potential">
                  {displayPotential || state.potential}
                </div>
                <button style={S.buzzer(buzzArmed)} onClick={doBuzz} disabled={!buzzArmed} data-testid="buzzer">
                  {state.you_attempted ? 'LOCKED' : 'BUZZ'}
                </button>
                <div style={{ color: '#4b5563', fontSize: '0.7rem', marginTop: '8px' }}>
                  SPACE to buzz — wrong buzz costs {Math.round(state.scoring_config.wrong_buzz_penalty_ratio * 100)}% of the locked points
                </div>
              </div>
            )}

            {state.buzz && !state.resolved && (
              <div style={{ textAlign: 'center' }}>
                <div style={S.potentialLabel}>
                  {youHoldBuzz ? 'you locked' : `${state.buzz.player_id} locked`}
                </div>
                <div style={S.potential(false)}>{state.buzz.locked_potential}</div>
                <LockRing remainingMs={state.buzz.lock_in_remaining_ms} totalMs={state.scoring_config.lock_in_ms} />
              </div>
            )}

            {q.options && (youHoldBuzz || state.resolved) && (
              <div style={S.options} data-testid="options">
                {q.options.map((opt, i) => (
                  <button
                    key={opt.option_id}
                    style={S.option(optionState(opt))}
                    onClick={() => doAnswer(opt.option_id)}
                    disabled={!youHoldBuzz || state.resolved}
                  >
                    <span style={S.keyHint}>{i + 1}</span>
                    {opt.label}
                  </button>
                ))}
              </div>
            )}

            {state.resolved && reveal && (
              <div style={{ textAlign: 'center', marginTop: '10px' }}>
                <span style={{ color: reveal.correct ? '#34d399' : '#fb7185', fontWeight: 800 }}>
                  {reveal.correct
                    ? `${reveal.player_id} takes ${reveal.delta} points`
                    : reveal.timed_out
                      ? `Lock-in expired — ${reveal.player_id} drops ${Math.abs(reveal.delta)}`
                      : `Wrong buzz — ${reveal.player_id} drops ${Math.abs(reveal.delta)}`}
                </span>
                <div style={{ marginTop: '10px' }}>
                  <button style={S.primaryBtn} onClick={doNext} data-testid="next-question">
                    Next scene (N)
                  </button>
                  {reveal.content_refs && reveal.content_refs.creator_id && (
                    <button
                      style={S.cardLinkBtn}
                      onClick={() => setCardCreator(reveal.content_refs.creator_id)}
                      data-testid="creator-card-link"
                    >
                      ★ Creator Card
                    </button>
                  )}
                </div>
              </div>
            )}
          </>
        )}

        {finished && (
          <div style={{ textAlign: 'center', marginTop: '40px' }}>
            <div style={{ fontSize: '0.8rem', letterSpacing: '0.35em', color: '#ffd700', marginBottom: '14px' }}>THAT'S A WRAP</div>
            {Object.entries(state.scores).map(([pid, score]) => (
              <div key={pid} style={{ fontSize: '2rem', fontWeight: 900, color: score < 0 ? '#fb7185' : '#00D4FF' }}>
                {pid}: {score}
              </div>
            ))}
          </div>
        )}

        <div style={S.scores}>
          {Object.entries(state.scores).map(([pid, score]) => (
            <div key={pid} style={S.scoreCell(score < 0)}>
              <div style={{ fontSize: '1.3rem', fontWeight: 800 }}>{score}</div>
              <div style={{ fontSize: '0.68rem', color: '#6b7280' }}>{pid}</div>
            </div>
          ))}
        </div>

        <div style={S.timeline} data-testid="reveal-timeline">
          {state.timeline.map((t) => (
            <span key={t.question_index} style={S.timelineChip(t.winner ? true : t.skipped ? null : false)}>
              Q{t.question_index + 1} · {t.winner ? `+${t.delta}` : t.skipped ? 'skipped' : `${t.delta}`}
            </span>
          ))}
        </div>
      </div>
      <div style={S.letterbox} />
      {cardCreator && <CreatorCardModal creatorId={cardCreator} onClose={() => setCardCreator(null)} />}
    </div>
  );
}
