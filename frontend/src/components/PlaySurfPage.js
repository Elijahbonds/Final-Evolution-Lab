import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import SurfMode from '@/game/modes/surf/SurfMode.js';
import GamepadOverlay from '@/game/input/GamepadOverlay.js';

const POLL_MS = 100;

/**
 * Skateboard slice — endless Venice strip (ride/carve archetype).
 * Route: /play/surf. ✕ = ollie · △ (airborne, near rail) = grind.
 */
export default function PlaySurfPage() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const modeRef = useRef(null);

  const [s, setS] = useState(null);
  const [status, setStatus] = useState('loading');

  const startRun = useCallback(async () => {
    const mode = modeRef.current;
    if (!mode) return;
    setStatus('loading');
    try {
      await mode.start(containerRef.current);
      setStatus('playing');
    } catch (err) {
      console.error('[PlaySkate] failed to start', err);
      setStatus('error');
    }
  }, []);

  useEffect(() => {
    const mode = new SurfMode('surfing', canvasRef.current, containerRef.current);
    modeRef.current = mode;
    if (typeof window !== 'undefined') window.__felMode = mode; // dev/test seam

    let pollTimer = null;
    (async () => {
      await startRun();
      pollTimer = setInterval(() => setS(mode.getState()), POLL_MS);
    })();

    return () => {
      if (pollTimer) clearInterval(pollTimer);
      mode.dispose();
      modeRef.current = null;
    };
  }, [startRun]);

  const gamepadProps = modeRef.current?.getGamepadProps?.() ?? {};

  return (
    <div
      ref={containerRef}
      style={{
        position: 'fixed', inset: 0, background: '#160d14', overflow: 'hidden',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', touchAction: 'none' }}
      />

      {/* Mini HUD */}
      <div style={{
        position: 'absolute', top: 14, left: 14, zIndex: 60,
        background: 'rgba(10,8,14,0.85)', border: '1px solid rgba(255,255,255,0.1)',
        borderRadius: 14, padding: 14, color: '#f8fafc', minWidth: 210,
      }}>
        <div style={{ fontSize: 11, letterSpacing: '0.1em', color: '#94a3b8' }}>VENICE BREAK</div>
        <div style={{ fontSize: 32, fontWeight: 900, color: '#facc15' }}>{s?.score ?? 0}</div>
        <div style={{ fontSize: 12, color: '#e2e8f0', display: 'grid', gap: 2, marginTop: 6 }}>
          <span>{s?.skatePhase ?? '—'} · {s?.speed ?? 0} m/s · {s?.distanceM ?? 0}m</span>
          <span>combo {s?.combo ?? 0} · best grind {(s?.bestGrindMs ?? 0) / 1000}s</span>
          {s?.lastTrick && <span style={{ color: '#4FA3E0', fontWeight: 800 }}>{s.lastTrick}</span>}
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

      {status === 'loading' && (
        <div style={overlayStyle}>
          <div style={{ color: '#e2e8f0', fontSize: 18, fontWeight: 700, letterSpacing: '0.06em' }}>
            PADDLING OUT…
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

      {status === 'playing' && <GamepadOverlay {...gamepadProps} isActive />}
    </div>
  );
}

const overlayStyle = {
  position: 'absolute', inset: 0, zIndex: 80,
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  background: 'rgba(10,6,12,0.78)', backdropFilter: 'blur(4px)',
};
