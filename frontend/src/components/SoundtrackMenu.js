/**
 * SoundtrackMenu — 2K-style creator jukebox (MusicProviderModule seam client).
 *
 * DISCOVERY ONLY: playback is deliberately decoupled from all match state.
 * No points, unlocks, streaks, or penalties may ever hinge on listening
 * (Spotify developer policy prohibits gameplay-coupled playback; the Tier-1
 * demo honors the same rule so higher tiers can swap in unchanged).
 *
 * Data flow: GET /api/music/creator/{id}/tracks -> {branding, tracks[]}.
 *   embed.kind === "local_audio"   -> <audio> element (Tier-1 CC0 demo pack)
 *   embed.kind === "oembed_iframe" -> provider iframe (Tier-2/3, future)
 *
 * Identity: premium dark ink, cyan #00D4FF / purple #9933FF accents.
 */
import React, { useCallback, useEffect, useRef, useState } from 'react';

const API_BASE = process.env.REACT_APP_BACKEND_URL || '';
const CYAN = '#00D4FF';
const PURPLE = '#9933FF';

const S = {
  wrap: {
    marginTop: '10px',
    borderRadius: '14px',
    overflow: 'hidden',
    border: `1px solid rgba(153,51,255,0.35)`,
    background: 'linear-gradient(165deg, #0c0918 0%, #07060d 100%)',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '12px 16px',
    background: 'linear-gradient(90deg, rgba(153,51,255,0.16), rgba(0,212,255,0.08))',
    borderBottom: '1px solid rgba(153,51,255,0.25)',
  },
  headerTitle: {
    fontSize: '0.72rem',
    fontWeight: 900,
    letterSpacing: '0.3em',
    textTransform: 'uppercase',
    color: CYAN,
  },
  tierBadge: {
    fontSize: '0.62rem',
    fontWeight: 700,
    letterSpacing: '0.12em',
    padding: '2px 9px',
    borderRadius: '999px',
    color: PURPLE,
    background: 'rgba(153,51,255,0.1)',
    border: '1px solid rgba(153,51,255,0.35)',
    textTransform: 'uppercase',
  },
  list: { maxHeight: '220px', overflowY: 'auto' },
  row: (active) => ({
    display: 'flex',
    alignItems: 'center',
    gap: '12px',
    padding: '10px 16px',
    cursor: 'pointer',
    background: active ? 'rgba(0,212,255,0.07)' : 'transparent',
    borderLeft: active ? `3px solid ${CYAN}` : '3px solid transparent',
    transition: 'background 0.15s',
  }),
  playBtn: (active) => ({
    width: '34px',
    height: '34px',
    borderRadius: '50%',
    border: `1px solid ${active ? CYAN : 'rgba(255,255,255,0.2)'}`,
    background: active ? 'rgba(0,212,255,0.14)' : 'rgba(255,255,255,0.04)',
    color: active ? CYAN : '#9ca3af',
    fontSize: '0.8rem',
    cursor: 'pointer',
    flexShrink: 0,
  }),
  trackNo: { color: '#4b5563', fontSize: '0.72rem', minWidth: '18px', fontVariantNumeric: 'tabular-nums' },
  title: { color: '#e8eaf0', fontSize: '0.88rem', fontWeight: 600, flex: 1 },
  duration: { color: '#6b7280', fontSize: '0.72rem', fontVariantNumeric: 'tabular-nums' },
  nowPlaying: {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '10px 16px',
    borderTop: `1px solid rgba(0,212,255,0.2)`,
    background: 'rgba(0,212,255,0.05)',
  },
  eq: { display: 'flex', gap: '2px', alignItems: 'flex-end', height: '14px' },
  eqBar: (i) => ({
    width: '3px',
    borderRadius: '2px',
    background: CYAN,
    animation: `sceneit-eq 0.${5 + i}s ease-in-out infinite alternate`,
  }),
  attribution: {
    padding: '9px 16px',
    fontSize: '0.64rem',
    color: '#4b5563',
    borderTop: '1px solid rgba(255,255,255,0.06)',
    lineHeight: 1.5,
  },
};

function fmt(sec) {
  const s = Math.max(0, Math.round(sec || 0));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export default function SoundtrackMenu({ creatorId }) {
  const [data, setData] = useState(null);
  const [err, setErr] = useState(null);
  const [playingId, setPlayingId] = useState(null);
  const audioRef = useRef(null);

  useEffect(() => {
    fetch(`${API_BASE}/api/music/creator/${creatorId}/tracks`)
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`))))
      .then(setData)
      .catch((e) => setErr(String(e)));
    return () => {
      if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; }
    };
  }, [creatorId]);

  const toggle = useCallback((track) => {
    if (track.embed.kind !== 'local_audio') return; // Tier-2/3 render iframes instead
    if (audioRef.current) { audioRef.current.pause(); audioRef.current = null; }
    if (playingId === track.track_id) { setPlayingId(null); return; }
    const audio = new Audio(`${API_BASE}${track.embed.url}`);
    audio.onended = () => setPlayingId(null);
    audio.play().catch(() => setPlayingId(null));
    audioRef.current = audio;
    setPlayingId(track.track_id);
  }, [playingId]);

  if (err) return <p style={{ color: '#fb7185', fontSize: '0.8rem' }}>Jukebox unavailable: {err}</p>;
  if (!data) return <p style={{ color: '#6b7280', fontSize: '0.8rem' }}>Warming up the decks…</p>;
  if (!data.tracks.length) {
    return <p style={{ color: '#6b7280', fontSize: '0.8rem' }}>No tracks on this card yet.</p>;
  }

  const nowPlaying = data.tracks.find((t) => t.track_id === playingId);

  return (
    <div style={S.wrap} data-testid="soundtrack-menu">
      <style>{'@keyframes sceneit-eq { from { height: 3px; } to { height: 14px; } }'}</style>
      <div style={S.header}>
        <span style={S.headerTitle}>Soundtrack</span>
        <span style={S.tierBadge}>{data.branding.name}</span>
      </div>
      <div style={S.list}>
        {data.tracks.map((t, i) => (
          <div key={t.track_id} style={S.row(t.track_id === playingId)} onClick={() => toggle(t)}>
            <span style={S.trackNo}>{String(i + 1).padStart(2, '0')}</span>
            <button
              style={S.playBtn(t.track_id === playingId)}
              onClick={(e) => { e.stopPropagation(); toggle(t); }}
              aria-label={t.track_id === playingId ? 'pause' : 'play'}
            >
              {t.track_id === playingId ? '❚❚' : '▶'}
            </button>
            <span style={S.title}>{t.title}</span>
            <span style={S.duration}>{fmt(t.duration_s)}</span>
          </div>
        ))}
      </div>
      {nowPlaying && (
        <div style={S.nowPlaying} data-testid="now-playing">
          <span style={S.eq}>{[0, 1, 2, 3].map((i) => <span key={i} style={S.eqBar(i)} />)}</span>
          <span style={{ color: CYAN, fontSize: '0.78rem', fontWeight: 700 }}>{nowPlaying.title}</span>
          <span style={{ color: '#6b7280', fontSize: '0.68rem' }}>— {data.creator_name}</span>
        </div>
      )}
      <div style={S.attribution}>
        {data.branding.attribution}
        {nowPlaying && nowPlaying.attribution ? ` · ${nowPlaying.attribution}` : ''}
        {' · Listening is discovery only — never tied to match scoring.'}
      </div>
    </div>
  );
}
