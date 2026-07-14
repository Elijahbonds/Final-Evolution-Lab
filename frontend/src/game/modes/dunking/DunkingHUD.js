import React, { useEffect, useRef, useState } from 'react';
import { HUDStateSystem } from '../../systems/index.js';

const DEFAULT_HUD_STATE = new HUDStateSystem().getState();

function formatTime(remainingMs) {
  const totalSec = Math.max(0, Math.floor((remainingMs ?? 0) / 1000));
  return `${String(Math.floor(totalSec / 60)).padStart(2, '0')}:${String(totalSec % 60).padStart(2, '0')}`;
}

function prqColor(v) {
  if (v >= 75) return '#22c55e';
  if (v >= 45) return '#f59e0b';
  return '#ef4444';
}

/** Animated score value — flashes on change. */
function AnimatedScore({ value }) {
  const [flash, setFlash] = useState(false);
  const prev = useRef(value);
  useEffect(() => {
    if (value !== prev.current) {
      prev.current = value;
      setFlash(true);
      const t = setTimeout(() => setFlash(false), 350);
      return () => clearTimeout(t);
    }
  }, [value]);
  return (
    <span style={{
      display: 'inline-block',
      fontSize: 38, fontWeight: 900, color: flash ? '#ffffff' : '#facc15',
      transform: flash ? 'scale(1.18)' : 'scale(1)',
      textShadow: flash ? '0 0 20px #facc1588' : 'none',
      transition: 'transform 150ms cubic-bezier(0.34,1.56,0.64,1), color 200ms, text-shadow 200ms',
      lineHeight: 1,
    }}>
      {value}
    </span>
  );
}

/** Combo counter — pulses and glows at high chains. */
function ComboCounter({ chain, multiplier }) {
  const isHot = chain >= 5;
  const isElite = chain >= 10;
  const color = isElite ? '#ef4444' : isHot ? '#f97316' : '#fb923c';
  return (
    <div style={{
      padding: '12px 14px',
      borderRadius: 14,
      background: isHot ? `${color}18` : 'rgba(255,255,255,0.05)',
      border: `1px solid ${isHot ? color + '44' : 'rgba(255,255,255,0.08)'}`,
      boxShadow: isHot ? `0 0 18px ${color}33` : 'none',
      transition: 'all 200ms',
    }}>
      <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 4 }}>
        Combo Chain
      </div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 10 }}>
        <span style={{
          fontSize: 30, fontWeight: 900, color,
          textShadow: isHot ? `0 0 14px ${color}88` : 'none',
          animation: isElite ? 'none' : undefined,
          transition: 'color 150ms, text-shadow 150ms',
        }}>
          x{multiplier}
        </span>
        <span style={{ fontSize: 14, color: '#e2e8f0' }}>
          {chain} hit{chain === 1 ? '' : 's'}
        </span>
      </div>
    </div>
  );
}

