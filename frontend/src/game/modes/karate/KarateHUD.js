import React, { useEffect, useRef, useState } from 'react';

const LOW_HP_THRESHOLD = 25;

function clampHP(v) { return Math.max(0, Math.min(100, v)); }

function HealthBar({ hp, isPlayer }) {
  const [displayHp, setDisplayHp] = useState(hp);
  const prevHp = useRef(hp);
  const [flash, setFlash] = useState(false);

  useEffect(() => {
    if (hp < prevHp.current) {
      setFlash(true);
      const t = setTimeout(() => setFlash(false), 300);
      prevHp.current = hp;
      return () => clearTimeout(t);
    }
    prevHp.current = hp;
  }, [hp]);

  useEffect(() => {
    const diff = hp - displayHp;
    if (Math.abs(diff) < 0.5) { setDisplayHp(hp); return; }
    const t = setTimeout(() => setDisplayHp(prev => prev + diff * 0.25), 16);
    return () => clearTimeout(t);
  }, [hp, displayHp]);

  const clamped    = clampHP(displayHp);
  const isLow      = clamped <= LOW_HP_THRESHOLD;
  const isCritical = clamped <= 10;
  const barColor   = isCritical ? '#ef4444' : isLow ? '#f97316' : '#22c55e';

  return (
    <div style={{ display: 'grid', gap: 4 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ fontSize: 10, color: '#94a3b8', letterSpacing: '0.1em', textTransform: 'uppercase' }}>
          {isPlayer ? 'YOU' : 'OPPONENT'}
        </span>
        <span style={{ fontSize: 13, fontWeight: 800, color: flash ? '#ffffff' : barColor, transition: 'color 100ms' }}>
          {Math.round(clamped)}
        </span>
      </div>
      <div style={{
        height: 12, borderRadius: 999, overflow: 'hidden',
        background: 'rgba(255,255,255,0.08)',
        boxShadow: isCritical ? '0 0 10px rgba(239,68,68,0.4)' : 'none',
        transition: 'box-shadow 300ms',
        position: 'relative',
      }}>
        <div style={{
          height: '100%', width: `${clampHP(hp)}%`,
          background: 'rgba(239,68,68,0.3)',
          position: 'absolute', left: 0, top: 0,
          transition: 'width 600ms cubic-bezier(0.4,0,0.2,1)',
        }} />
        <div style={{
          height: '100%', width: `${clamped}%`,
          background: barColor,
          boxShadow: `0 0 6px ${barColor}88`,
          transition: 'width 80ms linear, background 300ms',
          position: 'relative',
        }} />
      </div>
    </div>
  );
}

function ActionLabel({ text }) {
  const [visible, setVisible] = useState(false);
  const [currentText, setCurrentText] = useState('');
  const timerRef = useRef(null);
  useEffect(() => {
    if (!text) return;
    setCurrentText(text);
    setVisible(true);
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => setVisible(false), 900);
  }, [text]);
  return (
    <div style={{ textAlign: 'center', height: 28, opacity: visible ? 1 : 0, transform: visible ? 'translateY(0) scale(1)' : 'translateY(-8px) scale(0.85)', transition: 'opacity 150ms, transform 150ms' }}>
      <span style={{ fontSize: 13, fontWeight: 900, letterSpacing: '0.12em', textTransform: 'uppercase', color: currentText === 'PERFECT GUARD' ? '#22c55e' : currentText === 'KO' ? '#ef4444' : currentText === 'DODGE' ? '#a855f7' : '#f97316' }}>
        {currentText}
      </span>
    </div>
  );
}

/**
 * Premium HUD for Karate: Dojo Breach.
 *
 * Features: dual animated health bars, drain animation, color shift at low HP,
 * red vignette at ≤25 HP, floating action text, combo glow, PRQ meter.
 *
 * iOS parity: mirrors FELPremiumHudComponents + PremiumGameplayHUDStrip
 * (chakraBar, showPerfectGuard, karateHitFlash indicator).
 */
