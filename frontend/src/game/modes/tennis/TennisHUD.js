import React from 'react';

const SCORE_CELL_STYLE = {
  minWidth: 54,
  textAlign: 'center',
  fontVariantNumeric: 'tabular-nums',
};

function labelColor(label) {
  switch (label) {
    case 'ACE': return '#fde047';
    case 'WINNER': return '#22c55e';
    case 'FAULT': return '#ef4444';
    case 'OUT': return '#fb7185';
    case 'LET': return '#60a5fa';
    default: return '#f8fafc';
  }
}

function powerGradient(powerCharge) {
  if (powerCharge < 0.45) return 'linear-gradient(90deg, #22c55e 0%, #4ade80 100%)';
  if (powerCharge < 0.8) return 'linear-gradient(90deg, #eab308 0%, #f59e0b 100%)';
  return 'linear-gradient(90deg, #f97316 0%, #ef4444 100%)';
}

export function TennisHUD({
  sets = [0, 0],
  games = [0, 0],
  points = ['0', '0'],
  score = 0,
  prq = 50,
  lastResult = '',
  powerCharge = 0,
  serveReady = true,
  inRally = false,
  winner = null,
}) {
  const [flashOn, setFlashOn] = React.useState(false);
  const activeLabel = winner === 'player' ? 'WINNER' : winner === 'opponent' ? 'OUT' : lastResult;
  const lastLabelRef = React.useRef(activeLabel);

  React.useEffect(() => {
    if (activeLabel && activeLabel !== lastLabelRef.current) {
      lastLabelRef.current = activeLabel;
      setFlashOn(true);
      const timer = setTimeout(() => setFlashOn(false), 550);
      return () => clearTimeout(timer);
    }
    if (!activeLabel) lastLabelRef.current = '';
    return undefined;
  }, [activeLabel]);

  const barWidth = Math.round(Math.max(0, Math.min(1, powerCharge)) * 100);
  const playerSetCells = [sets[0] > 0 ? 1 : 0, sets[0] > 1 ? 1 : 0];
  const opponentSetCells = [sets[1] > 0 ? 1 : 0, sets[1] > 1 ? 1 : 0];

  return (
    <div style={{
      minWidth: 320,
      padding: 16,
      borderRadius: 18,
      color: '#f8fafc',
      background: 'rgba(8, 12, 20, 0.84)',
      border: '1px solid rgba(255,255,255,0.08)',
      backdropFilter: 'blur(10px)',
      WebkitBackdropFilter: 'blur(10px)',
      boxShadow: '0 12px 40px rgba(0,0,0,0.38)',
      fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      display: 'grid',
      gap: 12,
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
            Tennis Rally
          </div>
          <div style={{ fontSize: 34, fontWeight: 900, color: '#fbbf24', lineHeight: 1 }}>{score}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
            PRQ
          </div>
          <div style={{ fontSize: 24, fontWeight: 800, color: prq >= 75 ? '#22c55e' : prq >= 45 ? '#facc15' : '#f87171' }}>
            {Math.round(prq)}
          </div>
        </div>
      </div>

      <div style={{
        display: 'grid',
        gridTemplateColumns: '1.2fr repeat(2, 54px) 76px 76px',
        gap: 8,
        alignItems: 'center',
        padding: 12,
        borderRadius: 14,
        background: 'rgba(255,255,255,0.05)',
        border: '1px solid rgba(255,255,255,0.07)',
      }}>
        <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8' }}>Player</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 12, color: '#cbd5e1' }}>S1</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 12, color: '#cbd5e1' }}>S2</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 12, color: '#cbd5e1' }}>Games</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 12, color: '#cbd5e1' }}>Points</div>

        <div style={{ fontWeight: 800, color: '#f8fafc' }}>Player</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 22, fontWeight: 800 }}>{playerSetCells[0]}</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 22, fontWeight: 800 }}>{playerSetCells[1]}</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 22, fontWeight: 800 }}>{games[0] ?? 0}</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 24, fontWeight: 900, color: '#fbbf24' }}>{points[0] ?? '0'}</div>

        <div style={{ fontWeight: 800, color: '#fecaca' }}>Opponent</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 22, fontWeight: 800 }}>{opponentSetCells[0]}</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 22, fontWeight: 800 }}>{opponentSetCells[1]}</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 22, fontWeight: 800 }}>{games[1] ?? 0}</div>
        <div style={{ ...SCORE_CELL_STYLE, fontSize: 24, fontWeight: 900, color: '#fca5a5' }}>{points[1] ?? '0'}</div>
      </div>

      {powerCharge > 0.01 && (
        <div style={{ display: 'grid', gap: 6 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: '#cbd5e1', letterSpacing: '0.12em', textTransform: 'uppercase' }}>
            <span>R2 Power Charge</span>
            <span>{barWidth}%</span>
          </div>
          <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
            <div style={{
              width: `${barWidth}%`,
              height: '100%',
              background: powerGradient(powerCharge),
              boxShadow: `0 0 16px ${labelColor(powerCharge > 0.8 ? 'FAULT' : powerCharge > 0.45 ? 'ACE' : 'WINNER')}66`,
              transition: 'width 40ms linear, background 180ms ease',
            }} />
          </div>
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', minHeight: 34 }}>
        <div style={{
          fontSize: 13,
          fontWeight: 800,
          letterSpacing: '0.18em',
          textTransform: 'uppercase',
          color: inRally ? '#e2e8f0' : '#64748b',
          opacity: inRally ? 1 : 0,
          transform: inRally ? 'translateY(0)' : 'translateY(4px)',
          transition: 'opacity 180ms ease, transform 180ms ease',
        }}>
          RALLY!
        </div>
        <div style={{ fontSize: 12, color: serveReady ? '#93c5fd' : '#94a3b8', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
          {winner ? `${winner.toUpperCase()} TAKES IT` : serveReady ? 'Serve Ready' : 'Ball In Play'}
        </div>
      </div>

      <div style={{
        minHeight: 44,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: 14,
        background: activeLabel ? `${labelColor(activeLabel)}14` : 'rgba(255,255,255,0.03)',
        border: `1px solid ${activeLabel ? `${labelColor(activeLabel)}55` : 'rgba(255,255,255,0.06)'}`,
      }}>
        <span style={{
          fontSize: 24,
          fontWeight: 900,
          letterSpacing: '0.16em',
          textTransform: 'uppercase',
          color: labelColor(activeLabel),
          opacity: activeLabel ? 1 : 0.2,
          transform: flashOn ? 'scale(1.12)' : 'scale(1)',
          textShadow: activeLabel ? `0 0 20px ${labelColor(activeLabel)}88` : 'none',
          transition: 'transform 160ms ease, text-shadow 160ms ease, opacity 180ms ease',
        }}>
          {activeLabel || 'Ready'}
        </span>
      </div>
    </div>
  );
}

export default TennisHUD;
