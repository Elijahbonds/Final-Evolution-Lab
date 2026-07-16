import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import SprintMode from '@/game/modes/sprint/SprintMode.js';
import GamepadOverlay from '@/game/input/GamepadOverlay.js';

const POLL_MS = 100;

/**
 * Sprint — 100m dash on the rhythm archetype. Route: /play/sprint
 * □ = left foot · ○ = right foot. Alternate on the beat; jump the gun and
 * you're back in the blocks.
 */
export default function PlaySprintPage() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const modeRef = useRef(null);

  const [s, setS] = useState(null);
  const [status, setStatus] = useState('loading');

  const startRace = useCallback(async () => {
    const mode = modeRef.current;
    if (!mode) return;
    setStatus('loading');
    try {
      await mode.start(containerRef.current);
      setStatus('playing');
    } catch (err) {
      console.error('[PlaySprint] failed to start', err);
      setStatus('error');
    }
  }, []);

  useEffect(() => {
    const mode = new SprintMode('sprint', canvasRef.current, containerRef.current);
    modeRef.current = mode;
    if (typeof window !== 'undefined') window.__felMode = mode; // dev/test seam

    let pollTimer = null;
    (async () => {
      await startRace();
      pollTimer = setInterval(() => {
        const snap = mode.getState();
        setS(snap);
        if (snap.phase === 'finished') setStatus('finished');
      }, POLL_MS);
    })();

    return () => {
      if (pollTimer) clearInterval(pollTimer);
      mode.dispose();
      modeRef.current = null;
    };
  }, [startRace]);

  const gamepadProps = modeRef.current?.getGamepadProps?.() ?? {};
  const pre = s?.racePhase === 'Ready' || s?.racePhase === 'Set';

  return (
    <div
      ref={containerRef}
      style={{
        position: 'fixed', inset: 0, background: '#0a0e16', overflow: 'hidden',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', touchAction: 'none' }}
      />

      <div style={{
        position: 'absolute', top: 14, left: 14, zIndex: 60,
        background: 'rgba(8,10,16,0.85)', border: '1px solid rgba(255,255,255,0.1)',
        borderRadius: 14, padding: 14, color: '#f8fafc', minWidth: 220,
      }}>
        <div style={{ fontSize: 11, letterSpacing: '0.1em', color: '#94a3b8' }}>100M DASH</div>
        <div style={{ fontSize: 34, fontWeight: 900, color: '#3DDC84' }}>
          {(s?.timeS ?? 0).toFixed(2)}s
        </div>
        <div style={{ fontSize: 12, color: '#e2e8f0', display: 'grid', gap: 2, marginTop: 6 }}>
          <span>{s?.distanceM ?? 0}m · {s?.speed ?? 0} m/s (top {s?.topSpeed ?? 0})</span>
          <span>
            perfect {s?.cadence?.perfect ?? 0} · good {s?.cadence?.good ?? 0} ·
            off {s?.cadence?.off ?? 0} · stumble {s?.cadence?.fault ?? 0}
          </span>
          {s?.falseStarts > 0 && <span style={{ color: '#f87171' }}>false starts: {s.falseStarts}</span>}
          {s?.lastStep && <span style={{ color: '#60a5fa', fontWeight: 800 }}>{s.lastStep}</span>}
        </div>
      </div>

      <button
        onClick={() => navigate(-1)}
        style={{
          position: 'absolute', top: 14, right: 14, zIndex: 60,
          padding: '8px 14px', borderRadius: 10, cursor: 'pointer',
          background: 'rgba(15,18,26,0.85)', color: '#e2e8f0',
          border: '1px solid rgba(255,255,255,0.14)', fontSize: 13, fontWeight: 600,
        }}
      >
        ✕ Exit
      </button>

      {status === 'playing' && pre && (
        <div style={{ ...overlayStyle, background: 'rgba(6,8,14,0.35)', pointerEvents: 'none' }}>
          <div style={{ color: s?.racePhase === 'Set' ? '#f97316' : '#facc15', fontSize: 54, fontWeight: 900, letterSpacing: '0.12em' }}>
            {s?.racePhase === 'Set' ? 'SET…' : 'ON YOUR MARKS'}
          </div>
        </div>
      )}
      {status === 'loading' && (
        <div style={overlayStyle}>
          <div style={{ color: '#e2e8f0', fontSize: 18, fontWeight: 700, letterSpacing: '0.06em' }}>
            LACING UP…
          </div>
        </div>
      )}
      {status === 'error' && (
        <div style={overlayStyle}>
          <div style={{ color: '#f87171', fontSize: 16, fontWeight: 700 }}>
            Failed to start — check the console.
          </div>
        </div>
      )}
      {status === 'finished' && (
        <div style={overlayStyle}>
          <div style={{ display: 'grid', gap: 14, justifyItems: 'center' }}>
            <div style={{ color: '#facc15', fontSize: 34, fontWeight: 900 }}>FINISH</div>
            <div style={{ color: '#ffffff', fontSize: 46, fontWeight: 900, lineHeight: 1 }}>
              {(s?.finishTimeS ?? 0).toFixed(2)}s
            </div>
            <div style={{ color: '#94a3b8', fontSize: 13 }}>
              top speed {s?.topSpeed ?? 0} m/s · perfect steps {s?.cadence?.perfect ?? 0}
            </div>
            <button
              onClick={startRace}
              style={{
                padding: '12px 26px', borderRadius: 12, cursor: 'pointer',
                background: '#facc15', color: '#111827', border: 'none',
                fontSize: 15, fontWeight: 800, letterSpacing: '0.04em',
              }}
            >
              RUN IT AGAIN
            </button>
          </div>
        </div>
      )}

      {status === 'playing' && <GamepadOverlay {...gamepadProps} isActive />}
    </div>
  );
}

const overlayStyle = {
  position: 'absolute', inset: 0, zIndex: 80,
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  background: 'rgba(6,8,14,0.78)', backdropFilter: 'blur(4px)',
};