export function KarateHUD({
  playerHealth   = 100,
  opponentHealth = 100,
  score          = 0,
  prq            = 50,
  combo          = 0,
  timeRemaining  = 180,
  lastAction     = '',
  showPerfectGuard = false,
  winner         = null,
}) {
  const isLowHP   = playerHealth <= LOW_HP_THRESHOLD;
  const timeIsLow = timeRemaining <= 10 && timeRemaining > 0;
  const labelText = showPerfectGuard ? 'PERFECT GUARD' : lastAction;
  const prqColor  = prq >= 75 ? '#22c55e' : prq >= 45 ? '#f59e0b' : '#ef4444';

  return (
    <div style={{
      display: 'grid', gap: 10, minWidth: 280, maxWidth: 380, padding: 14,
      borderRadius: 18,
      background: 'rgba(7,10,16,0.88)',
      border: `1px solid rgba(255,255,255,${isLowHP ? 0.2 : 0.08})`,
      backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
      color: '#f8fafc',
      fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      boxShadow: isLowHP ? '0 0 30px rgba(239,68,68,0.35)' : '0 4px 24px rgba(0,0,0,0.6)',
      transition: 'box-shadow 400ms',
    }}>

      {/* Score + Timer */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <div style={{ fontSize: 10, color: '#94a3b8', letterSpacing: '0.1em', textTransform: 'uppercase' }}>Score</div>
          <div style={{ fontSize: 28, fontWeight: 900, color: '#facc15', lineHeight: 1.1 }}>{score}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 10, color: '#94a3b8', letterSpacing: '0.1em', textTransform: 'uppercase' }}>Time</div>
          <div style={{ fontSize: 24, fontWeight: 800, color: timeIsLow ? '#ef4444' : '#60a5fa', transition: 'color 300ms' }}>
            {String(Math.floor(timeRemaining / 60)).padStart(2, '0')}:{String(timeRemaining % 60).padStart(2, '0')}
          </div>
        </div>
      </div>

      {/* Health bars */}
      <div style={{ display: 'grid', gap: 6 }}>
        <HealthBar hp={playerHealth}   isPlayer={true}  />
        <div style={{ textAlign: 'center', fontSize: 11, fontWeight: 900, color: '#60a5fa', letterSpacing: '0.15em' }}>VS</div>
        <HealthBar hp={opponentHealth} isPlayer={false} />
      </div>

      {/* Action label */}
      <ActionLabel text={labelText} />

      {/* Combo + PRQ */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
        <div style={{ padding: '6px 10px', borderRadius: 10, background: combo >= 5 ? 'rgba(249,115,22,0.15)' : 'rgba(255,255,255,0.05)', border: `1px solid ${combo >= 5 ? 'rgba(249,115,22,0.4)' : 'rgba(255,255,255,0.08)'}` }}>
          <span style={{ fontSize: 10, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.08em' }}>Combo</span>
          <div style={{ fontSize: 22, fontWeight: 900, color: combo >= 8 ? '#ef4444' : combo >= 5 ? '#f97316' : '#fb923c', lineHeight: 1.1 }}>{combo}✕</div>
        </div>
        <div style={{ flex: 1, display: 'grid', gap: 4 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 10, color: '#94a3b8', textTransform: 'uppercase', letterSpacing: '0.08em' }}>PRQ</span>
            <span style={{ fontSize: 11, fontWeight: 700, color: prqColor }}>{Math.round(prq)}</span>
          </div>
          <div style={{ height: 8, borderRadius: 999, overflow: 'hidden', background: 'rgba(255,255,255,0.08)' }}>
            <div style={{ height: '100%', width: `${prq}%`, background: prqColor, transition: 'width 150ms ease-out' }} />
          </div>
        </div>
      </div>

      {/* Winner overlay */}
      {winner && (
        <div style={{ textAlign: 'center', padding: '8px 0', fontSize: 20, fontWeight: 900, letterSpacing: '0.15em', color: winner === 'player' ? '#22c55e' : '#ef4444', textShadow: `0 0 20px ${winner === 'player' ? '#22c55e' : '#ef4444'}` }}>
          {winner === 'player' ? '🏆 VICTORY' : '💀 DEFEATED'}
        </div>
      )}
    </div>
  );
}

export default KarateHUD;
