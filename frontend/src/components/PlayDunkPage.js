import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { DunkingMode } from '@/game/modes/dunking/index.js';
import DunkingHUD from '@/game/modes/dunking/DunkingHUD.js';
import GamepadOverlay from '@/game/input/GamepadOverlay.js';
import { ModePhase } from '@/game/modes/GameModeInterface.js';

const HUD_POLL_MS = 100;

/**
 * Playable Dunking Hero slice — mounts the Babylon.js DunkingScene with the
 * virtual gamepad and premium HUD. Route: /play/dunk
 */
export default function PlayDunkPage() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const modeRef = useRef(null);

  const [hudState, setHudState] = useState(null);
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
      console.error('[PlayDunk] failed to start mode', err);
      setStatus('error');
    }
  }, []);

  useEffect(() => {
    const mode = new DunkingMode('basketball_dunk', canvasRef.current, containerRef.current);
    modeRef.current = mode;
    // Dev/test seam: lets the smoke harness drive input and read sim state.
    if (typeof window !== 'undefined') window.__felMode = mode;

    let unsubscribe = null;
    let pollTimer = null;

    (async () => {
      await startMatch();
      unsubscribe = mode.systems?.hudStateSystem?.subscribe?.((s) => setHudState({ ...s }));
      setHudState(mode.systems?.hudStateSystem?.getState?.() ?? null);
      pollTimer = setInterval(() => {
        const snapshot = mode.getState();
        setModeState(snapshot);
        if (snapshot.phase === ModePhase.FINISHED) setStatus('finished');
      }, HUD_POLL_MS);
    })();

    return () => {
      if (pollTimer) clearInterval(pollTimer);
      unsubscribe?.();
      mode.dispose();
      modeRef.current = null;
    };
  }, [startMatch]);

  const gamepadProps = modeRef.current?.getGamepadProps?.() ?? {};

  return (
    <div
      ref={containerRef}
      style={{
        position: 'fixed', inset: 0,
        background: '#05070c',
        overflow: 'hidden',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <canvas
        ref={canvasRef}
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', touchAction: 'none' }}
      />

      {/* HUD — top-left */}
      <div style={{ position: 'absolute', top: 14, left: 14, zIndex: 60 }}>
        <DunkingHUD
          hudState={hudState}
          styleCharge={modeState?.styleCharge ?? 0}
          powerCharge={modeState?.powerCharge ?? 0}
          isMidAir={modeState?.isMidAir ?? false}
        />
      </div>

      {/* Exit — top-right */}
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

      {/* Loading / error / finished overlays */}
      {status === 'loading' && (
        <div style={overlayStyle}>
          <div style={{ color: '#e2e8f0', fontSize: 18, fontWeight: 700, letterSpacing: '0.06em' }}>
            LOADING VENICE BEACH COURT…
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
            <div style={{ color: '#facc15', fontSize: 30, fontWeight: 900 }}>FINAL SCORE</div>
            <div style={{ color: '#ffffff', fontSize: 52, fontWeight: 900, lineHeight: 1 }}>
              {modeState?.score ?? 0}
            </div>
            <button
              onClick={startMatch}
              style={{
                padding: '12px 26px', borderRadius: 12, cursor: 'pointer',
                background: '#facc15', color: '#111827', border: 'none',
                fontSize: 15, fontWeight: 800, letterSpacing: '0.04em',
              }}
            >
              RUN IT BACK
            </button>
          </div>
        </div>
      )}

      {/* Virtual gamepad */}
      {status === 'playing' && <GamepadOverlay {...gamepadProps} isActive />}
    </div>
  );
}

const overlayStyle = {
  position: 'absolute', inset: 0, zIndex: 80,
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  background: 'rgba(4,6,10,0.78)', backdropFilter: 'blur(4px)',
};
