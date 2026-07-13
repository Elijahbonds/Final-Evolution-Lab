import React, { useEffect, useMemo, useRef, useState } from 'react';

function useFlashToken(value) {
  const [active, setActive] = useState(false);
  const previous = useRef(value);

  useEffect(() => {
    if (value && value !== previous.current) {
      previous.current = value;
      setActive(true);
      const id = setTimeout(() => setActive(false), 320);
      return () => clearTimeout(id);
    }
    previous.current = value;
    return undefined;
  }, [value]);

  return active;
}

function tokenColor(label) {
  switch (label) {
    case 'ACE': return '#38bdf8';
    case 'SPIKE': return '#f97316';
    case 'BLOCK': return '#a78bfa';
    case 'SAVE': return '#22c55e';
    default: return '#facc15';
  }
}

function ServiceIndicator({ serveReady, winner }) {
  const text = winner
    ? `${winner} WINS`
    : serveReady
      ? 'PLAYER TO SERVE'
      : 'OPPONENT SERVE / RALLY LIVE';

  return (
    <div style={{
      padding: '8px 12px',
      borderRadius: 999,
      background: serveReady ? 'rgba(59,130,246,0.18)' : 'rgba(239,68,68,0.18)',
      border: `1px solid ${serveReady ? 'rgba(96,165,250,0.45)' : 'rgba(248,113,113,0.45)'}`,
      color: '#f8fafc',
      fontSize: 11,
      fontWeight: 800,
      letterSpacing: '0.12em',
      textTransform: 'uppercase',
      justifySelf: 'start',
    }}>
      {text}
    </div>
  );
}

export function VolleyballHUD({
  playerPoints = 0,
  opponentPoints = 0,
  sets = [0, 0],
  score = 0,
  prq = 50,
  lastResult = '',
  serveReady = true,
  isSpiking = false,
  winner = null,
}) {
  const label = useMemo(() => {
    const upper = String(lastResult || '').toUpperCase();
    if (upper.includes('ACE')) return 'ACE';
    if (upper.includes('SPIKE')) return 'SPIKE';
    if (upper.includes('BLOCK')) return 'BLOCK';
    if (upper.includes('SAVE')) return 'SAVE';
    return upper;
  }, [lastResult]);

  const flash = useFlashToken(`${playerPoints}-${opponentPoints}-${label}-${winner || ''}`);
  const prqFill = Math.max(0, Math.min(100, prq));
  const labelColor = tokenColor(label);

  return (
    <div style={{
      display: 'grid',
      gap: 12,
      minWidth: 320,
      maxWidth: 420,
      padding: 16,
      borderRadius: 20,
      background: 'rgba(8,15,28,0.82)',
      border: '1px solid rgba(255,255,255,0.08)',
      backdropFilter: 'blur(10px)',
      WebkitBackdropFilter: 'blur(10px)',
      color: '#f8fafc',
      fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      boxShadow: '0 18px 48px rgba(0,0,0,0.32)',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10 }}>
        <ServiceIndicator serveReady={serveReady} winner={winner} />
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 10, color: '#94a3b8', letterSpacing: '0.12em', textTransform: 'uppercase' }}>Session Score</div>
          <div style={{ fontSize: 22, fontWeight: 900, color: '#facc15' }}>{score}</div>
        </div>
      </div>

      <div style={{
        padding: 14,
        borderRadius: 16,
        background: flash ? 'rgba(255,255,255,0.08)' : 'rgba(255,255,255,0.04)',
        transform: flash ? 'scale(1.02)' : 'scale(1)',
        transition: 'transform 160ms ease, background 160ms ease',
      }}>
        <div style={{ fontSize: 13, color: '#93c5fd', letterSpacing: '0.12em', textTransform: 'uppercase', marginBottom: 8 }}>
          Scoreboard
        </div>
        <div style={{
          fontSize: 32,
          fontWeight: 900,
          lineHeight: 1.1,
          letterSpacing: '-0.03em',
          textShadow: flash ? '0 0 24px rgba(255,255,255,0.24)' : 'none',
        }}>
          PLAYER {String(playerPoints).padStart(2, '0')} – {String(opponentPoints).padStart(2, '0')} OPPONENT
        </div>
      </div>

      <div style={{ display: 'grid', gap: 8 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, color: '#94a3b8', letterSpacing: '0.1em', textTransform: 'uppercase' }}>Sets</span>
          <span style={{ fontSize: 11, color: '#94a3b8', letterSpacing: '0.1em', textTransform: 'uppercase' }}>Best of 3</span>
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <span style={{ fontSize: 12, fontWeight: 700, color: '#bfdbfe' }}>PLAYER</span>
            {[0, 1, 2].map((index) => (
              <span key={`player-set-${index}`} style={{ fontSize: 20, color: index < (sets?.[0] ?? 0) ? '#38bdf8' : '#475569' }}>
                {index < (sets?.[0] ?? 0) ? '●' : '○'}
              </span>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            {[0, 1, 2].map((index) => (
              <span key={`opponent-set-${index}`} style={{ fontSize: 20, color: index < (sets?.[1] ?? 0) ? '#f87171' : '#475569' }}>
                {index < (sets?.[1] ?? 0) ? '●' : '○'}
              </span>
            ))}
            <span style={{ fontSize: 12, fontWeight: 700, color: '#fecaca' }}>OPPONENT</span>
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
        {['SPIKE', 'ACE', 'BLOCK', 'SAVE'].map((token) => {
          const active = label === token || (token === 'SPIKE' && isSpiking);
          return (
            <div key={token} style={{
              padding: '8px 12px',
              borderRadius: 999,
              background: active ? `${tokenColor(token)}22` : 'rgba(255,255,255,0.05)',
              border: `1px solid ${active ? tokenColor(token) : 'rgba(255,255,255,0.08)'}`,
              color: active ? tokenColor(token) : '#cbd5e1',
              fontSize: 12,
              fontWeight: 800,
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              boxShadow: active ? `0 0 18px ${tokenColor(token)}44` : 'none',
              transform: active && flash ? 'translateY(-1px) scale(1.04)' : 'scale(1)',
              transition: 'all 140ms ease',
            }}>
              {token}
            </div>
          );
        })}
        {lastResult && !['SPIKE', 'ACE', 'BLOCK', 'SAVE'].includes(label) && (
          <div style={{ fontSize: 12, color: labelColor, fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            {label}
          </div>
        )}
      </div>

      <div style={{ display: 'grid', gap: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, color: '#94a3b8', letterSpacing: '0.1em', textTransform: 'uppercase' }}>PRQ</span>
          <span style={{ fontSize: 12, fontWeight: 800, color: prqFill >= 75 ? '#22c55e' : prqFill >= 45 ? '#facc15' : '#f87171' }}>
            {Math.round(prqFill)}
          </span>
        </div>
        <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
          <div style={{
            width: `${prqFill}%`,
            height: '100%',
            background: prqFill >= 75 ? '#22c55e' : prqFill >= 45 ? '#facc15' : '#f87171',
            transition: 'width 180ms ease',
          }} />
        </div>
      </div>
    </div>
  );
}

export default VolleyballHUD;
