import React, { useState, useEffect } from 'react';

function meterColor(power) {
  if (power >= 0.85) return '#ef4444';
  if (power >= 0.55) return '#facc15';
  return '#22c55e';
}

function scoreVsPar(strokes, par) {
  if (!strokes) return 'E';
  const diff = strokes - par;
  if (diff === 0) return 'E';
  return diff > 0 ? `+${diff}` : `${diff}`;
}

function flashLabelText(result = '') {
  const upper = String(result || '').toUpperCase();
  if (upper.includes('HOLE IN ONE')) return 'HOLE IN ONE ⛳';
  if (upper.includes('EAGLE')) return 'EAGLE 🦅';
  if (upper.includes('BIRDIE')) return 'BIRDIE 🐦';
  if (upper.includes('PAR')) return 'PAR';
  if (upper.includes('BOGEY')) return 'BOGEY';
  return '';
}

export function GolfHUD({
  score = 0,
  prq = 50,
  hole = 1,
  totalHoles = 9,
  par = 3,
  strokes = 0,
  distanceToPin = 150,
  lastShotDistance = 0,
  lastResult = '',
  swingCharging = false,
  swingPower = 0,
  winner = null,
  windDirection = '→',
  windStrength = 0,
}) {
  const [flashLabel, setFlashLabel] = useState('');
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const label = flashLabelText(lastResult);
    if (!label) return undefined;
    setFlashLabel(label);
    setIsVisible(true);
    const timer = setTimeout(() => setIsVisible(false), 1400);
    return () => clearTimeout(timer);
  }, [lastResult]);

  const powerPct = Math.round(clamp(swingPower, 0, 1) * 100);
  const prqPct = Math.max(0, Math.min(100, Math.round(prq)));
  const relative = scoreVsPar(strokes, par);
  const powerColor = meterColor(swingPower);

  return (
    <div
      style={{
        position: 'relative',
        display: 'grid',
        gap: 12,
        minWidth: 320,
        maxWidth: 420,
        padding: 16,
        borderRadius: 20,
        background: 'rgba(5, 18, 14, 0.86)',
        border: '1px solid rgba(255,255,255,0.08)',
        color: '#f8fafc',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        boxShadow: '0 10px 40px rgba(0,0,0,0.45)',
        overflow: 'hidden',
      }}
    >
      {isVisible && flashLabel && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'grid',
            placeItems: 'center',
            background: 'linear-gradient(135deg, rgba(34,197,94,0.12), rgba(59,130,246,0.08))',
            fontSize: 28,
            fontWeight: 900,
            letterSpacing: '0.08em',
            color: '#fef08a',
            textShadow: '0 0 18px rgba(250,204,21,0.72)',
            opacity: isVisible ? 1 : 0,
            transition: 'opacity 260ms ease-out',
            pointerEvents: 'none',
          }}
        >
          {flashLabel}
        </div>
      )}

      {winner && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'grid',
            placeItems: 'center',
            background: 'rgba(2, 8, 23, 0.78)',
            backdropFilter: 'blur(6px)',
            zIndex: 2,
          }}
        >
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 13, letterSpacing: '0.16em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 8 }}>
              Round Complete
            </div>
            <div style={{ fontSize: 32, fontWeight: 900, color: '#facc15', textShadow: '0 0 18px rgba(250,204,21,0.45)' }}>
              {winner}
            </div>
            <div style={{ marginTop: 6, fontSize: 14, color: '#e2e8f0' }}>Press ✕ to play again</div>
          </div>
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
            Score
          </div>
          <div style={{ fontSize: 42, fontWeight: 900, color: '#facc15', lineHeight: 1 }}>{score}</div>
        </div>

        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
            Hole
          </div>
          <div style={{ fontSize: 24, fontWeight: 800, color: '#86efac' }}>
            Hole {hole} / {totalHoles} • Par {par}
          </div>
          <div style={{ marginTop: 4, fontSize: 13, fontWeight: 700, color: '#dbeafe' }}>
            {Math.round(distanceToPin)} yds to pin
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 10 }}>
        <Card label="Strokes" value={strokes || '—'} accent="#f8fafc" />
        <Card label="Vs Par" value={relative} accent={relative.startsWith('+') ? '#f87171' : relative === 'E' ? '#e2e8f0' : '#4ade80'} />
        <Card label="Last Shot" value={lastShotDistance ? `${Math.round(lastShotDistance)} yds` : '—'} accent="#60a5fa" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: 14, alignItems: 'stretch' }}>
        <div style={{ display: 'grid', gap: 10 }}>
          <div
            style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              padding: '12px 14px',
              borderRadius: 14,
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.08)',
            }}
          >
            <div>
              <div style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
                Wind
              </div>
              <div style={{ marginTop: 4, fontSize: 20, fontWeight: 800, color: '#bfdbfe' }}>
                {windDirection} {windStrength}%
              </div>
            </div>
            <div style={{ fontSize: 13, color: '#cbd5e1' }}>
              {lastResult || 'Pick your landing spot'}
            </div>
          </div>

          <div style={{ display: 'grid', gap: 6 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
                PRQ
              </span>
              <span style={{ fontSize: 12, fontWeight: 800, color: prqPct >= 75 ? '#22c55e' : prqPct >= 50 ? '#facc15' : '#ef4444' }}>
                {prqPct}
              </span>
            </div>
            <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
              <div
                style={{
                  width: `${prqPct}%`,
                  height: '100%',
                  background: prqPct >= 75 ? '#22c55e' : prqPct >= 50 ? '#facc15' : '#ef4444',
                  boxShadow: '0 0 14px rgba(34,197,94,0.4)',
                  transition: 'width 180ms ease-out',
                }}
              />
            </div>
          </div>
        </div>

        <div
          style={{
            width: 72,
            padding: 10,
            borderRadius: 16,
            background: 'rgba(255,255,255,0.05)',
            border: '1px solid rgba(255,255,255,0.08)',
            display: 'grid',
            justifyItems: 'center',
            gap: 8,
          }}
        >
          <div style={{ fontSize: 10, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Power
          </div>
          <div
            style={{
              position: 'relative',
              width: 22,
              height: 138,
              borderRadius: 999,
              background: 'linear-gradient(180deg, rgba(239,68,68,0.18) 0%, rgba(250,204,21,0.15) 48%, rgba(34,197,94,0.12) 100%)',
              overflow: 'hidden',
              border: '1px solid rgba(255,255,255,0.08)',
            }}
          >
            <div
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                height: '5%',
                background: 'rgba(255,255,255,0.14)',
                boxShadow: swingCharging && swingPower >= 0.95 ? '0 0 16px rgba(255,255,255,0.95)' : 'none',
              }}
            />
            <div
              style={{
                position: 'absolute',
                inset: 'auto 0 0 0',
                height: swingCharging ? `${powerPct}%` : '0%',
                background: `linear-gradient(180deg, ${powerColor}, ${powerColor}aa)`,
                boxShadow: `0 0 18px ${powerColor}88`,
                transition: 'height 40ms linear',
              }}
            />
          </div>
          <div style={{ fontSize: 11, fontWeight: 800, color: powerColor }}>{swingCharging ? `${powerPct}%` : 'READY'}</div>
          <div style={{ fontSize: 9, color: '#f8fafc', textShadow: swingPower >= 0.95 ? '0 0 10px rgba(255,255,255,0.8)' : 'none' }}>
            PERFECT
          </div>
        </div>
      </div>
    </div>
  );
}

function Card({ label, value, accent }) {
  return (
    <div
      style={{
        display: 'grid',
        gap: 4,
        padding: '12px 14px',
        borderRadius: 14,
        background: 'rgba(255,255,255,0.05)',
        border: '1px solid rgba(255,255,255,0.08)',
      }}
    >
      <span style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
        {label}
      </span>
      <span style={{ fontSize: 24, fontWeight: 900, color: accent || '#f8fafc', lineHeight: 1 }}>
        {value}
      </span>
    </div>
  );
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export default GolfHUD;
