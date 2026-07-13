import React, { useEffect, useMemo, useRef, useState } from 'react';

function downText(down, toGo) {
  const suffix = ['st', 'nd', 'rd'][down - 1] || 'th';
  return `${down}${suffix} & ${toGo}`;
}

function meterColor(prq) {
  if (prq >= 80) return '#22c55e';
  if (prq >= 50) return '#f59e0b';
  return '#ef4444';
}

function StatCard({ label, value, accent }) {
  return (
    <div
      style={{
        display: 'grid',
        gap: 4,
        padding: '12px 14px',
        borderRadius: 14,
        background: 'rgba(255,255,255,0.06)',
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

export function FootballHUD({
  score = 0,
  prq = 50,
  yardsGained = 0,
  down = 1,
  toGo = 10,
  touchdowns = 0,
  lastMove = '',
  speed = 1,
  isBursting = false,
  winner = null,
}) {
  const [tdFlash, setTdFlash] = useState(false);
  const [burstMeter, setBurstMeter] = useState(100);
  const previousTouchdowns = useRef(touchdowns);

  useEffect(() => {
    if (touchdowns > previousTouchdowns.current || /touchdown/i.test(lastMove)) {
      previousTouchdowns.current = touchdowns;
      setTdFlash(true);
      const timer = setTimeout(() => setTdFlash(false), 1100);
      return () => clearTimeout(timer);
    }
    previousTouchdowns.current = touchdowns;
    return undefined;
  }, [touchdowns, lastMove]);

  useEffect(() => {
    const timer = setInterval(() => {
      setBurstMeter((value) => {
        if (isBursting) return Math.max(0, value - 5.5);
        return Math.min(100, value + 3.5);
      });
    }, 120);
    return () => clearInterval(timer);
  }, [isBursting]);

  const prqColor = meterColor(prq);
  const speedPct = useMemo(() => Math.min(100, Math.round(((speed - 1) / 0.85) * 100)), [speed]);

  return (
    <div
      style={{
        position: 'relative',
        display: 'grid',
        gap: 12,
        minWidth: 300,
        maxWidth: 380,
        padding: 16,
        borderRadius: 18,
        background: 'rgba(5, 10, 18, 0.88)',
        border: '1px solid rgba(255,255,255,0.08)',
        color: '#f8fafc',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        boxShadow: '0 10px 40px rgba(0,0,0,0.45)',
        overflow: 'hidden',
      }}
    >
      {tdFlash && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            display: 'grid',
            placeItems: 'center',
            background: 'linear-gradient(135deg, rgba(20,71,200,0.18), rgba(239,68,68,0.18))',
            color: '#facc15',
            fontSize: 28,
            fontWeight: 900,
            letterSpacing: '0.16em',
            textShadow: '0 0 18px rgba(250,204,21,0.75)',
            pointerEvents: 'none',
          }}
        >
          TOUCHDOWN
        </div>
      )}

      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
            Score
          </div>
          <div style={{ fontSize: 40, fontWeight: 900, color: '#facc15', lineHeight: 1 }}>{score}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
            Down & Distance
          </div>
          <div style={{ fontSize: 28, fontWeight: 900, color: '#60a5fa', lineHeight: 1 }}>
            {downText(down, toGo)}
          </div>
          {winner && (
            <div style={{ marginTop: 4, fontSize: 11, fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', color: winner === 'player' ? '#22c55e' : '#ef4444' }}>
              {winner === 'player' ? 'Drive won' : 'Defense stands'}
            </div>
          )}
        </div>
      </div>

      <div style={{ display: 'grid', gap: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
            PRQ
          </span>
          <span style={{ fontWeight: 800, color: prqColor }}>{Math.round(prq)}</span>
        </div>
        <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
          <div
            style={{
              width: `${Math.max(0, Math.min(100, prq))}%`,
              height: '100%',
              background: prqColor,
              boxShadow: `0 0 14px ${prqColor}66`,
              transition: 'width 160ms ease-out',
            }}
          />
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, minmax(0, 1fr))', gap: 10 }}>
        <StatCard label="Yards" value={yardsGained.toFixed ? yardsGained.toFixed(1) : yardsGained} accent="#e2e8f0" />
        <StatCard label="TDs" value={touchdowns} accent="#22c55e" />
        <StatCard label="Speed" value={`${Math.round(speed * 100)}%`} accent={isBursting ? '#f97316' : '#60a5fa'} />
      </div>

      <div
        style={{
          display: 'grid',
          gap: 6,
          padding: '12px 14px',
          borderRadius: 14,
          background: 'rgba(15,23,42,0.75)',
          border: `1px solid ${isBursting ? 'rgba(249,115,22,0.45)' : 'rgba(255,255,255,0.08)'}`,
        }}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Speed Burst
          </span>
          <span style={{ fontSize: 12, fontWeight: 800, color: isBursting ? '#f97316' : '#94a3b8' }}>
            {isBursting ? 'BOOSTING' : 'READY'}
          </span>
        </div>
        <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
          <div
            style={{
              width: `${burstMeter}%`,
              height: '100%',
              background: 'linear-gradient(90deg, #facc15, #f97316)',
              boxShadow: isBursting ? '0 0 16px rgba(249,115,22,0.65)' : 'none',
              transition: 'width 120ms linear, box-shadow 120ms linear',
            }}
          />
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: '#94a3b8' }}>
          <span>L2 / R2 burst</span>
          <span>{speedPct > 0 ? `+${speedPct}%` : 'Cruise'}</span>
        </div>
      </div>

      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: '10px 12px',
          borderRadius: 14,
          background: 'rgba(255,255,255,0.04)',
          border: '1px solid rgba(255,255,255,0.08)',
        }}
      >
        <span style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
          Last Move
        </span>
        <span style={{ fontSize: 14, fontWeight: 800, color: '#f8fafc' }}>
          {lastMove || '—'}
        </span>
      </div>
    </div>
  );
}

export default FootballHUD;
