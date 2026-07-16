import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import StoryMode from '@/game/modes/story/StoryMode.js';
import GamepadOverlay from '@/game/input/GamepadOverlay.js';

const POLL_MS = 100;

/** Story Mode — the Venice board. ✕ = roll · □ = strike (boss fights).
 *  Route: /play/story */
export default function PlayStoryPage() {
  const navigate = useNavigate();
  const canvasRef = useRef(null);
  const containerRef = useRef(null);
  const modeRef = useRef(null);
  const [s, setS] = useState(null);
  const [status, setStatus] = useState('loading');

  const startStory = useCallback(async () => {
    const mode = modeRef.current;
    if (!mode) return;
    setStatus('loading');
    try {
      await mode.start(containerRef.current);
      setStatus('playing');
    } catch (err) {
      console.error('[PlayStory] failed to start', err);
      setStatus('error');
    }
  }, []);

  useEffect(() => {
    const mode = new StoryMode('story', canvasRef.current, containerRef.current);
    modeRef.current = mode;
    if (typeof window !== 'undefined') window.__felMode = mode;
    let pollTimer = null;
    (async () => {
      await startStory();
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
  }, [startStory]);

  const gamepadProps = modeRef.current?.getGamepadProps?.() ?? {};

  return (
    <div ref={containerRef} style={{ position: 'fixed', inset: 0, background: '#0b0812', overflow: 'hidden', fontFamily: 'system-ui, sans-serif' }}>
      <canvas ref={canvasRef} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block', touchAction: 'none' }} />

      <div style={{ position: 'absolute', top: 14, left: 14, zIndex: 60, background: 'rgba(10,8,16,0.88)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 14, padding: 14, color: '#f8fafc', minWidth: 240 }}>
        <div style={{ fontSize: 11, letterSpacing: '0.1em', color: '#94a3b8' }}>STORY · VENICE BOARD</div>
        <div style={{ fontSize: 30, fontWeight: 900, color: '#F2C14E' }}>{s?.shards ?? 0} <span style={{ fontSize: 13, color: '#94a3b8' }}>shards</span></div>
        <div style={{ fontSize: 12, color: '#e2e8f0', display: 'grid', gap: 2, marginTop: 6 }}>
          <span>HP {s?.hp ?? 100} · bosses {s?.bossesDefeated ?? 0}/{s?.bossesTotal ?? 4} · space {s?.tokenIndex ?? 0}</span>
          {s?.lastRoll > 0 && <span>last roll: {s.lastRoll}</span>}
          <span style={{ color: '#93c5fd' }}>{s?.lastEvent ?? ''}</span>
        </div>
        {s?.boss && (
          <div style={{ marginTop: 8, padding: 8, borderRadius: 10, background: 'rgba(201,76,76,0.16)', border: '1px solid rgba(201,76,76,0.4)' }}>
            <div style={{ fontWeight: 900, color: '#f87171' }}>{s.boss.name}</div>
            <div style={{ height: 8, borderRadius: 999, background: 'rgba(255,255,255,0.1)', marginTop: 4 }}>
              <div style={{ height: '100%', borderRadius: 999, background: '#f87171', width: `${(s.boss.hp / s.boss.maxHp) * 100}%`, transition: 'width 150ms' }} />
            </div>
            <div style={{ fontSize: 11, color: '#fca5a5', marginTop: 2 }}>□ to strike</div>
          </div>
        )}
        {s?.canRoll && <div style={{ marginTop: 8, fontSize: 12, color: '#3DDC84', fontWeight: 800 }}>✕ ROLL</div>}
      </div>

      <button onClick={() => navigate(-1)} style={{ position: 'absolute', top: 14, right: 14, zIndex: 60, padding: '8px 14px', borderRadius: 10, cursor: 'pointer', background: 'rgba(15,18,26,0.85)', color: '#e2e8f0', border: '1px solid rgba(255,255,255,0.14)', fontSize: 13, fontWeight: 600 }}>✕ Exit</button>

      {status === 'loading' && <div style={overlayStyle}><div style={{ color: '#e2e8f0', fontSize: 18, fontWeight: 700 }}>SETTING THE BOARD…</div></div>}
      {status === 'error' && <div style={overlayStyle}><div style={{ color: '#f87171', fontSize: 16, fontWeight: 700 }}>Failed to start — check the console.</div></div>}
      {status === 'finished' && (
        <div style={overlayStyle}>
          <div style={{ display: 'grid', gap: 12, justifyItems: 'center' }}>
            <div style={{ color: '#F2C14E', fontSize: 34, fontWeight: 900 }}>STORY COMPLETE</div>
            <div style={{ color: '#fff', fontSize: 20, fontWeight: 700 }}>Venice is free · {s?.shards ?? 0} shards</div>
            <button onClick={startStory} style={{ padding: '12px 26px', borderRadius: 12, cursor: 'pointer', background: '#facc15', color: '#111827', border: 'none', fontSize: 15, fontWeight: 800 }}>NEW GAME+</button>
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
  background: 'rgba(8,6,14,0.78)', backdropFilter: 'blur(4px)',
};
