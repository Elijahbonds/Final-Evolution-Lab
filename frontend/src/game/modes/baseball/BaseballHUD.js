import React, { useState, useEffect } from 'react';

function DotRow({ label, count, max, color }) {
  return (
    <div style={{ display: 'grid', gap: 6 }}>
      <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>{label}</div>
      <div style={{ display: 'flex', gap: 6 }}>
        {Array.from({ length: max }).map((_, index) => {
          const filled = index < count;
          return (
            <span
              key={`${label}-${index}`}
              style={{
                width: 12,
                height: 12,
                borderRadius: 999,
                background: filled ? color : 'rgba(255,255,255,0.08)',
                boxShadow: filled ? `0 0 10px ${color}66` : 'inset 0 0 0 1px rgba(255,255,255,0.08)',
                transition: 'all 160ms ease-out',
              }}
            />
          );
        })}
      </div>
    </div>
  );
}

function prqColor(value) {
  if (value >= 75) return '#22c55e';
  if (value >= 45) return '#f59e0b';
  return '#ef4444';
}

export function BaseballHUD({
  score,
  prq,
  atBats,
  hits,
  homeRuns,
  strikes,
  balls,
  outs,
  inning,
  lastResult,
  pitchInFlight,
  winner,
}) {
  const [flashLabel, setFlashLabel] = useState('');
  const [flashVisible, setFlashVisible] = useState(false);
  const [pulseOn, setPulseOn] = useState(false);

  useEffect(() => {
    if (!lastResult) return undefined;
    setFlashLabel(lastResult);
    setFlashVisible(true);
    const fadeTimer = setTimeout(() => setFlashVisible(false), 700);
    const clearTimer = setTimeout(() => setFlashLabel(''), 1020);
    return () => {
      clearTimeout(fadeTimer);
      clearTimeout(clearTimer);
    };
  }, [lastResult]);

  useEffect(() => {
    if (!pitchInFlight) {
      setPulseOn(false);
      return undefined;
    }
    setPulseOn(true);
    const timer = setInterval(() => setPulseOn((value) => !value), 320);
    return () => clearInterval(timer);
  }, [pitchInFlight]);

  const safePrq = Math.max(0, Math.min(100, prq ?? 0));
  const avgLabel = atBats > 0 ? `${hits}/${atBats}` : '0/0';
  const flashMap = {
    HOMERUN: 'HOMERUN 🏆',
    HIT: 'HIT ✅',
    FOUL: 'FOUL',
    STRIKE: 'STRIKE',
    BALL: 'BALL',
  };
  const flashText = flashMap[flashLabel] || flashLabel;
  const flashColor = flashLabel === 'HOMERUN'
    ? '#facc15'
    : flashLabel === 'HIT'
    ? '#22c55e'
    : flashLabel === 'BALL'
    ? '#60a5fa'
    : '#f97316';

  return (
    <div style={{
      display: 'grid',
      gap: 14,
      minWidth: 300,
      maxWidth: 380,
      padding: 16,
      borderRadius: 20,
      background: 'rgba(5, 10, 18, 0.84)',
      border: '1px solid rgba(255,255,255,0.08)',
      color: '#f8fafc',
      fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      boxShadow: '0 8px 32px rgba(0,0,0,0.55)',
      backdropFilter: 'blur(10px)',
      WebkitBackdropFilter: 'blur(10px)',
      position: 'relative',
      overflow: 'hidden',
    }}>
      {winner && (
        <div style={{
          position: 'absolute',
          inset: 0,
          display: 'grid',
          placeItems: 'center',
          background: 'rgba(2, 6, 14, 0.78)',
          zIndex: 2,
          textAlign: 'center',
          padding: 20,
        }}>
          <div>
            <div style={{ fontSize: 12, letterSpacing: '0.16em', textTransform: 'uppercase', color: '#93c5fd', marginBottom: 8 }}>
              Final Result
            </div>
            <div style={{ fontSize: 30, fontWeight: 900, color: '#f8fafc', textShadow: '0 0 18px rgba(250,204,21,0.25)' }}>
              {winner}
            </div>
          </div>
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>Score</div>
          <div style={{ fontSize: 38, fontWeight: 900, color: '#facc15', lineHeight: 1 }}>{score ?? 0}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.12em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>Inning</div>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            {[1, 2, 3].map((slot) => (
              <span
                key={slot}
                style={{
                  width: 24,
                  height: 24,
                  borderRadius: 999,
                  display: 'grid',
                  placeItems: 'center',
                  fontSize: 12,
                  fontWeight: 800,
                  background: inning === slot ? 'rgba(96,165,250,0.22)' : 'rgba(255,255,255,0.06)',
                  border: inning === slot ? '1px solid rgba(96,165,250,0.55)' : '1px solid rgba(255,255,255,0.08)',
                  color: inning === slot ? '#dbeafe' : '#cbd5e1',
                }}
              >
                {slot}
              </span>
            ))}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gap: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>PRQ</span>
          <span style={{ fontSize: 12, fontWeight: 800, color: prqColor(safePrq) }}>{Math.round(safePrq)} / 100</span>
        </div>
        <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
          <div style={{
            height: '100%',
            width: `${safePrq}%`,
            background: prqColor(safePrq),
            boxShadow: `0 0 12px ${prqColor(safePrq)}66`,
            transition: 'width 180ms ease-out, background 200ms ease-out',
          }} />
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 10 }}>
        <DotRow label="B" count={Math.min(4, balls ?? 0)} max={4} color="#60a5fa" />
        <DotRow label="S" count={Math.min(3, strikes ?? 0)} max={3} color="#f97316" />
        <DotRow label="O" count={Math.min(3, outs ?? 0)} max={3} color="#ef4444" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 12 }}>
        <div style={{ padding: '10px 12px', borderRadius: 14, background: 'rgba(255,255,255,0.05)' }}>
          <div style={{ fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>At Bats</div>
          <div style={{ fontSize: 24, fontWeight: 800 }}>{atBats ?? 0}</div>
        </div>
        <div style={{ padding: '10px 12px', borderRadius: 14, background: 'rgba(255,255,255,0.05)' }}>
          <div style={{ fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>Hits / HR</div>
          <div style={{ fontSize: 24, fontWeight: 800 }}>{hits ?? 0} / {homeRuns ?? 0}</div>
        </div>
        <div style={{ padding: '10px 12px', borderRadius: 14, background: 'rgba(255,255,255,0.05)' }}>
          <div style={{ fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>AVG</div>
          <div style={{ fontSize: 24, fontWeight: 800 }}>{avgLabel}</div>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', minHeight: 40 }}>
        <div style={{
          opacity: flashVisible ? 1 : 0,
          transform: flashVisible ? 'translateY(0)' : 'translateY(8px)',
          transition: 'opacity 220ms ease-out, transform 220ms ease-out',
          fontWeight: 900,
          fontSize: 20,
          color: flashColor,
          textShadow: `0 0 14px ${flashColor}55`,
        }}>
          {flashText}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Pitch
          </span>
          <span style={{
            width: 16,
            height: 16,
            borderRadius: 999,
            background: pitchInFlight ? '#22c55e' : 'rgba(255,255,255,0.10)',
            boxShadow: pitchInFlight ? '0 0 16px rgba(34,197,94,0.65)' : 'none',
            transform: pitchInFlight ? `scale(${pulseOn ? 1.18 : 0.92})` : 'scale(1)',
            opacity: pitchInFlight ? (pulseOn ? 1 : 0.72) : 0.45,
            transition: 'transform 180ms ease-out, opacity 180ms ease-out, box-shadow 180ms ease-out',
          }} />
        </div>
      </div>
    </div>
  );
}

export default BaseballHUD;
