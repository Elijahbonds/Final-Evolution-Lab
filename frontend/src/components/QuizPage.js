import React, { useEffect, useRef, useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import QuizCore from '@/game/systems/QuizCore.js';
import { SensoryBus } from '@/game/systems/SensoryBus.js';

/**
 * Shared quiz surface (rhythm/UI archetype — pure UI, no 3D scene).
 * Brain Brawl and Who-Scene-It are banks + flavor on this one component.
 */
export default function QuizPage({ title, subtitle, bank, accent = '#a78bfa' }) {
  const navigate = useNavigate();
  const quizRef = useRef(null);
  const busRef = useRef(null);
  const [view, setView] = useState(null); // {q, options, index, total}
  const [remaining, setRemaining] = useState(0);
  const [flash, setFlash] = useState(null); // {kind, correctIndex, earned}
  const [done, setDone] = useState(null);

  const startRound = useCallback(() => {
    const quiz = new QuizCore({ questions: bank });
    quizRef.current = quiz;
    if (typeof window !== 'undefined') window.__felQuiz = quiz; // dev/test seam
    setDone(null);
    setFlash(null);
    const q = quiz.next();
    setView({ ...q, index: quiz.index + 1, total: bank.length });
  }, [bank]);

  useEffect(() => {
    busRef.current = new SensoryBus({
      sfx: {
        impact: '/audio/sfx_punch_impact.mp3',
        swoosh: '/audio/sfx_basketball_swoosh.mp3',
        crowd:  '/audio/sfx_crowd_cheer.mp3',
      },
    });
    startRound();
    return () => busRef.current?.dispose();
  }, [startRound]);

  // countdown + timeout
  useEffect(() => {
    const t = setInterval(() => {
      const quiz = quizRef.current;
      if (!quiz || quiz.finished || !quiz.current) return;
      const ms = quiz.remainingMs();
      setRemaining(ms);
      if (ms <= 0 && !flash) {
        const r = quiz.timeout();
        setFlash({ kind: 'timeout', correctIndex: r.correctIndex });
        busRef.current?.emit({ sfx: 'impact', volume: 0.5 });
        setTimeout(() => advance(), 1100);
      }
    }, 100);
    return () => clearInterval(t);
  });

  const advance = () => {
    const quiz = quizRef.current;
    setFlash(null);
    const q = quiz.next();
    if (!q) {
      setDone({ score: quiz.score, ...quiz.stats });
      busRef.current?.emit({ sfx: 'crowd', volume: 0.6 });
      return;
    }
    setView({ ...q, index: quiz.index + 1, total: bank.length });
  };

  const pick = (i) => {
    const quiz = quizRef.current;
    if (!quiz?.current || flash) return;
    const r = quiz.answer(i);
    if (r.result === 'correct') {
      setFlash({ kind: 'correct', correctIndex: r.correctIndex, earned: r.earned, picked: i });
      busRef.current?.emit({ sfx: 'swoosh', volume: 0.6 });
    } else {
      setFlash({ kind: 'wrong', correctIndex: r.correctIndex, picked: i });
      busRef.current?.emit({ sfx: 'impact', volume: 0.6 });
    }
    setTimeout(() => advance(), 950);
  };

  const quiz = quizRef.current;

  return (
    <div style={pageStyle}>
      <header style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 18 }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 26, fontWeight: 900, letterSpacing: '0.04em' }}>{title}</h1>
          <div style={{ color: '#94a3b8', fontSize: 13 }}>{subtitle}</div>
        </div>
        <button onClick={() => navigate(-1)} style={btnGhost}>✕ Exit</button>
      </header>

      {!done && view && (
        <div style={{ maxWidth: 640, margin: '0 auto' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', color: '#94a3b8', fontSize: 12, marginBottom: 8 }}>
            <span>Q {view.index}/{view.total} · streak ×{quiz ? quiz.multiplier.toFixed(2) : '1.00'}</span>
            <span style={{ color: remaining < 3000 ? '#f87171' : '#e2e8f0', fontWeight: 800 }}>
              {(remaining / 1000).toFixed(1)}s
            </span>
          </div>
          <div style={{ height: 6, borderRadius: 999, background: 'rgba(255,255,255,0.08)', marginBottom: 16 }}>
            <div style={{
              height: '100%', borderRadius: 999, background: accent,
              width: `${quiz ? (remaining / quiz.questionTimeMs) * 100 : 0}%`,
              transition: 'width 100ms linear',
            }} />
          </div>
          <div style={{ ...cardStyle, fontSize: 19, fontWeight: 700, marginBottom: 14 }}>{view.q}</div>
          <div style={{ display: 'grid', gap: 10 }}>
            {view.options.map((opt, i) => {
              let bg = 'rgba(255,255,255,0.05)';
              if (flash) {
                if (i === flash.correctIndex) bg = 'rgba(52,211,153,0.25)';
                else if (i === flash.picked) bg = 'rgba(248,113,113,0.25)';
              }
              return (
                <button key={i} onClick={() => pick(i)} style={{ ...optionStyle, background: bg }}>
                  {opt}
                </button>
              );
            })}
          </div>
          <div style={{ marginTop: 12, fontSize: 22, fontWeight: 900, color: accent, minHeight: 30 }}>
            {flash?.kind === 'correct' && `+${flash.earned}`}
            {flash?.kind === 'wrong' && 'WRONG'}
            {flash?.kind === 'timeout' && 'TIME!'}
          </div>
          <div style={{ color: '#e2e8f0', fontWeight: 800 }}>Score {quiz?.score ?? 0}</div>
        </div>
      )}

      {done && (
        <div style={{ ...cardStyle, maxWidth: 480, margin: '40px auto', textAlign: 'center', display: 'grid', gap: 12 }}>
          <div style={{ fontSize: 30, fontWeight: 900, color: accent }}>ROUND COMPLETE</div>
          <div style={{ fontSize: 44, fontWeight: 900 }}>{done.score}</div>
          <div style={{ color: '#94a3b8', fontSize: 13 }}>
            {done.correct} correct · {done.wrong} wrong · {done.timeout} timed out
          </div>
          <button onClick={startRound} style={btnPrimary}>PLAY AGAIN</button>
        </div>
      )}
    </div>
  );
}

const pageStyle = {
  minHeight: '100vh', background: '#070510', color: '#f8fafc',
  padding: '24px clamp(14px, 5vw, 48px)',
  fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
};
const cardStyle = {
  background: 'rgba(14,12,24,0.92)', border: '1px solid rgba(255,255,255,0.09)',
  borderRadius: 16, padding: 18,
};
const optionStyle = {
  padding: '14px 16px', borderRadius: 12, cursor: 'pointer', textAlign: 'left',
  color: '#f8fafc', fontSize: 15, fontWeight: 600,
  border: '1px solid rgba(255,255,255,0.12)',
};
const btnPrimary = {
  padding: '12px 26px', borderRadius: 12, cursor: 'pointer',
  background: '#facc15', color: '#111827', border: 'none',
  fontSize: 15, fontWeight: 800, letterSpacing: '0.04em',
};
const btnGhost = {
  padding: '8px 14px', borderRadius: 10, cursor: 'pointer', fontSize: 13,
  background: 'rgba(255,255,255,0.06)', color: '#e2e8f0', border: '1px solid rgba(255,255,255,0.14)',
};
