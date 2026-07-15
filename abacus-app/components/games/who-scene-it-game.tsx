'use client';

import { useEffect, useRef, useState } from 'react';
import type { GameProps } from '@/components/games/game-shell';
import { QUIZ_BANK, QUIZ_CATEGORIES, type QuizQuestion } from '@/lib/quiz-data';
import { SessionRecorder } from '@/lib/game-systems';

const TOTAL_Q = 15;
const Q_TIME = 8;
const WIN_SCORE = 1200;

interface RoundQ extends QuizQuestion {
  catLabel: string;
  catColor: string;
}

function buildDeck(): RoundQ[] {
  const deck: RoundQ[] = [];
  const cats = [...QUIZ_CATEGORIES];
  for (const cat of cats) {
    const qs = [...(QUIZ_BANK[cat.key] ?? [])].sort(() => Math.random() - 0.5).slice(0, 3);
    for (const q of qs) deck.push({ ...q, catLabel: cat.label, catColor: cat.color });
  }
  return deck.sort(() => Math.random() - 0.5).slice(0, TOTAL_Q);
}

export default function WhoSceneItGame({ grade, prq, onEnd, gamepad }: GameProps) {
  const [started, setStarted] = useState(false);
  const [deck, setDeck] = useState<RoundQ[]>([]);
  const [idx, setIdx] = useState(0);
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [timeLeft, setTimeLeft] = useState(Q_TIME);
  const [picked, setPicked] = useState<number | null>(null);
  const [feedback, setFeedback] = useState<'right' | 'wrong' | 'timeout' | null>(null);
  const endedRef = useRef(false);
  const onEndRef = useRef(onEnd);
  onEndRef.current = onEnd;
  const startRef = useRef(0);
  const scoreRef = useRef(0);
  scoreRef.current = score;
  const recRef = useRef(new SessionRecorder());

  const timeBonus = grade.key === 'ELITE' ? 2 : grade.key === 'PRIMED' ? 1 : 0;

  // keyboard shortcuts 1-4 to pick answer
  useEffect(() => {
    const kd = (e: KeyboardEvent) => {
      if (e.key >= '1' && e.key <= '4') { e.preventDefault(); pick(parseInt(e.key) - 1); }
    };
    window.addEventListener('keydown', kd);
    return () => window.removeEventListener('keydown', kd);
  });

  useEffect(() => {
    if (!started) return;
    setDeck(buildDeck());
    startRef.current = Date.now();
  }, [started]);

  // countdown
  useEffect(() => {
    if (!started || deck.length === 0 || picked !== null || feedback !== null || endedRef.current) return;
    if (timeLeft <= 0) {
      setFeedback('timeout');
      setStreak(0);
      recRef.current.recordMiss();
      return;
    }
    const t = setTimeout(() => setTimeLeft((v) => Math.round((v - 0.1) * 10) / 10), 100);
    return () => clearTimeout(t);
  }, [started, deck, timeLeft, picked, feedback]);

  // advance after feedback
  useEffect(() => {
    if (feedback === null || endedRef.current) return;
    const t = setTimeout(() => {
      if (idx + 1 >= deck.length) {
        endedRef.current = true;
        const finalScore = scoreRef.current;
        onEndRef.current?.({
          score: finalScore,
          won: finalScore >= WIN_SCORE,
          duration: Math.round((Date.now() - startRef.current) / 1000),
          headline: finalScore >= WIN_SCORE ? 'SCENE STEALER — CULTURE CHAMPION' : 'REWATCH THE CLASSICS',
          tallies: recRef.current.tallies(), maxCombo: recRef.current.bestChain,
        });
      } else {
        setIdx((v) => v + 1);
        setPicked(null);
        setFeedback(null);
        setTimeLeft(Q_TIME + timeBonus);
      }
    }, 1100);
    return () => clearTimeout(t);
  }, [feedback, idx, deck.length, timeBonus]);

  function pick(i: number) {
    if (picked !== null || feedback !== null || endedRef.current) return;
    setPicked(i);
    const q = deck[idx];
    if (i === q.answer) {
      const speedPts = Math.round(timeLeft * 8);
      const streakPts = streak >= 2 ? 20 : 0;
      setScore((s) => s + 60 + speedPts + streakPts);
      setStreak((s) => { const n = s + 1; recRef.current.recordHit(); recRef.current.recordChain(n); return n; });
      setFeedback('right');
    } else {
      setStreak(0);
      recRef.current.recordMiss();
      setFeedback('wrong');
    }
  }

  const q = deck[idx];

  return (
    <div className="relative w-full">
      <div className="relative w-full overflow-hidden rounded-xl border border-white/10 bg-[#0F0A1C] p-4 sm:p-6" style={{ minHeight: 420 }}>
        {!started ? (
          <div className="flex min-h-[380px] flex-col items-center justify-center gap-4 text-center">
            <h2 className="fel-heading text-4xl text-white">WHO SCENE IT</h2>
            <p className="max-w-md text-sm text-gray-300">
              Rapid-fire recall across every category — {TOTAL_Q} questions, {Q_TIME + timeBonus} seconds each. Answer fast for speed points, chain streaks for bonuses. Score {WIN_SCORE}+ to win.
            </p>
            <div className="mt-2 grid grid-cols-2 gap-x-6 gap-y-1 font-mono text-[11px] text-white/40">
              <span>1 / 2 / 3 / 4 — Pick answer</span>
              <span>Speed bonus: faster = more pts</span>
              <span>3+ streak = +20 bonus</span>
              <span>Tap options on mobile</span>
            </div>
            <button onClick={() => setStarted(true)} className="rounded-lg bg-[#A855F7] px-8 py-3 font-bold text-white transition hover:bg-[#9333ea]">ROLL THE SCENE</button>
          </div>
        ) : !q ? (
          <div className="flex min-h-[380px] items-center justify-center text-white/60">Shuffling the reel…</div>
        ) : (
          <div className="mx-auto max-w-2xl">
            <div className="flex items-center justify-between font-mono text-xs text-white/60">
              <span>Q{idx + 1}/{deck.length}</span>
              <span className="rounded px-2 py-0.5 font-bold" style={{ color: q.catColor, background: `${q.catColor}22` }}>{q.catLabel}</span>
              <span>SCORE {score} · STREAK x{streak}</span>
            </div>
            <div className="mt-3 h-2 w-full overflow-hidden rounded bg-white/10">
              <div
                className="h-full rounded transition-[width] duration-100"
                style={{ width: `${Math.max(0, (timeLeft / (Q_TIME + timeBonus)) * 100)}%`, background: timeLeft < 3 ? '#FF3366' : '#00E5FF' }}
              />
            </div>
            <h3 className="mt-6 min-h-[64px] text-center text-lg font-semibold text-white">{q.q}</h3>
            <div className="mt-5 grid gap-3 sm:grid-cols-2">
              {q.options.map((opt, i) => {
                let cls = 'border-white/15 bg-white/5 text-white hover:border-[#A855F7]/60 hover:bg-[#A855F7]/10';
                if (feedback !== null) {
                  if (i === q.answer) cls = 'border-[#00FF9D] bg-[#00FF9D]/15 text-[#00FF9D]';
                  else if (picked === i) cls = 'border-[#FF3366] bg-[#FF3366]/15 text-[#FF3366]';
                  else cls = 'border-white/10 bg-white/5 text-white/40';
                }
                return (
                  <button key={i} onClick={() => pick(i)} disabled={feedback !== null} className={`rounded-lg border px-4 py-3 text-sm font-medium transition ${cls}`}>
                    {opt}
                  </button>
                );
              })}
            </div>
            <div className="mt-4 min-h-[28px] text-center font-bold">
              {feedback === 'right' && <span className="text-[#00FF9D]">CORRECT! +{60 + Math.round(timeLeft * 8)}{streak >= 3 ? ' +streak' : ''}</span>}
              {feedback === 'wrong' && <span className="text-[#FF3366]">WRONG SCENE!</span>}
              {feedback === 'timeout' && <span className="text-[#FFD700]">TIME! MOVING ON…</span>}
            </div>
            <p className="text-center font-mono text-[10px] text-white/30">PRQ {prq.toFixed(0)} · {grade.label}</p>
          </div>
        )}
      </div>
    </div>
  );
}
