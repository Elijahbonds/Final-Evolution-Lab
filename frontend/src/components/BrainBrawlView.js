/**
 * BrainBrawlView — demo-quality Brain Brawl trivia experience (nexus/brainbrawl-demo).
 *
 * Screens: Quick Play (Blitz / Deep Dive) -> Match (question card, timer ring,
 * thumb-friendly answers, streak + score roll-up, post-answer micro-lesson
 * overlay with a Creator Card "Save lesson" seam) -> Results (replay export).
 *
 * Authority modes:
 *   server (default)  — questions fetched server-side only; answers are never
 *                       in the client until the server resolves the question.
 *   recording (local) — ?recording=1 or REACT_APP_RECORDING_LOCAL=1: fetches a
 *                       full pack once (server gated by RECORDING_LOCAL=1) and
 *                       runs the round locally for a jitter-free screen
 *                       recording. Seed is shown in the UI in both modes.
 *
 * Unified-input seam (keyboard mapping, mirrors future controller map):
 *   1-9    -> select / toggle answer option
 *   Space  -> "buzz": start round, submit multi-select, dismiss overlay
 *   Enter  -> same as Space
 * Touch targets are >= 64px tall (thumb-friendly).
 */
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { API_URL, getStoredUserId } from '@/lib/apiClient';
import { scoreAnswer } from '@/lib/brainbrawlScoring';
import { saveLesson } from '@/lib/creatorCardSeam';

const T = {
  bg: '#08090b',
  panel: '#0d1018',
  panelBorder: 'rgba(0,229,255,0.15)',
  text: '#e8eaf0',
  dim: '#6b7280',
  soft: '#9ca3af',
  accent: '#00e5ff',
  gold: '#ffd700',
  green: '#34d399',
  red: '#f87171',
  purple: '#c084fc',
};

const styles = {
  container: {
    background: T.bg, color: T.text, minHeight: '100vh',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
    padding: '24px', display: 'flex', flexDirection: 'column', alignItems: 'center',
  },
  inner: { width: '100%', maxWidth: '760px' },
  card: {
    background: T.panel, border: `1px solid ${T.panelBorder}`,
    borderRadius: '20px', padding: '24px',
  },
  label: {
    fontSize: '0.72rem', textTransform: 'uppercase', letterSpacing: '0.12em',
    color: T.dim, fontWeight: 700,
  },
  chip: (color) => ({
    padding: '4px 12px', borderRadius: '20px', fontSize: '0.72rem', fontWeight: 700,
    letterSpacing: '0.08em', textTransform: 'uppercase',
    background: `${color}1f`, color, border: `1px solid ${color}44`,
  }),
  btn: {
    padding: '12px 26px', borderRadius: '12px', border: 'none', fontWeight: 800,
    cursor: 'pointer', fontSize: '0.95rem',
  },
};

// ── Timer ring ──────────────────────────────────────────────────────────────

function TimerRing({ remainingMs, timeLimitMs }) {
  const r = 44;
  const circ = 2 * Math.PI * r;
  const frac = Math.max(0, Math.min(1, remainingMs / timeLimitMs));
  const color = frac > 0.5 ? T.accent : frac > 0.2 ? T.gold : T.red;
  const secs = Math.ceil(remainingMs / 1000);
  return (
    <div style={{ position: 'relative', width: 104, height: 104, flexShrink: 0 }}
      data-testid="bb-timer-ring">
      <svg width="104" height="104" style={{ transform: 'rotate(-90deg)' }}>
        <circle cx="52" cy="52" r={r} fill="none" stroke="rgba(255,255,255,0.07)" strokeWidth="7" />
        <circle
          cx="52" cy="52" r={r} fill="none" stroke={color} strokeWidth="7"
          strokeLinecap="round" strokeDasharray={circ}
          strokeDashoffset={circ * (1 - frac)}
          style={{ transition: 'stroke-dashoffset 0.1s linear, stroke 0.4s' }}
        />
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', alignItems: 'center',
        justifyContent: 'center', fontSize: '1.9rem', fontWeight: 800, color,
        animation: frac <= 0.2 && remainingMs > 0 ? 'bbPulse 0.5s infinite' : 'none',
      }}>
        {secs}
      </div>
    </div>
  );
}

