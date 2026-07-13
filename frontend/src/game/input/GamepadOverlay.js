import React, { useCallback, useRef, useState } from 'react';

// ---------------------------------------------------------------------------
// Constants — mirroring iOS InputManager deadzone & range values
// ---------------------------------------------------------------------------
const ANALOG_RANGE = 28;       // px max stick displacement
const DEADZONE_INNER = 0.06;   // matches iOS InputManager.deadzoneInner

// eslint-disable-next-line no-unused-vars
function applyDeadzone(value, inner = DEADZONE_INNER) {
  const v = Math.max(0, Math.min(1, value));
  if (v <= inner) return 0;
  return (v - inner) / (1 - inner);
}

function clampAnalog(translation, radius) {
  const len = Math.sqrt(translation.x * translation.x + translation.y * translation.y);
  if (len <= radius) return translation;
  const s = radius / len;
  return { x: translation.x * s, y: translation.y * s };
}

function normalizeAnalog(offset) {
  return {
    x: Math.max(-1, Math.min(1, offset.x / ANALOG_RANGE)),
    y: Math.max(-1, Math.min(1, -offset.y / ANALOG_RANGE)), // invert Y so up = +1
  };
}

// ---------------------------------------------------------------------------
// Face button colours — matches iOS ArcadeFaceButton.displayColor
// ---------------------------------------------------------------------------
const FACE_COLORS = {
  triangle: '#4EC87A',
  square:   '#F570B5',
  circle:   '#F57070',
  cross:    '#61A6FA',
};
const FACE_SYMBOLS = { triangle: '△', square: '□', circle: '○', cross: '✕' };