/** Analog power-charge meters — mirrors iOS styleTriggerHeld / powerTriggerHeld. */
function ChargeMeter({ label, depth, color }) {
  if (depth < 0.02) return null;
  const pct = Math.round(depth * 100);
  return (
    <div style={{ display: 'grid', gap: 3 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 10, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.08em' }}>{label}</span>
        <span style={{ fontSize: 10, fontWeight: 700, color }}>{pct}%</span>
      </div>
      <div style={{ height: 6, borderRadius: 999, background: 'rgba(255,255,255,0.08)', overflow: 'hidden' }}>
        <div style={{
          height: '100%', width: `${pct}%`, background: color,
          boxShadow: `0 0 6px ${color}88`,
          transition: 'width 40ms linear',
        }} />
      </div>
    </div>
  );
}

/**
 * Premium HUD for Dunking Hero mode.
 *
 * New vs baseline:
 *   - AnimatedScore: flash + scale on point gain
 *   - ComboCounter: glows orange/red at high chains, elite pulsing
 *   - PRQ bar: animated fill + color transition + flash on ≥75
 *   - ChargeMeter: shows L2/R2 analog trigger depth
 *   - Countdown: timer turns red at ≤10s
 *
 * iOS parity: mirrors PremiumGameplayHUDStrip + FELPremiumHudComponents.
 *
 * @param {{
 *   hudState?: object,
 *   styleCharge?: number,
 *   powerCharge?: number,
 *   isMidAir?: boolean,
 * }} props
 */
export function DunkingHUD({ hudState, styleCharge = 0, powerCharge = 0, isMidAir = false }) {
  const state = {
    ...DEFAULT_HUD_STATE,
    ...(hudState || {}),
    score:  { ...DEFAULT_HUD_STATE.score,  ...(hudState?.score  || {}) },
    prq:    { ...DEFAULT_HUD_STATE.prq,    ...(hudState?.prq    || {}) },
    combo:  { ...DEFAULT_HUD_STATE.combo,  ...(hudState?.combo  || {}) },
    timer:  { ...DEFAULT_HUD_STATE.timer,  ...(hudState?.timer  || {}) },
  };

  const prqValue   = Math.max(0, Math.min(100, state.prq.prq ?? 0));
  const color      = prqColor(prqValue);
  const remainMs   = state.timer.remainingMs ?? 0;
  const timeIsLow  = remainMs <= 10000 && remainMs > 0;

  return (
    <div style={{
      display: 'grid', gap: 12,
      minWidth: 280, maxWidth: 360, padding: 16,
      borderRadius: 18,
      background: 'rgba(7, 10, 16, 0.86)',
      border: '1px solid rgba(255,255,255,0.08)',
      backdropFilter: 'blur(8px)',
      WebkitBackdropFilter: 'blur(8px)',
      color: '#f8fafc',
      fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      boxShadow: '0 4px 32px rgba(0,0,0,0.6)',
    }}>

      {/* Score + Timer row */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 10 }}>
        <div>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 2 }}>
            Score
          </div>
          <AnimatedScore value={state.score.total} />
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase', color: '#94a3b8', marginBottom: 2 }}>
            Time
          </div>
          <span style={{
            fontSize: 28, fontWeight: 800,
            color: timeIsLow ? '#ef4444' : '#60a5fa',
            textShadow: timeIsLow ? '0 0 12px #ef444488' : 'none',
            transition: 'color 300ms, text-shadow 300ms',
          }}>
            {formatTime(remainMs)}
          </span>
          {isMidAir && (
            <div style={{ fontSize: 10, color: '#facc15', fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase' }}>
              ↑ IN AIR
            </div>
          )}
        </div>
      </div>

      {/* PRQ Meter */}
      <div style={{ display: 'grid', gap: 6 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span style={{ fontSize: 11, letterSpacing: '0.08em', textTransform: 'uppercase', color: '#94a3b8' }}>
            PRQ · {state.prq.tier ?? 'Silver'}
          </span>
          <span style={{ fontWeight: 700, color, fontSize: 12 }}>{Math.round(prqValue)} / 100</span>
        </div>
        <div style={{ height: 10, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
          <div style={{
            height: '100%', width: `${prqValue}%`, background: color,
            boxShadow: prqValue >= 75 ? `0 0 10px ${color}88` : 'none',
            transition: 'width 180ms ease-out, background 300ms, box-shadow 300ms',
          }} />
        </div>
      </div>

      {/* Combo */}
      <ComboCounter chain={state.combo.chain} multiplier={state.combo.multiplier} />

      {/* Charge meters (shown when triggers are held) */}
      {(styleCharge > 0.02 || powerCharge > 0.02) && (
        <div style={{ display: 'grid', gap: 6 }}>
          <ChargeMeter label="Style  L2" depth={styleCharge}  color="#a855f7" />
          <ChargeMeter label="Power  R2" depth={powerCharge}  color="#f97316" />
        </div>
      )}

    </div>
  );
}

export default DunkingHUD;
