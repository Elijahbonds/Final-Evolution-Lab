import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { KarateMode } from '@/game/modes/karate/index.js';
import KarateHUD from '@/game/modes/karate/KarateHUD.js';
import GamepadOverlay from '@/game/input/GamepadOverlay.js';
import { ModePhase } from '@/game/modes/GameModeInterface.js';

const POLL_MS = 100;

/**
 * Playable Karate slice — Zen Dojo scene + round gate + premium HUD.
 * Route: /play/karate
 */
export default function PlayKaratePage() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const modeRef = useRef(null);

  const [modeState, setModeState] = useState(null);
  const [status, setStatus] = useState('loading'); // loading | playing | finished | error

  const startMatch = useCallback(async () => {
    const mode = modeRef.current;
    if (!mode) return;
    setStatus('loading');
    try {
      await mode.start(containerRef.current);
      setStatus('playing');
    } catch (err) {
      console.error('[PlayKarate] failed to start mode', err);
      setStatus('error');
    }
  }, []);

  useEffect(() => {
    const mode = new KarateMode('karate', canvasRef.current, containerRef.current);
    modeRef.current = mode;
    if (typeof window !== 'undefined') window.__felMode = mode; // dev/test seam

    let pollTimer = null;
    (async () => {
      await startMatch();
      pollTimer = setInterval(() => {
        const snapshot = mode.getState();
        setModeState(snapshot);
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
  const s = modeState ?? {};
  const preFight = status === 'playing' && (s.matchPhase === 'Ready' || s.matchPhase === 'Countdown');

  return (
    <div
      ref={containerRef}
      style={{
        position: 'fixed', inset: 0, background: '#0a0603', overflow: 'hidden',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', touchAction: 'none' }}
      />

      <div style={{ position: 'absolute', top: 14, left: 14, zIndex: 60 }}>
        <KarateHUD
          playerHealth={s.playerHealth ?? 100}
          opponentHealth={s.opponentHealth ?? 100}
          score={s.score ?? 0}
          prq={s.prq ?? 50}
          combo={s.combo ?? 0}
          timeRemaining={s.timeRemaining ?? 180}
          lastAction={s.lastAction ?? ''}
          showPerfectGuard={s.showPerfectGuard ?? false}
          winner={s.winner ?? null}
        />
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
            ENTERING THE DOJO…
          </div>
        </div>
      )}
      {preFight && (
        <div style={{ ...overlayStyle, background: 'rgba(4,3,2,0.35)', pointerEvents: 'none' }}>
          <div style={{ color: '#facc15', fontSize: 54, fontWeight: 900, letterSpacing: '0.1em', textShadow: '0 0 30px #f9731688' }}>
            {s.matchPhase === 'Ready' ? 'READY' : Math.max(1, Math.ceil((s.countdownMsRemaining ?? 0) / 1000))}
          </div>
        </div>
      )}
      {status === 'error' && (
        <div style={overlayStyle}>
          <div style={{ color: '#f87171', fontSize: 16, fontWeight: 700 }}>
            Failed to start the match — check the console.
          </div>
        </div>
      )}
      {status === 'finished' && (
        <div style={overlayStyle}>
          <div style={{ display: 'grid', gap: 14, justifyItems: 'center' }}>
            <div style={{ color: s.winner === 'player' ? '#facc15' : '#f87171', fontSize: 34, fontWeight: 900 }}>
              {s.winner === 'player' ? 'VICTORY' : s.winner === 'opponent' ? 'DEFEAT' : 'TIME'}
            </div>
            <div style={{ color: '#ffffff', fontSize: 20, fontWeight: 700 }}>Score {s.score ?? 0}</div>
            <button
              onClick={startMatch}
              style={{
                padding: '12px 26px', borderRadius: 12, cursor: 'pointer',
                background: '#facc15', color: '#111827', border: 'none',
                fontSize: 15, fontWeight: 800, letterSpacing: '0.04em',
              }}
            >
              REMATCH
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
  background: 'rgba(4,3,2,0.78)', backdropFilter: 'blur(4px)',
};
