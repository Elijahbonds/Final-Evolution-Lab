import React, { useEffect, useMemo, useState } from 'react';

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function powerColor(power) {
  if (power < 0.45) return '#22c55e';
  if (power < 0.75) return '#facc15';
  return '#ef4444';
}

export function SoccerHUD({
  goalsScored = 0,
  goalsConceded = 0,
  shotsRemaining = 5,
  score = 0,
  prq = 50,
  lastResult = '',
  shotPowerMeter = 0,
  aimIndicator = 0,
  phase = 'warmup',
  winner = null,
}) {
  const [showFlash, setShowFlash] = useState(false);
  const power = clamp(shotPowerMeter, 0, 1);
  const aim = clamp(aimIndicator, -1, 1);
  const powerFill = `${Math.round(power * 100)}%`;
  const powerTint = powerColor(power);
  const dots = useMemo(
    () => Array.from({ length: 5 }, (_, index) => index < shotsRemaining),
    [shotsRemaining]
  );

  useEffect(() => {
    if (!lastResult) return undefined;
    setShowFlash(true);
    const timer = setTimeout(() => setShowFlash(false), 950);
    return () => clearTimeout(timer);
  }, [lastResult]);

  return (
    <div
      style={{
        display: 'grid',
        gap: 12,
        minWidth: 280,
        maxWidth: 380,
        padding: 16,
        borderRadius: 18,
        background: 'rgba(7, 10, 16, 0.84)',
        border: '1px solid rgba(255,255,255,0.08)',
        color: '#f8fafc',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        boxShadow: '0 12px 40px rgba(0,0,0,0.4)',
        backdropFilter: 'blur(10px)',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Penalty Score
          </div>
          <div style={{ marginTop: 4, fontSize: 28, fontWeight: 900, color: '#f8fafc' }}>
            PLAYER {goalsScored} – {goalsConceded} OPPONENT
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Match
          </div>
          <div style={{ marginTop: 4, fontSize: 14, fontWeight: 800, color: '#38bdf8' }}>
            {phase === 'finished' ? 'FINAL' : 'LIVE'}
          </div>
          {winner && (
            <div style={{ marginTop: 4, fontSize: 12, fontWeight: 700, color: winner === 'player' ? '#22c55e' : winner === 'draw' ? '#facc15' : '#ef4444' }}>
              {winner === 'draw' ? 'DRAW' : `${winner.toUpperCase()} WINS`}
            </div>
          )}
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>
            FEL Score
          </div>
          <div style={{ fontSize: 30, fontWeight: 900, color: '#facc15' }}>{score}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>
            PRQ
          </div>
          <div style={{ fontSize: 22, fontWeight: 800, color: prq >= 70 ? '#22c55e' : prq >= 45 ? '#facc15' : '#ef4444' }}>
            {Math.round(prq)}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gap: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Shots Remaining
          </span>
          <span style={{ fontSize: 12, fontWeight: 800, color: '#e2e8f0' }}>
            {dots.map((filled) => (filled ? '●' : '○')).join(' ')}
          </span>
        </div>
      </div>

      <div style={{ display: 'grid', gap: 8 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Aim
          </span>
          <span style={{ fontSize: 11, fontWeight: 700, color: '#cbd5e1' }}>
            LEFT · CENTER · RIGHT
          </span>
        </div>
        <div style={{ position: 'relative', height: 14, borderRadius: 999, background: 'linear-gradient(90deg, rgba(239,68,68,0.18), rgba(250,204,21,0.18), rgba(34,197,94,0.18))', border: '1px solid rgba(255,255,255,0.08)' }}>
          <div
            style={{
              position: 'absolute',
              top: -8,
              left: `calc(${((aim + 1) / 2) * 100}% - 8px)`,
              width: 0,
              height: 0,
              borderLeft: '8px solid transparent',
              borderRight: '8px solid transparent',
              borderTop: '12px solid #f8fafc',
              filter: 'drop-shadow(0 0 8px rgba(255,255,255,0.35))',
              transition: 'left 80ms linear',
            }}
          />
        </div>
      </div>

      {power > 0.05 && (
        <div style={{ display: 'grid', gap: 8 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>
              Shot Power
            </span>
            <span style={{ fontSize: 12, fontWeight: 800, color: powerTint }}>
              {Math.round(power * 100)}%
            </span>
          </div>
          <div style={{ height: 10, borderRadius: 999, background: 'rgba(255,255,255,0.08)', overflow: 'hidden' }}>
            <div
              style={{
                width: powerFill,
                height: '100%',
                background: `linear-gradient(90deg, #22c55e 0%, #facc15 55%, #ef4444 100%)`,
                boxShadow: `0 0 14px ${powerTint}88`,
                transformOrigin: 'left center',
                transition: 'width 60ms linear, box-shadow 120ms ease-out',
              }}
            />
          </div>
        </div>
      )}

      <div
        style={{
          minHeight: 30,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 20,
          fontWeight: 900,
          letterSpacing: '0.12em',
          color: lastResult === 'GOAL' ? '#22c55e' : lastResult === 'SAVE' ? '#38bdf8' : '#ef4444',
          opacity: showFlash ? 1 : 0.18,
          transform: showFlash ? 'scale(1)' : 'scale(0.94)',
          textShadow: showFlash ? '0 0 18px currentColor' : 'none',
          transition: 'opacity 240ms ease-out, transform 240ms ease-out, text-shadow 240ms ease-out',
        }}
      >
        {lastResult || 'READY'}
      </div>
    </div>
  );
}

export default SoccerHUD;
