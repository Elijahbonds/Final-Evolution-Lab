import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { BaseballMode } from '@/game/modes/baseball/index.js';
import BaseballHUD from '@/game/modes/baseball/BaseballHUD.js';
import GamepadOverlay from '@/game/input/GamepadOverlay.js';
import { ModePhase } from '@/game/modes/GameModeInterface.js';

const POLL_MS = 100;

/** Playable baseball slice. Route: /play/baseball */
export default function PlayBaseballPage() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const modeRef = useRef(null);

  const [s, setS] = useState(null);
  const [status, setStatus] = useState('loading');

  const startMatch = useCallback(async () => {
    const mode = modeRef.current;
    if (!mode) return;
    setStatus('loading');
    try {
      await mode.start(containerRef.current);
      setStatus('playing');
    } catch (err) {
      console.error('[PlayBaseballPage] failed to start', err);
      setStatus('error');
    }
  }, []);

  useEffect(() => {
    const mode = new BaseballMode('baseball', canvasRef.current, containerRef.current);
    modeRef.current = mode;
    if (typeof window !== 'undefined') window.__felMode = mode; // dev/test seam

    let pollTimer = null;
    (async () => {
      await startMatch();
      pollTimer = setInterval(() => {
        const snapshot = mode.getState();
        setS(snapshot);
        if (snapshot.phase === ModePhase.FINISHED) setStatus('finished');
      }, POLL_MS);
    })();

    return () => {
      if (pollTimer) clearInterval(pollTimer);
      mode.dispose();
      modeRef.current = null;
    };
  }, [startMatch]);

  const gamepadProps = modeRef.current?.getGamepadProps?.() ?? {};

  return (
    <div
      ref={containerRef}
      style={{
        position: 'fixed', inset: 0, background: '#0d1410', overflow: 'hidden',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', touchAction: 'none' }}
      />

      <div style={{ position: 'absolute', top: 14, left: 14, zIndex: 60 }}>
        <BaseballHUD score={s?.score ?? 0} prq={s?.prq ?? 50} atBats={s?.atBats ?? 0} hits={s?.hits ?? 0} homeRuns={s?.homeRuns ?? 0} strikes={s?.strikes ?? 0} balls={s?.balls ?? 0} outs={s?.outs ?? 0} inning={s?.inning ?? 1} lastResult={s?.lastResult ?? ''} pitchInFlight={s?.pitchInFlight ?? false} winner={s?.winner ?? null} />
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
            STEPPING TO THE PLATE…
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
            <div style={{ color: s?.winner === 'player' ? '#facc15' : '#f87171', fontSize: 34, fontWeight: 900 }}>
              {s?.winner === 'player' ? 'GAME WON' : 'GAME OVER'}
            </div>
            <div style={{ color: '#ffffff', fontSize: 18, fontWeight: 700 }}>Score {s?.score ?? 0}</div>
            <button
              onClick={startMatch}
              style={{
                padding: '12px 26px', borderRadius: 12, cursor: 'pointer',
                background: '#facc15', color: '#111827', border: 'none',
                fontSize: 15, fontWeight: 800, letterSpacing: '0.04em',
              }}
            >
              PLAY AGAIN
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
  background: 'rgba(5,8,10,0.78)', backdropFilter: 'blur(4px)',
};
