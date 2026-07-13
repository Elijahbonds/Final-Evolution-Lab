import React from 'react';

function HealthBar({ label, value, align = 'left' }) {
  const percentage = Math.max(0, Math.min(100, value));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, minWidth: 220 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', color: '#f5f5f5', fontSize: 13, fontWeight: 700 }}>
        <span>{label}</span>
        <span>{Math.round(percentage)} HP</span>
      </div>
      <div
        style={{
          width: '100%',
          height: 18,
          borderRadius: 999,
          overflow: 'hidden',
          background: 'rgba(255,255,255,0.12)',
          border: '1px solid rgba(255,255,255,0.15)',
        }}
      >
        <div
          style={{
            width: `${percentage}%`,
            height: '100%',
            background: 'linear-gradient(90deg, #7f1d1d 0%, #ef4444 100%)',
            transformOrigin: align === 'right' ? 'right center' : 'left center',
            transition: 'width 180ms ease-out',
          }}
        />
      </div>
    </div>
  );
}

export function KarateHUD({ hudState, playerHealth, opponentHealth }) {
  const state = hudState || {};

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 16,
        padding: 16,
        borderRadius: 18,
        background: 'rgba(7, 10, 16, 0.78)',
        border: '1px solid rgba(255,255,255,0.08)',
        color: '#f5f5f5',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
        <HealthBar label="Player" value={playerHealth} />
        <HealthBar label="Opponent" value={opponentHealth} align="right" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 12 }}>
        {[
          ['Score', state.score ?? 0],
          ['PRQ', state.prq ?? 0],
          ['Combo', state.combo ?? 0],
          ['Time', `${state.timeRemaining ?? 0}s`],
        ].map(([label, value]) => (
          <div
            key={label}
            style={{
              padding: '12px 14px',
              borderRadius: 14,
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.08)',
            }}
          >
            <div style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#a1a1aa', marginBottom: 4 }}>
              {label}
            </div>
            <div style={{ fontSize: 24, fontWeight: 800 }}>{value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

export default KarateHUD;