// ---------------------------------------------------------------------------
// ShoulderButtons — L1/L2 or R1/R2 strip
// ---------------------------------------------------------------------------
function ShoulderButtons({ side, triggerDepth, onShoulder, onTrigger }) {
  const isLeft = side === 'left';
  const s1 = isLeft ? 'L1' : 'R1';
  const s2 = isLeft ? 'L2' : 'R2';
  const [s1Pressed, setS1Pressed] = useState(false);
  const triggerStartY = useRef(null);
  const triggerActive = (triggerDepth ?? 0) >= 0.85;
  const fillPct = Math.round((triggerDepth ?? 0) * 100);

  const handleS1Down = useCallback((e) => {
    e.preventDefault();
    setS1Pressed(true);
    onShoulder(s1, 1.0);
  }, [onShoulder, s1]);

  const handleS1Up = useCallback(() => {
    setS1Pressed(false);
    onShoulder(s1, 0);
  }, [onShoulder, s1]);

  const handleTriggerStart = useCallback((e) => {
    e.preventDefault();
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    triggerStartY.current = clientY;
  }, []);

  const handleTriggerMove = useCallback((e) => {
    if (triggerStartY.current === null) return;
    e.preventDefault();
    const clientY = e.touches ? e.touches[0].clientY : e.clientY;
    const delta = clientY - triggerStartY.current;
    const depth = Math.max(0, Math.min(1, delta / 32));
    onTrigger(s2, depth);
  }, [onTrigger, s2]);

  const handleTriggerEnd = useCallback(() => {
    triggerStartY.current = null;
    onTrigger(s2, 0);
  }, [onTrigger, s2]);

  return (
    <div style={{ display: 'flex', flexDirection: isLeft ? 'row' : 'row-reverse', gap: 6, alignItems: 'flex-start', pointerEvents: 'auto' }}>
      {/* S1 button */}
      <button
        onPointerDown={handleS1Down}
        onPointerUp={handleS1Up}
        onPointerLeave={handleS1Up}
        style={{
          width: 48, height: 22, borderRadius: 999,
          border: `1.5px solid rgba(255,255,255,${s1Pressed ? 0.5 : 0.18})`,
          background: s1Pressed ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.08)',
          color: 'rgba(255,255,255,0.8)', fontSize: 9, fontWeight: 800, letterSpacing: '0.08em',
          cursor: 'pointer', transform: s1Pressed ? 'scale(0.94)' : 'scale(1)',
          transition: 'transform 80ms, background 80ms', touchAction: 'none', userSelect: 'none',
        }}
      >
        {s1}
      </button>

      {/* S2 analog trigger */}
      <div
        onPointerDown={handleTriggerStart}
        onPointerMove={handleTriggerMove}
        onPointerUp={handleTriggerEnd}
        onPointerLeave={handleTriggerEnd}
        style={{
          width: 48, height: 22, borderRadius: 999,
          border: `1.5px solid rgba(255,255,255,${triggerActive ? 0.55 : 0.18})`,
          background: 'rgba(0,0,0,0.3)', overflow: 'hidden', position: 'relative',
          cursor: 'pointer', touchAction: 'none', userSelect: 'none',
        }}
      >
        <div style={{
          position: 'absolute', left: 0, top: 0, height: '100%', width: `${fillPct}%`,
          background: triggerActive ? 'rgba(250,204,21,0.7)' : 'rgba(255,255,255,0.18)',
          transition: 'width 40ms linear',
        }} />
        <span style={{
          position: 'absolute', inset: 0, display: 'flex', alignItems: 'center',
          justifyContent: 'center', fontSize: 9, fontWeight: 800, letterSpacing: '0.08em',
          color: 'rgba(255,255,255,0.8)', pointerEvents: 'none',
        }}>
          {s2}
        </span>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// DPad — mirrors iOS dPadCluster
// ---------------------------------------------------------------------------
function DPad({ onDPad }) {
  const [pressed, setPressed] = useState(null);

  function makeHandler(dir) {
    return {
      onPointerDown(e) { e.preventDefault(); setPressed(dir); onDPad(dir); },
      onPointerUp()    { setPressed(null); },
      onPointerLeave() { setPressed(null); },
    };
  }

  const btn = (dir, symbol) => {
    const isPressed = pressed === dir;
    return (
      <div
        {...makeHandler(dir)}
        style={{
          width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center',
          borderRadius: 6,
          background: isPressed ? 'rgba(255,255,255,0.28)' : 'rgba(255,255,255,0.12)',
          border: '1px solid rgba(255,255,255,0.14)', color: 'rgba(255,255,255,0.85)',
          fontSize: 13, fontWeight: 800, cursor: 'pointer',
          transform: isPressed ? 'scale(0.92)' : 'scale(1)',
          transition: 'transform 60ms, background 60ms',
          touchAction: 'none', userSelect: 'none',
        }}
      >
        {symbol}
      </div>
    );
  };

  return (
    <div style={{
      display: 'grid',
      gridTemplateAreas: `". up ." "left mid right" ". down ."`,
      gridTemplateColumns: '36px 36px 36px', gridTemplateRows: '36px 36px 36px',
      gap: 2, padding: 6, background: 'rgba(0,0,0,0.22)', borderRadius: 12, pointerEvents: 'auto',
    }}>
      <div style={{ gridArea: 'up' }}>    {btn('up',    '▲')}</div>
      <div style={{ gridArea: 'left' }}>  {btn('left',  '◀')}</div>
      <div style={{ gridArea: 'mid', width: 36, height: 36, borderRadius: 4, background: 'rgba(255,255,255,0.05)' }} />
      <div style={{ gridArea: 'right' }}> {btn('right', '▶')}</div>
      <div style={{ gridArea: 'down' }}>  {btn('down',  '▼')}</div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// FaceButtons — △/□/○/✕ cluster, mirrors iOS faceButtonCluster
// ---------------------------------------------------------------------------
function FaceButtons({ onFaceButton }) {
  const [pressed, setPressed] = useState(null);

  function makeHandler(id) {
    return {
      onPointerDown(e) { e.preventDefault(); setPressed(id); onFaceButton(id); },
      onPointerUp()    { setPressed(null); },
      onPointerLeave() { setPressed(null); },
    };
  }

  const btn = (id) => {
    const color = FACE_COLORS[id];
    const symbol = FACE_SYMBOLS[id];
    const isPressed = pressed === id;
    return (
      <div
        key={id}
        {...makeHandler(id)}
        style={{
          width: 42, height: 42, borderRadius: '50%',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          background: isPressed ? color : `${color}22`,
          border: `1.5px solid ${color}88`,
          color: isPressed ? '#fff' : color,
          fontSize: 16, fontWeight: 900,
          boxShadow: `0 0 ${isPressed ? 10 : 4}px ${color}55`,
          transform: isPressed ? 'scale(0.9)' : 'scale(1)',
          transition: 'transform 60ms, background 60ms, box-shadow 60ms',
          cursor: 'pointer', touchAction: 'none', userSelect: 'none',
        }}
      >
        {symbol}
      </div>
    );
  };

  return (
    <div style={{
      display: 'grid',
      gridTemplateAreas: `". triangle ." "square . circle" ". cross ."`,
      gridTemplateColumns: '42px 42px 42px', gridTemplateRows: '42px 42px 42px',
      gap: 4, padding: 8, background: 'rgba(0,0,0,0.18)', borderRadius: 16, pointerEvents: 'auto',
    }}>
      <div style={{ gridArea: 'triangle' }}>{btn('triangle')}</div>
      <div style={{ gridArea: 'square' }}>  {btn('square')}</div>
      <div style={{ gridArea: 'circle' }}>  {btn('circle')}</div>
      <div style={{ gridArea: 'cross' }}>   {btn('cross')}</div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// AnalogStick — drag-to-deflect with spring-back, mirrors iOS analogStick(…)
// ---------------------------------------------------------------------------
function AnalogStick({ label, onStick }) {
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const startPos = useRef(null);
  const animRef  = useRef(null);

  const onPointerDown = useCallback((e) => {
    e.preventDefault();
    if (animRef.current) cancelAnimationFrame(animRef.current);
    startPos.current = { x: e.clientX, y: e.clientY };
  }, []);

  const onPointerMove = useCallback((e) => {
    if (!startPos.current) return;
    e.preventDefault();
    const raw     = { x: e.clientX - startPos.current.x, y: e.clientY - startPos.current.y };
    const clamped = clampAnalog(raw, ANALOG_RANGE);
    setOffset(clamped);
    onStick(normalizeAnalog(clamped));
  }, [onStick]);

  const onPointerUp = useCallback(() => {
    startPos.current = null;
    const spring = () => {
      setOffset(prev => {
        const next = { x: prev.x * 0.55, y: prev.y * 0.55 };
        if (Math.abs(next.x) < 0.5 && Math.abs(next.y) < 0.5) {
          onStick({ x: 0, y: 0 });
          return { x: 0, y: 0 };
        }
        onStick(normalizeAnalog(next));
        animRef.current = requestAnimationFrame(spring);
        return next;
      });
    };
    animRef.current = requestAnimationFrame(spring);
  }, [onStick]);

  return (
    <div
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerLeave={onPointerUp}
      style={{
        width: 64, height: 64, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(255,255,255,0.08) 0%, rgba(0,0,0,0.3) 100%)',
        border: '1px solid rgba(255,255,255,0.1)',
        position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center',
        touchAction: 'none', userSelect: 'none', cursor: 'grab', pointerEvents: 'auto',
      }}
    >
      <div style={{
        width: 28, height: 28, borderRadius: '50%',
        background: 'linear-gradient(135deg, #4a4a4a 0%, #2a2a2a 100%)',
        border: '1px solid rgba(255,255,255,0.22)',
        boxShadow: '0 2px 4px rgba(0,0,0,0.5)',
        position: 'absolute',
        transform: `translate(${offset.x}px, ${offset.y}px)`,
        transition: startPos.current ? 'none' : 'transform 80ms ease-out',
        pointerEvents: 'none',
      }} />
      <span style={{
        position: 'absolute', bottom: 6, fontSize: 7, fontWeight: 900,
        color: 'rgba(255,255,255,0.2)', letterSpacing: '0.1em', fontFamily: 'monospace',
        pointerEvents: 'none',
      }}>
        {label}
      </span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// GamepadOverlay — main export
// ---------------------------------------------------------------------------

/**
 * Virtual PS2-style gamepad overlay for FEL web game modes.
 *
 * Architecture mirrors iOS PS2GamepadOverlay.swift + PS2ControllerShellView.swift.
 * Layout:
 *   Top strip  — L1/L2 (left) · R1/R2 (right) shoulder/trigger buttons
 *   Left gutter — D-pad (top) + Left analog stick (bottom)
 *   Right gutter — Face buttons △□○✕ (top) + Right analog stick (bottom)
 *
 * All callbacks emit normalised values that match the iOS InputManager contract
 * so Abacus AI / Claude can map web ↔ iOS directly.
 *
 * @param {{
 *   onFaceButton?: (id: 'triangle'|'square'|'circle'|'cross') => void,
 *   onDPad?:       (dir: 'up'|'down'|'left'|'right') => void,
 *   onLeftStick?:  ({x: number, y: number}) => void,
 *   onRightStick?: ({x: number, y: number}) => void,
 *   onShoulder?:   (id: 'L1'|'R1', value: 0|1) => void,
 *   onTrigger?:    (id: 'L2'|'R2', depth: number) => void,
 *   l2Depth?:      number,
 *   r2Depth?:      number,
 *   isActive?:     boolean,
 * }} props
 */
export function GamepadOverlay({
  onFaceButton  = () => {},
  onDPad        = () => {},
  onLeftStick   = () => {},
  onRightStick  = () => {},
  onShoulder    = () => {},
  onTrigger     = () => {},
  l2Depth       = 0,
  r2Depth       = 0,
  isActive      = true,
}) {
  return (
    <div
      style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        opacity: isActive ? 1 : 0.35,
        display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', zIndex: 100,
      }}
      aria-label="Game controller"
      role="group"
    >
      {/* ── Shoulder / trigger strip ── */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', padding: '6px 12px 0', pointerEvents: 'none' }}>
        <ShoulderButtons side="left"  triggerDepth={l2Depth} onShoulder={onShoulder} onTrigger={onTrigger} />
        <ShoulderButtons side="right" triggerDepth={r2Depth} onShoulder={onShoulder} onTrigger={onTrigger} />
      </div>

      {/* ── Controller shell ── */}
      <div style={{
        padding: '10px 10px 16px',
        background: 'linear-gradient(180deg, rgba(28,28,38,0.82) 0%, rgba(14,14,22,0.90) 60%, rgba(8,8,14,0.94) 100%)',
        borderTop: '1px solid rgba(255,255,255,0.06)',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        pointerEvents: 'none',
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', gap: 8 }}>

          {/* Left gutter: D-pad + Left stick */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 8, pointerEvents: 'none' }}>
            <DPad onDPad={onDPad} />
            <AnalogStick label="L" onStick={onLeftStick} />
          </div>

          {/* Center branding */}
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'flex-end', gap: 6, paddingBottom: 8, pointerEvents: 'none' }}>
            <div style={{ display: 'flex', gap: 10 }}>
              {['SELECT', 'START'].map(lbl => (
                <div key={lbl} style={{ width: 24, height: 7, borderRadius: 999, background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.1)' }} />
              ))}
            </div>
            <span style={{ fontSize: 7, fontWeight: 700, letterSpacing: '0.25em', color: 'rgba(255,255,255,0.12)', fontFamily: 'monospace', textTransform: 'uppercase' }}>
              DUALSHOCK®2
            </span>
          </div>

          {/* Right gutter: Face buttons + Right stick */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8, pointerEvents: 'none' }}>
            <FaceButtons onFaceButton={onFaceButton} />
            <AnalogStick label="R" onStick={onRightStick} />
          </div>

        </div>
      </div>
    </div>
  );
}

export default GamepadOverlay;
