import React from 'react';
import { HUDStateSystem } from '../../systems/index.js';

const DEFAULT_HUD_STATE = new HUDStateSystem().getState();

function formatTimeRemaining(remainingMs) {
  const totalSeconds = Math.max(0, Math.floor((remainingMs ?? 0) / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

function resolvePrqColor(prqValue) {
  if (prqValue >= 75) {
    return '#22c55e';
  }

  if (prqValue >= 45) {
    return '#f59e0b';
  }

  return '#ef4444';
}

/**
 * Presentational HUD for Dunking Hero mode.
 *
 * @param {{ hudState?: ReturnType<HUDStateSystem['getState']> }} props
 * @returns {JSX.Element}
 */
export function DunkingHUD({ hudState }) {
  const state = {
    ...DEFAULT_HUD_STATE,
    ...(hudState || {}),
    score: {
      ...DEFAULT_HUD_STATE.score,
      ...(hudState?.score || {}),
    },
    prq: {
      ...DEFAULT_HUD_STATE.prq,
      ...(hudState?.prq || {}),
    },
    combo: {
      ...DEFAULT_HUD_STATE.combo,
      ...(hudState?.combo || {}),
    },
    timer: {
      ...DEFAULT_HUD_STATE.timer,
      ...(hudState?.timer || {}),
    },
  };

  const prqValue = Math.max(0, Math.min(100, state.prq.prq ?? 0));
  const prqColor = resolvePrqColor(prqValue);

  return (
    <div
      style={{
        display: 'grid',
        gap: 14,
        minWidth: 280,
        maxWidth: 360,
        padding: 18,
        borderRadius: 18,
        background: 'rgba(7, 10, 16, 0.82)',
        border: '1px solid rgba(255,255,255,0.08)',
        color: '#f8fafc',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12 }}>
        <div>
          <div style={{ fontSize: 12, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Score
          </div>
          <div style={{ fontSize: 32, fontWeight: 800, color: '#facc15' }}>{state.score.total}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 12, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
            Time Remaining
          </div>
          <div style={{ fontSize: 28, fontWeight: 800, color: '#60a5fa' }}>
            {formatTimeRemaining(state.timer.remainingMs)}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gap: 8 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: 12, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
            PRQ Meter
          </span>
          <span style={{ fontWeight: 700, color: prqColor }}>{Math.round(prqValue)} / 100</span>
        </div>
        <div
          style={{
            width: '100%',
            height: 12,
            borderRadius: 999,
            overflow: 'hidden',
            background: 'rgba(255,255,255,0.08)',
          }}
        >
          <div
            style={{
              width: `${prqValue}%`,
              height: '100%',
              background: prqColor,
              transition: 'width 180ms ease-out',
            }}
          />
        </div>
      </div>

      <div
        style={{
          display: 'grid',
          gap: 6,
          padding: '12px 14px',
          borderRadius: 14,
          background: 'rgba(255,255,255,0.05)',
          border: '1px solid rgba(255,255,255,0.08)',
        }}
      >
        <div style={{ fontSize: 12, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
          Combo Chain
        </div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 12 }}>
          <span style={{ fontSize: 28, fontWeight: 800, color: '#fb923c' }}>
            x{state.combo.multiplier}
          </span>
          <span style={{ fontSize: 15, color: '#e2e8f0' }}>
            {state.combo.chain} hit{state.combo.chain === 1 ? '' : 's'}
          </span>
        </div>
      </div>
    </div>
  );
}

export default DunkingHUD;