// ── Score roll-up ───────────────────────────────────────────────────────────

function RollUpScore({ value }) {
  const [display, setDisplay] = useState(value);
  const fromRef = useRef(value);
  useEffect(() => {
    const from = fromRef.current;
    if (from === value) return undefined;
    const start = performance.now();
    const dur = 650;
    let raf;
    const tick = (now) => {
      const p = Math.min(1, (now - start) / dur);
      const eased = 1 - Math.pow(1 - p, 3);
      setDisplay(Math.round(from + (value - from) * eased));
      if (p < 1) raf = requestAnimationFrame(tick);
      else fromRef.current = value;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value]);
  return (
    <span style={{ fontSize: '2.2rem', fontWeight: 800, color: T.accent, fontVariantNumeric: 'tabular-nums' }}
      data-testid="bb-score">
      {display}
    </span>
  );
}

// ── Answer button ───────────────────────────────────────────────────────────

function AnswerButton({ option, index, state, multi, selected, onPress, disabled }) {
  // state: 'idle' | 'selected' | 'correct' | 'wrong' | 'missed'
  const palette = {
    idle: { bg: 'rgba(255,255,255,0.03)', border: 'rgba(255,255,255,0.12)', color: T.text },
    selected: { bg: 'rgba(0,229,255,0.12)', border: T.accent, color: T.accent },
    correct: { bg: 'rgba(52,211,153,0.15)', border: T.green, color: T.green },
    wrong: { bg: 'rgba(248,113,113,0.13)', border: T.red, color: T.red },
    missed: { bg: 'rgba(52,211,153,0.06)', border: 'rgba(52,211,153,0.45)', color: T.green },
  }[state];
  return (
    <button
      onClick={() => !disabled && onPress(index)}
      data-testid={`bb-answer-${index}`}
      style={{
        display: 'flex', alignItems: 'center', gap: '14px', width: '100%',
        minHeight: '64px', padding: '14px 18px', borderRadius: '14px',
        background: palette.bg, border: `1.5px solid ${palette.border}`,
        color: palette.color, fontSize: '1.02rem', fontWeight: 600, textAlign: 'left',
        cursor: disabled ? 'default' : 'pointer',
        transition: 'background 0.15s, border-color 0.15s, transform 0.1s',
        animation: state === 'correct' ? 'bbCorrect 0.45s' : state === 'wrong' ? 'bbShake 0.4s' : 'none',
      }}
    >
      <span style={{
        width: 30, height: 30, borderRadius: 8, flexShrink: 0, display: 'flex',
        alignItems: 'center', justifyContent: 'center', fontSize: '0.85rem', fontWeight: 800,
        background: 'rgba(255,255,255,0.06)', color: palette.color,
        border: `1px solid ${palette.border}`,
      }}>
        {multi && selected ? '✓' : index + 1}
      </span>
      {option}
    </button>
  );
}

// ── Micro-lesson overlay ────────────────────────────────────────────────────

function LessonOverlay({ result, question, onContinue, finished }) {
  const [saveState, setSaveState] = useState('idle'); // idle | saving | saved
  const lesson = result.micro_lesson;
  const handleSave = async () => {
    setSaveState('saving');
    await saveLesson({
      questionId: question.id,
      prompt: question.prompt,
      explanation: result.explanation,
      microLesson: lesson,
      taxonomy: question.taxonomy,
    });
    setSaveState('saved');
  };
  return (
    <div style={{
      position: 'fixed', inset: 0, background: 'rgba(4,5,7,0.82)', zIndex: 40,
      display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
      backdropFilter: 'blur(4px)',
    }} data-testid="bb-lesson-overlay">
      <div style={{
        ...styles.card, maxWidth: 720, width: 'calc(100% - 32px)', margin: '0 16px 24px',
        border: `1px solid ${result.full_correct ? 'rgba(52,211,153,0.35)' : 'rgba(248,113,113,0.3)'}`,
        animation: 'bbSlideUp 0.3s ease-out',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
          <span style={styles.chip(result.full_correct ? T.green : T.red)}>
            {result.full_correct ? 'Correct' : result.points > 0 ? 'Partial credit' : 'Missed'}
          </span>
          <span style={{ color: T.gold, fontWeight: 800 }}>+{result.points} pts</span>
          {result.streak > 1 && (
            <span style={styles.chip(T.gold)}>streak x{result.streak}</span>
          )}
        </div>
        {result.explanation && (
          <p style={{ color: T.soft, lineHeight: 1.55, margin: '0 0 14px' }}>{result.explanation}</p>
        )}
        {lesson && (
          <div style={{
            background: 'rgba(192,132,252,0.07)', border: '1px solid rgba(192,132,252,0.25)',
            borderRadius: 14, padding: '16px 18px', marginBottom: 16,
          }}>
            <div style={{ ...styles.label, color: T.purple, marginBottom: 6 }}>Micro-lesson · {lesson.title}</div>
            <p style={{ color: T.text, lineHeight: 1.55, margin: '0 0 10px', fontSize: '0.94rem' }}>{lesson.body}</p>
            <div style={{ color: T.purple, fontWeight: 700, fontSize: '0.9rem' }}>→ {lesson.takeaway}</div>
          </div>
        )}
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {(lesson || result.explanation) && (
            <button
              style={{
                ...styles.btn, background: 'rgba(192,132,252,0.14)', color: T.purple,
                border: '1px solid rgba(192,132,252,0.35)',
              }}
              onClick={handleSave}
              disabled={saveState !== 'idle'}
              data-testid="bb-save-lesson"
            >
              {saveState === 'saved' ? 'Saved to Creator Cards ✓' : saveState === 'saving' ? 'Saving…' : 'Save lesson'}
            </button>
          )}
          <button
            style={{ ...styles.btn, background: T.accent, color: T.bg, marginLeft: 'auto' }}
            onClick={onContinue}
            data-testid="bb-continue"
          >
            {finished ? 'See results' : 'Next question'} <span style={{ opacity: 0.6 }}>(Space)</span>
          </button>
        </div>
      </div>
    </div>
  );
}

// ── Main view ───────────────────────────────────────────────────────────────

const PHASE = { QUICKPLAY: 'quickplay', QUESTION: 'question', RESOLVED: 'resolved', RESULTS: 'results' };

export default function BrainBrawlView({ onExit }) {
  const recordingMode = useMemo(() => {
    const params = new URLSearchParams(window.location.search);
    return params.get('recording') === '1' || process.env.REACT_APP_RECORDING_LOCAL === '1';
  }, []);
  const urlSeed = useMemo(() => {
    const s = new URLSearchParams(window.location.search).get('seed');
    return s ? Number(s) : null;
  }, []);

  const [phase, setPhase] = useState(PHASE.QUICKPLAY);
  const [mode, setMode] = useState('blitz');
  const [error, setError] = useState(null);
  const [round, setRound] = useState(null);       // {round_id?, seed, time_limit_ms, question_count}
  const [question, setQuestion] = useState(null); // public question payload
  const [selected, setSelected] = useState([]);
  const [result, setResult] = useState(null);     // last answer result (post-resolution)
  const [score, setScore] = useState(0);
  const [streak, setStreak] = useState(0);
  const [bestStreak, setBestStreak] = useState(0);
  const [correctCount, setCorrectCount] = useState(0);
  const [remainingMs, setRemainingMs] = useState(0);
  const [answeredCount, setAnsweredCount] = useState(0);

  // Recording-mode local state
  const packRef = useRef(null);          // full question pack (answers included)
  const localEventsRef = useRef([]);     // locally built replay events
  const localStreakRef = useRef(0);
  const localNormMsRef = useRef(0);

  const issuedAtRef = useRef(0);
  const latencyRef = useRef(0);          // measured request RTT/2 estimate
  const timerRef = useRef(null);
  const submittingRef = useRef(false);
  const playerId = useMemo(() => getStoredUserId(), []);

  const stopTimer = () => { if (timerRef.current) { clearInterval(timerRef.current); timerRef.current = null; } };

  const beginQuestion = useCallback((q, timeLimitMs) => {
    setQuestion(q);
    setSelected([]);
    setResult(null);
    setRemainingMs(timeLimitMs);
    issuedAtRef.current = performance.now();
    setPhase(PHASE.QUESTION);
  }, []);

  // Countdown driver
  useEffect(() => {
    if (phase !== PHASE.QUESTION || !round) return undefined;
    stopTimer();
    timerRef.current = setInterval(() => {
      const elapsed = performance.now() - issuedAtRef.current;
      const rem = Math.max(0, round.time_limit_ms - elapsed);
      setRemainingMs(rem);
      if (rem <= 0) {
        stopTimer();
        submitAnswer([], true); // timeout -> empty answer, server clamps timing
      }
    }, 80);
    return stopTimer;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase, question, round]);

  // ── Round lifecycle ──────────────────────────────────────────────────────

  const startRound = useCallback(async (chosenMode) => {
    setError(null);
    setScore(0); setStreak(0); setBestStreak(0); setCorrectCount(0); setAnsweredCount(0);
    localEventsRef.current = []; localStreakRef.current = 0; localNormMsRef.current = 0;
    setMode(chosenMode);
    const t0 = performance.now();
    try {
      if (recordingMode) {
        const qp = new URLSearchParams({ mode: chosenMode });
        if (urlSeed != null) qp.set('seed', String(urlSeed));
        const r = await fetch(`${API_URL}/brainbrawl/recording-pack?${qp}`, { credentials: 'include' });
        if (!r.ok) throw new Error(r.status === 403
          ? 'Recording mode needs RECORDING_LOCAL=1 on the server.'
          : await r.text());
        const pack = await r.json();
        packRef.current = pack;
        latencyRef.current = 0; // local-authoritative: no latency to normalize
        setRound({
          seed: pack.seed, time_limit_ms: pack.time_limit_ms,
          question_count: pack.questions.length, mode_id: pack.mode_id,
          content_hash: pack.content_hash, local: true,
        });
        localEventsRef.current.push({
          type: 'round_start', seq: 0, mode: chosenMode, mode_id: pack.mode_id,
          seed: pack.seed, content_hash: pack.content_hash,
          time_limit_ms: pack.time_limit_ms, question_count: pack.questions.length,
          player_id: playerId, timestamp: new Date().toISOString(),
        });
        const q0 = pack.questions[0];
        localEventsRef.current.push({
          type: 'question_presented', seq: 1, index: 0, question_id: q0.id,
          player_id: playerId, timestamp: new Date().toISOString(),
        });
        beginQuestion({ ...stripLocal(q0), index: 0 }, pack.time_limit_ms);
      } else {
        const r = await fetch(`${API_URL}/brainbrawl/rounds/start`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({
            mode: chosenMode, player_id: playerId,
            ...(urlSeed != null ? { seed: urlSeed } : {}),
          }),
        });
        if (!r.ok) throw new Error(await r.text());
        const data = await r.json();
        latencyRef.current = Math.round((performance.now() - t0) / 2);
        setRound({
          round_id: data.round_id, seed: data.seed, time_limit_ms: data.time_limit_ms,
          question_count: data.question_count, mode_id: data.mode_id, local: false,
        });
        beginQuestion(data.question, data.time_limit_ms);
      }
    } catch (err) {
      setError(String(err.message || err));
    }
  }, [recordingMode, urlSeed, playerId, beginQuestion]);

  const stripLocal = (q) => {
    const { answer, explanation, micro_lesson, ...pub } = q; // eslint-disable-line no-unused-vars
    return pub;
  };

  const finishLocalRound = () => {
    const seq = localEventsRef.current.length;
    localEventsRef.current.push({
      type: 'round_end', seq,
      score: { [playerId]: scoreRefValue.current },
      total_normalized_ms: { [playerId]: localNormMsRef.current },
      tie_break_rule: 'latency_normalized_time',
      timestamp: new Date().toISOString(),
    });
  };

  // keep an always-current score for local round_end construction
  const scoreRefValue = useRef(0);
  useEffect(() => { scoreRefValue.current = score; }, [score]);

  const submitAnswer = useCallback(async (sel, timedOut = false) => {
    if (submittingRef.current || phase !== PHASE.QUESTION || !round || !question) return;
    submittingRef.current = true;
    stopTimer();
    const responseMs = Math.min(
      Math.round(performance.now() - issuedAtRef.current), round.time_limit_ms);
    try {
      let payload;
      if (round.local) {
        // Locally-authoritative grade (recording mode) — mirrors server math.
        const pack = packRef.current;
        const fullQ = pack.questions[question.index];
        const res = scoreAnswer(fullQ, sel, responseMs, 0, round.time_limit_ms, localStreakRef.current);
        localStreakRef.current = res.streakAfter;
        localNormMsRef.current += res.normalizedMs;
        const newScore = scoreRefValue.current + res.points;
        const inputs = {
          selected: res.selected, client_ts: Date.now() / 1000,
          response_ms: responseMs, claimed_response_ms: responseMs, latency_ms: 0,
        };
        const seqBase = localEventsRef.current.length;
        localEventsRef.current.push(
          { type: 'answer_submitted', seq: seqBase, index: question.index, question_id: fullQ.id, player_id: playerId, inputs, timestamp: new Date().toISOString() },
          {
            type: 'answer_result', seq: seqBase + 1, index: question.index, question_id: fullQ.id,
            player_id: playerId, inputs, points: res.points, raw_points: res.rawPoints,
            streak_bonus: res.streakBonus, full_correct: res.fullCorrect,
            credit: [res.creditNumerator, res.creditDenominator],
            streak_after: res.streakAfter, score_snapshot: { [playerId]: newScore },
            timestamp: new Date().toISOString(),
          },
        );
        const isLast = question.index + 1 >= pack.questions.length;
        payload = {
          status: isLast ? 'finished' : 'active',
          score: newScore,
          result: {
            full_correct: res.fullCorrect, points: res.points, streak: res.streakAfter,
            correct_answer: res.correctAnswer, explanation: fullQ.explanation || null,
            micro_lesson: fullQ.micro_lesson || null,
          },
          next_question: isLast ? null : { ...stripLocal(pack.questions[question.index + 1]), index: question.index + 1, time_limit_ms: round.time_limit_ms },
        };
        if (!isLast) {
          localEventsRef.current.push({
            type: 'question_presented', seq: localEventsRef.current.length,
            index: question.index + 1, question_id: pack.questions[question.index + 1].id,
            player_id: playerId, timestamp: new Date().toISOString(),
          });
        }
      } else {
        const r = await fetch(`${API_URL}/brainbrawl/rounds/${round.round_id}/answer`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({
            question_index: question.index,
            selected: sel,
            client_ts: Date.now() / 1000,
            response_ms: responseMs,
            latency_ms: latencyRef.current,
          }),
        });
        if (!r.ok) throw new Error(await r.text());
        payload = await r.json();
      }

      setSelected(sel);
      setResult({ ...payload.result, nextQuestion: payload.next_question, finished: payload.status === 'finished' });
      setScore(payload.score);
      setStreak(payload.result.streak);
      setBestStreak((b) => Math.max(b, payload.result.streak));
      if (payload.result.full_correct) setCorrectCount((c) => c + 1);
      setAnsweredCount((c) => c + 1);
      if (round.local && payload.status === 'finished') {
        scoreRefValue.current = payload.score;
        finishLocalRound();
      }
      setPhase(PHASE.RESOLVED);
      if (timedOut && !payload.result.explanation && !payload.result.micro_lesson) {
        // brief flash then auto-advance on timeouts with nothing to read
        setTimeout(() => continueAfterResult(payload), 900);
      }
    } catch (err) {
      setError(String(err.message || err));
    } finally {
      submittingRef.current = false;
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [phase, round, question, playerId]);

  const continueAfterResult = useCallback((payloadOverride) => {
    const res = payloadOverride
      ? { nextQuestion: payloadOverride.next_question, finished: payloadOverride.status === 'finished' }
      : result;
    if (!res) return;
    if (res.finished || !res.nextQuestion) setPhase(PHASE.RESULTS);
    else beginQuestion(res.nextQuestion, round.time_limit_ms);
  }, [result, round, beginQuestion]);

  const downloadReplay = async () => {
    try {
      let data;
      if (round.local) {
        data = {
          metadata: {
            match_id: `local_${round.seed}`, mode_id: round.mode_id, brainbrawl_mode: mode,
            seed: round.seed, judge_offsets: [], category: null,
            content_hash: round.content_hash, time_limit_ms: round.time_limit_ms,
            question_count: round.question_count, players: [playerId],
            status: 'finished', export_version: '1.1', recording_local: true,
            event_count: localEventsRef.current.length,
          },
          events: localEventsRef.current,
        };
      } else {
        const r = await fetch(`${API_URL}/brainbrawl/rounds/${round.round_id}/export-replay`, { credentials: 'include' });
        if (!r.ok) throw new Error(await r.text());
        data = await r.json();
      }
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `brainbrawl_replay_${round.seed}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(`Replay export failed: ${String(err.message || err)}`);
    }
  };

  // ── Unified input seam: keyboard (1-9 answers, Space/Enter buzz) ─────────
  useEffect(() => {
    const onKey = (e) => {
      if (e.repeat) return;
      const buzz = e.key === ' ' || e.key === 'Enter';
      if (phase === PHASE.QUICKPLAY) {
        if (e.key === '1') setMode('blitz');
        else if (e.key === '2') setMode('deep_dive');
        else if (buzz) { e.preventDefault(); startRound(mode); }
      } else if (phase === PHASE.QUESTION && question) {
        const n = parseInt(e.key, 10);
        if (n >= 1 && n <= question.options.length) {
          const idx = n - 1;
          if (question.type === 'multi') {
            setSelected((s) => (s.includes(idx) ? s.filter((x) => x !== idx) : [...s, idx]));
          } else {
            submitAnswer([idx]);
          }
        } else if (buzz && question.type === 'multi') {
          e.preventDefault();
          submitAnswer(selected);
        }
      } else if (phase === PHASE.RESOLVED && buzz) {
        e.preventDefault();
        continueAfterResult();
      } else if (phase === PHASE.RESULTS && buzz) {
        e.preventDefault();
        setPhase(PHASE.QUICKPLAY);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [phase, question, selected, mode, startRound, submitAnswer, continueAfterResult]);

  // ── Renders ──────────────────────────────────────────────────────────────

  const seedChip = round && (
    <span style={{ ...styles.chip(round.local ? T.gold : T.accent), fontFamily: 'monospace', textTransform: 'none' }}
      data-testid="bb-seed">
      {round.local ? 'LOCAL · ' : ''}seed {String(round.seed)}
    </span>
  );

  const header = (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20, gap: 12, flexWrap: 'wrap' }}>
      <h1 style={{ fontSize: '1.35rem', fontWeight: 800, color: T.accent, margin: 0, letterSpacing: '0.02em' }}>
        BRAIN BRAWL
      </h1>
      <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap' }}>
        {recordingMode && <span style={styles.chip(T.gold)}>recording</span>}
        {seedChip}
        {onExit && (
          <button style={{ ...styles.btn, padding: '8px 16px', background: '#1f2937', color: T.soft }} onClick={onExit}>
            Exit
          </button>
        )}
      </div>
    </div>
  );

  const answerState = (idx) => {
    if (phase === PHASE.RESOLVED && result) {
      const correct = result.correct_answer || [];
      if (correct.includes(idx)) return selected.includes(idx) ? 'correct' : 'missed';
      if (selected.includes(idx)) return 'wrong';
      return 'idle';
    }
    return selected.includes(idx) ? 'selected' : 'idle';
  };

  return (
    <div style={styles.container}>
      <style>{`
        @keyframes bbPulse { 50% { transform: scale(1.12); } }
        @keyframes bbCorrect { 0% { transform: scale(1); } 35% { transform: scale(1.035); } 100% { transform: scale(1); } }
        @keyframes bbShake { 0%,100% { transform: translateX(0); } 25% { transform: translateX(-7px); } 55% { transform: translateX(6px); } 80% { transform: translateX(-3px); } }
        @keyframes bbSlideUp { from { transform: translateY(24px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        @keyframes bbFadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
      `}</style>
      <div style={styles.inner}>
        {header}

        {error && (
          <div style={{
            background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.3)',
            borderRadius: 10, padding: '12px 16px', marginBottom: 16, color: T.red,
          }} data-testid="bb-error">
            {error}
          </div>
        )}

        {phase === PHASE.QUICKPLAY && (
          <div style={{ animation: 'bbFadeIn 0.25s ease-out' }}>
            <div style={{ ...styles.label, marginBottom: 12 }}>Quick Play — choose your round</div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 16 }}>
              {[{
                id: 'blitz', title: 'Blitz', tag: '10s per question',
                desc: 'Speed + accuracy scoring. Streak bonuses stack up to +50%. Ten questions, no mercy.',
                accent: T.accent,
              }, {
                id: 'deep_dive', title: 'Deep Dive', tag: '45s · one question',
                desc: 'One explainable question. Take your time — then collect the micro-lesson.',
                accent: T.purple,
              }].map((m, i) => (
                <button
                  key={m.id}
                  data-testid={`bb-mode-${m.id}`}
                  onClick={() => { setMode(m.id); startRound(m.id); }}
                  style={{
                    ...styles.card, cursor: 'pointer', textAlign: 'left',
                    border: `1.5px solid ${mode === m.id ? m.accent : T.panelBorder}`,
                    outline: 'none',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                    <span style={{ fontSize: '1.25rem', fontWeight: 800, color: m.accent }}>{m.title}</span>
                    <span style={styles.chip(m.accent)}>{m.tag}</span>
                  </div>
                  <p style={{ color: T.soft, lineHeight: 1.5, margin: 0, fontSize: '0.92rem' }}>{m.desc}</p>
                  <div style={{ ...styles.label, marginTop: 14 }}>press {i + 1} then space · or tap</div>
                </button>
              ))}
            </div>
          </div>
        )}

        {(phase === PHASE.QUESTION || phase === PHASE.RESOLVED) && question && round && (
          <div style={{ animation: 'bbFadeIn 0.2s ease-out' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, gap: 16 }}>
              <div>
                <div style={styles.label}>Question {question.index + 1} / {round.question_count}</div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 12 }}>
                  <RollUpScore value={score} />
                  {streak > 1 && <span style={styles.chip(T.gold)} data-testid="bb-streak">🔥 x{streak}</span>}
                </div>
              </div>
              <TimerRing remainingMs={phase === PHASE.QUESTION ? remainingMs : 0} timeLimitMs={round.time_limit_ms} />
            </div>

            <div style={{ ...styles.card, marginBottom: 16 }} data-testid="bb-question-card">
              <div style={{ display: 'flex', gap: 8, marginBottom: 12, flexWrap: 'wrap' }}>
                <span style={styles.chip(T.accent)}>{question.taxonomy?.category?.replace(/_/g, ' ')}</span>
                <span style={styles.chip(question.difficulty === 'hard' ? T.red : question.difficulty === 'medium' ? T.gold : T.green)}>
                  {question.difficulty}
                </span>
                {question.type === 'multi' && <span style={styles.chip(T.purple)}>select all that apply</span>}
              </div>
              <div style={{ fontSize: '1.45rem', fontWeight: 700, lineHeight: 1.35 }}>
                {question.prompt}
              </div>
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 12 }}>
              {question.options.map((opt, i) => (
                <AnswerButton
                  key={i} option={opt} index={i} multi={question.type === 'multi'}
                  selected={selected.includes(i)}
                  state={answerState(i)}
                  disabled={phase !== PHASE.QUESTION}
                  onPress={(idx) => {
                    if (question.type === 'multi') {
                      setSelected((s) => (s.includes(idx) ? s.filter((x) => x !== idx) : [...s, idx]));
                    } else {
                      submitAnswer([idx]);
                    }
                  }}
                />
              ))}
            </div>

            {question.type === 'multi' && phase === PHASE.QUESTION && (
              <button
                style={{ ...styles.btn, marginTop: 16, width: '100%', minHeight: 56, background: T.accent, color: T.bg }}
                onClick={() => submitAnswer(selected)}
                data-testid="bb-submit-multi"
              >
                Lock in {selected.length} answer{selected.length === 1 ? '' : 's'} (Space)
              </button>
            )}

            {phase === PHASE.RESOLVED && result && (result.explanation || result.micro_lesson) && (
              <LessonOverlay
                result={result} question={question}
                finished={result.finished}
                onContinue={() => continueAfterResult()}
              />
            )}
            {phase === PHASE.RESOLVED && result && !result.explanation && !result.micro_lesson && (
              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 16 }}>
                <button style={{ ...styles.btn, background: T.accent, color: T.bg }}
                  onClick={() => continueAfterResult()} data-testid="bb-continue-plain">
                  {result.finished ? 'See results' : 'Next question'} <span style={{ opacity: 0.6 }}>(Space)</span>
                </button>
              </div>
            )}
          </div>
        )}

        {phase === PHASE.RESULTS && round && (
          <div style={{ ...styles.card, textAlign: 'center', animation: 'bbFadeIn 0.3s ease-out' }} data-testid="bb-results">
            <div style={styles.label}>Round complete · {mode === 'blitz' ? 'Blitz' : 'Deep Dive'}</div>
            <div style={{ fontSize: '3.4rem', fontWeight: 800, color: T.accent, margin: '10px 0' }}>{score}</div>
            <div style={{ display: 'flex', justifyContent: 'center', gap: 24, marginBottom: 20, color: T.soft }}>
              <span>{correctCount}/{answeredCount} correct</span>
              <span style={{ color: T.gold }}>best streak x{Math.max(bestStreak, 1)}</span>
            </div>
            <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
              <button style={{ ...styles.btn, background: T.accent, color: T.bg }}
                onClick={() => setPhase(PHASE.QUICKPLAY)} data-testid="bb-play-again">
                Play again (Space)
              </button>
              <button
                style={{ ...styles.btn, background: 'rgba(255,215,0,0.12)', color: T.gold, border: '1px solid rgba(255,215,0,0.3)' }}
                onClick={downloadReplay} data-testid="bb-download-replay"
              >
                Download replay JSON
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
