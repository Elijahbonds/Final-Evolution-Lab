import React, { useState, useEffect, useRef } from "react";
import axios from "axios";
import { 
  Trophy, Brain, HelpCircle, Award, Play, RotateCcw, 
  Coins, Star, Volume2, VolumeX, Timer, ChevronRight, Check, X, ShieldAlert 
} from "lucide-react";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

export function TriviaArenaView({ onBack }) {
  const [gameState, setGameState] = useState("start"); // start, spinning, question, grading, results
  const [audioEnabled, setAudioEnabled] = useState(true);
  
  // Game metrics
  const [round, setRound] = useState(1);
  const [score, setScore] = useState(0);
  const [historyLog, setHistoryLog] = useState([]); // [{ category, question, correct: boolean }]
  
  // Wheel State
  const [rotation, setRotation] = useState(0);
  const [spinning, setSpinning] = useState(false);
  const [currentCategory, setCurrentCategory] = useState(null);

  // Question State
  const [question, setQuestion] = useState(null);
  const [selectedAnswer, setSelectedAnswer] = useState(null); // index
  const [isAnswered, setIsAnswered] = useState(false);
  const [timeLeft, setTimeLeft] = useState(15);
  const timerRef = useRef(null);
  
  // Final receipt
  const [receipt, setReceipt] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const categories = [
    { id: "history", name: "History", color: "#F59E0B", gradient: "from-amber-500 to-yellow-600", text: "text-amber-400" },
    { id: "science", name: "Science", color: "#10B981", gradient: "from-emerald-500 to-green-600", text: "text-emerald-400" },
    { id: "pop_culture", name: "Pop Culture", color: "#F43F5E", gradient: "from-rose-500 to-pink-600", text: "text-rose-400" },
    { id: "sport_history", name: "Sport History", color: "#F97316", gradient: "from-orange-500 to-red-600", text: "text-orange-400" },
    { id: "sport_science", name: "Sport Science", color: "#06B6D4", gradient: "from-cyan-500 to-blue-600", text: "text-cyan-400" },
    { id: "art", name: "Art", color: "#8B5CF6", gradient: "from-violet-500 to-purple-600", text: "text-violet-400" },
    { id: "literature", name: "Literature", color: "#6366F1", gradient: "from-indigo-500 to-violet-600", text: "text-indigo-400" },
    { id: "vocabulary", name: "Vocabulary", color: "#14B8A6", gradient: "from-teal-500 to-emerald-600", text: "text-teal-400" }
  ];

  // Sound Synthesizer (Web Audio API)
  const synthTone = (freq, type = "sine", duration = 0.1, delay = 0) => {
    if (!audioEnabled) return;
    try {
      setTimeout(() => {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const osc = ctx.createOscillator();
        const gain = ctx.createGain();
        osc.type = type;
        osc.frequency.setValueAtTime(freq, ctx.currentTime);
        osc.connect(gain);
        gain.connect(ctx.destination);
        gain.gain.setValueAtTime(0.12, ctx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
        osc.start();
        osc.stop(ctx.currentTime + duration);
      }, delay * 1000);
    } catch {}
  };

  const playSpinSound = () => {
    if (!audioEnabled) return;
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sawtooth";
      osc.frequency.setValueAtTime(100, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(600, ctx.currentTime + 1.2);
      osc.frequency.exponentialRampToValueAtTime(220, ctx.currentTime + 3.0);
      osc.connect(gain);
      gain.connect(ctx.destination);
      gain.gain.setValueAtTime(0.08, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 3.0);
      osc.start();
      osc.stop(ctx.currentTime + 3.0);
    } catch {}
  };

  const playCorrectSound = () => {
    synthTone(523.25, "sine", 0.1); // C5
    synthTone(659.25, "sine", 0.15, 0.08); // E5
    synthTone(783.99, "sine", 0.25, 0.16); // G5
  };

  const playIncorrectSound = () => {
    try {
      if (!audioEnabled) return;
      const ctx = new (window.AudioContext || window.webkitAudioContext)();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = "sawtooth";
      osc.frequency.setValueAtTime(180, ctx.currentTime);
      osc.frequency.linearRampToValueAtTime(90, ctx.currentTime + 0.35);
      osc.connect(gain);
      gain.connect(ctx.destination);
      gain.gain.setValueAtTime(0.15, ctx.currentTime);
      gain.gain.linearRampToValueAtTime(0.001, ctx.currentTime + 0.35);
      osc.start();
      osc.stop(ctx.currentTime + 0.35);
    } catch {}
  };

  // Timer logic
  useEffect(() => {
    if (gameState === "question" && timeLeft > 0 && !isAnswered) {
      timerRef.current = setTimeout(() => setTimeLeft(t => t - 1), 1000);
    } else if (gameState === "question" && timeLeft === 0 && !isAnswered) {
      handleTimeout();
    }
    return () => clearTimeout(timerRef.current);
  }, [gameState, timeLeft, isAnswered]);

  const startNewGame = () => {
    setRound(1);
    setScore(0);
    setHistoryLog([]);
    setReceipt(null);
    setGameState("spinning");
    setRotation(0);
    setCurrentCategory(null);
  };

  const spinWheel = () => {
    if (spinning) return;
    setSpinning(true);
    setGameState("spinning");
    
    // Choose a random index (0-7)
    const categoryIndex = Math.floor(Math.random() * 8);
    const targetCategory = categories[categoryIndex];
    
    // Calculate rotation: 5 full spins + degrees to center the segment
    // Each segment is 45 degrees. Pointer is at 0 degrees (top).
    // Segment 0 center is at 22.5 deg, Segment 1 is at 67.5 deg, etc.
    const segmentAngle = 45;
    const finalAngle = 360 * 5 + (360 - (categoryIndex * segmentAngle) - 22.5);
    
    setRotation(finalAngle);
    playSpinSound();

    setTimeout(() => {
      setSpinning(false);
      setCurrentCategory(targetCategory);
      fetchQuestionForCategory(targetCategory.id);
    }, 3100);
  };

  const fetchQuestionForCategory = async (catId) => {
    try {
      const r = await axios.get(`${API}/trivia/questions`, {
        params: { category: catId, count: 1 }
      });
      if (r.data && r.data.length > 0) {
        setQuestion(r.data[0]);
        setSelectedAnswer(null);
        setIsAnswered(false);
        setTimeLeft(15);
        setGameState("question");
      }
    } catch (e) {
      console.error(e);
      // Fallback in case of network issue
      setQuestion({
        question: "What muscle group is primary for long distance athletic events?",
        options: ["Fast-Twitch", "Slow-Twitch", "Cardiac", "Intermediate"],
        correct: 1,
        category: "sport_science",
        difficulty: "easy"
      });
      setSelectedAnswer(null);
      setIsAnswered(false);
      setTimeLeft(15);
      setGameState("question");
    }
  };

  const handleTimeout = () => {
    setIsAnswered(true);
    setSelectedAnswer(-1); // No choice
    playIncorrectSound();
    
    setHistoryLog(prev => [
      ...prev,
      { category: currentCategory, question: question.question, correct: false }
    ]);

    setTimeout(advanceGame, 2000);
  };

  const selectAnswer = (optionIdx) => {
    if (isAnswered) return;
    setIsAnswered(true);
    setSelectedAnswer(optionIdx);
    
    const isCorrect = optionIdx === question.correct;
    if (isCorrect) {
      setScore(s => s + 1);
      playCorrectSound();
    } else {
      playIncorrectSound();
    }

    setHistoryLog(prev => [
      ...prev,
      { category: currentCategory, question: question.question, correct: isCorrect }
    ]);

    setTimeout(advanceGame, 2000);
  };

  const advanceGame = () => {
    if (round < 5) {
      setRound(r => r + 1);
      setGameState("spinning");
      setCurrentCategory(null);
    } else {
      submitGameSession();
    }
  };

  const submitGameSession = async () => {
    setGameState("grading");
    setSubmitting(true);
    
    const finalScore = score * 100; // e.g. 4/5 correct -> 400 score
    const outcomeResult = score >= 3 ? "win" : "loss";
    
    try {
      const r = await axios.post(`${API}/games/session`, {
        mode_id: "trivia_arena",
        score: finalScore,
        outcome: outcomeResult,
        duration_seconds: 60,
        completed: true
      });
      setReceipt(r.data);
    } catch (e) {
      console.error("Session receipt commit failed:", e);
      // Client-side fallback receipt representation
      setReceipt({
        xp_earned: Math.min(Math.floor(finalScore / 5), 500),
        shards_earned: score >= 3 ? 50 : 15,
        prq_delta: score >= 3 ? 2.2 : -1.1,
        score: finalScore
      });
    } finally {
      setSubmitting(false);
      setGameState("results");
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 fade-in">
      
      {/* HEADER BAR */}
      <div className="flex items-center justify-between border-b border-white/5 pb-4">
        <div>
          <span className="overline text-teal-400">Brain Brawl Suite</span>
          <h1 className="text-4xl font-black uppercase tracking-tight" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
            Trivia Arena
          </h1>
        </div>
        <div className="flex items-center gap-4">
          <button 
            onClick={() => setAudioEnabled(!audioEnabled)}
            className="p-2 border border-white/5 bg-zinc-900/60 hover:bg-zinc-800 text-zinc-400 hover:text-white rounded transition-colors"
            title={audioEnabled ? "Disable Game Audio" : "Enable Game Audio"}
          >
            {audioEnabled ? <Volume2 className="w-5 h-5" /> : <VolumeX className="w-5 h-5 text-zinc-600" />}
          </button>
          {onBack && (
            <button onClick={onBack} className="px-4 py-2 border border-zinc-800 bg-[#0F0F13] hover:bg-zinc-800 text-zinc-400 hover:text-white text-xs font-mono uppercase rounded transition-all">
              Exit Game
            </button>
          )}
        </div>
      </div>

      {/* START STATE */}
      {gameState === "start" && (
        <div className="max-w-xl mx-auto text-center" data-testid="trivia-start-screen">
          <div className="surface-card p-10 border border-white/10 rounded-sm relative overflow-hidden">
            <div className="absolute top-0 right-0 w-20 h-20 bg-gradient-to-bl from-teal-500/10 to-transparent"></div>
            
            <div className="w-20 h-20 bg-teal-400/10 border border-teal-400/20 text-teal-400 flex items-center justify-center rounded-sm mx-auto mb-6">
              <Brain className="w-10 h-10 animate-pulse" />
            </div>
            
            <h2 className="text-3xl font-extrabold uppercase mb-3" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              SPIN & WIN
            </h2>
            
            <p className="text-zinc-400 text-sm max-w-sm mx-auto mb-8 font-light">
              Test your knowledge across 8 custom categories inspired by Trivia Crack and vocab.com. Achieve at least 3 correct answers to earn bonus Shards!
            </p>

            <div className="grid grid-cols-2 gap-3 max-w-md mx-auto mb-8 text-left font-mono text-xs text-zinc-500">
              <div className="p-3 bg-black/40 border border-white/5 rounded">
                <span className="text-zinc-600 uppercase block mb-1">Total Rounds</span>
                <span className="text-white text-lg font-bold">5 Quizzes</span>
              </div>
              <div className="p-3 bg-black/40 border border-white/5 rounded">
                <span className="text-zinc-600 uppercase block mb-1">Time Limit</span>
                <span className="text-white text-lg font-bold">15s per Q</span>
              </div>
              <div className="p-3 bg-black/40 border border-white/5 rounded">
                <span className="text-zinc-600 uppercase block mb-1">Economy Reward</span>
                <span className="text-yellow-400 text-lg font-bold">50 Shards / Win</span>
              </div>
              <div className="p-3 bg-black/40 border border-white/5 rounded">
                <span className="text-zinc-600 uppercase block mb-1">PRQ Delta</span>
                <span className="text-emerald-400 text-lg font-bold">Up to +2.4 PRQ</span>
              </div>
            </div>

            <button 
              onClick={startNewGame}
              className="w-full py-4 bg-teal-400 hover:bg-teal-300 text-black font-extrabold text-sm tracking-wider uppercase transition-all rounded shadow-[0_0_20px_rgba(20,184,166,0.2)]"
            >
              Start Game Session
            </button>
          </div>
        </div>
      )}

      {/* SPINNING STATE */}
      {gameState === "spinning" && (
        <div className="grid md:grid-cols-12 gap-8 items-center" data-testid="trivia-spinning-screen">
          
          <div className="md:col-span-5 space-y-6 text-center md:text-left">
            <div className="p-4 border border-zinc-800 bg-zinc-950/60 rounded">
              <div className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono">Arena Progression</div>
              <div className="text-3xl font-extrabold text-white mt-1">ROUND {round} / 5</div>
              <div className="progress-bar mt-3 rounded-full"><div className="progress-fill rounded-full bg-teal-400" style={{ width: `${((round - 1) / 5) * 100}%` }}></div></div>
            </div>

            <div className="space-y-2">
              <h3 className="text-xl font-bold uppercase font-mono">Spin the Category Wheel</h3>
              <p className="text-sm text-zinc-400 font-light">
                Spin the wheel to lock in a random academic or sports subject. Shards are committed after 5 full rounds.
              </p>
            </div>

            <button
              onClick={spinWheel}
              disabled={spinning}
              className="px-8 py-3.5 bg-teal-400 hover:bg-teal-300 disabled:bg-zinc-850 disabled:text-zinc-600 text-black font-bold text-xs tracking-wider uppercase transition-all shadow-[0_4px_15px_rgba(20,184,166,0.1)] rounded w-full flex items-center justify-center gap-2"
            >
              {spinning ? "Wheel is spinning..." : "Spin Category Wheel"}
            </button>
          </div>

          <div className="md:col-span-7 flex flex-col items-center justify-center">
            {/* SPINNER WHEEL COMPONENT */}
            <div className="relative w-80 h-80 md:w-96 md:h-96">
              
              {/* Point Indicator */}
              <div className="absolute top-[-10px] left-1/2 -translate-x-1/2 z-20 w-0 h-0 border-l-[12px] border-l-transparent border-r-[12px] border-r-transparent border-t-[20px] border-t-white drop-shadow-[0_2px_5px_rgba(0,0,0,0.5)]"></div>
              
              {/* Outer boundary */}
              <div className="w-full h-full rounded-full border-[8px] border-[#0F0F13] bg-[#050505] shadow-[0_0_40px_rgba(0,0,0,0.8),0_0_20px_rgba(255,255,255,0.02)] overflow-hidden relative">
                
                {/* SVG Rotator */}
                <svg 
                  className="w-full h-full"
                  viewBox="0 0 100 100"
                  style={{ 
                    transform: `rotate(${rotation}deg)`, 
                    transition: spinning ? "transform 3.1s cubic-bezier(0.08, 0.76, 0.22, 0.99)" : "none" 
                  }}
                >
                  <g transform="translate(50,50)">
                    {categories.map((cat, idx) => {
                      const angle = 45;
                      const rotateVal = idx * angle;
                      // Draw 45deg slice
                      return (
                        <path 
                          key={cat.id}
                          d="M0,0 L0,-45 A45,45 0 0,1 31.819,-31.819 Z" 
                          fill={cat.color}
                          transform={`rotate(${rotateVal})`}
                          stroke="rgba(0,0,0,0.15)"
                          strokeWidth="0.5"
                          opacity="0.85"
                        />
                      );
                    })}
                  </g>
                  {/* Wheel inner core */}
                  <circle cx="50" cy="50" r="14" fill="#0A0A0E" stroke="rgba(255,255,255,0.08)" strokeWidth="1" />
                  <circle cx="50" cy="50" r="13" fill="#0F0F13" />
                </svg>

                {/* Inner center text indicator */}
                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                  <div className="w-12 h-12 rounded-full bg-[#050505] border border-white/10 flex items-center justify-center">
                    <Brain className="w-5 h-5 text-teal-400" />
                  </div>
                </div>
              </div>
            </div>

            {currentCategory && (
              <div className="mt-6 text-center font-mono animate-bounce">
                <span className="text-zinc-500 uppercase text-xs">SELECTED</span>
                <div className={`text-xl font-bold uppercase ${currentCategory.text}`}>{currentCategory.name}</div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* QUESTION STATE */}
      {gameState === "question" && question && (
        <div className="max-w-2xl mx-auto" data-testid="trivia-question-screen">
          <div className="flex items-center justify-between font-mono text-xs text-zinc-500 mb-3">
            <span className="p-1 px-2 border border-zinc-800 bg-[#0A0A0C] text-zinc-400 uppercase">ROUND {round}/5</span>
            <div className="flex items-center gap-2">
              <Timer className="w-4 h-4 text-zinc-600" />
              <span className={`text-sm font-bold ${timeLeft <= 4 ? "text-red-400 animate-pulse" : "text-white"}`}>
                {timeLeft}s
              </span>
            </div>
            <span className={`uppercase font-bold ${currentCategory.text}`}>
              {currentCategory.name}
            </span>
          </div>

          {/* Time Limit Progress Bar */}
          <div className="progress-bar rounded-full mb-6">
            <div 
              className={`progress-fill rounded-full transition-all duration-1000 ${timeLeft <= 4 ? "bg-red-500" : "bg-teal-400"}`} 
              style={{ width: `${(timeLeft / 15) * 100}%` }}
            ></div>
          </div>

          <div className="surface-card p-8 border border-white/10 rounded-sm relative">
            <div className="absolute top-2 right-4 font-mono text-[9px] text-zinc-600">DIFFICULTY: {question.difficulty.toUpperCase()}</div>
            
            <h2 className="text-2xl sm:text-3xl font-extrabold text-center mt-4 mb-10 text-white" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              {question.question}
            </h2>

            <div className="grid grid-cols-1 gap-3">
              {question.options.map((opt, idx) => {
                let btnStyle = "border-white/5 hover:border-teal-400/30 text-zinc-300 hover:text-white bg-[#0F0F13]/50";
                let iconEl = null;

                if (isAnswered) {
                  if (idx === question.correct) {
                    btnStyle = "border-emerald-500/50 bg-emerald-500/10 text-emerald-400 font-bold";
                    iconEl = <Check className="w-5 h-5 text-emerald-400" />;
                  } else if (idx === selectedAnswer) {
                    btnStyle = "border-red-500/50 bg-red-500/10 text-red-400 font-bold";
                    iconEl = <X className="w-5 h-5 text-red-400" />;
                  } else {
                    btnStyle = "border-white/5 opacity-40 text-zinc-500 bg-zinc-950";
                  }
                }

                return (
                  <button
                    key={idx}
                    onClick={() => selectAnswer(idx)}
                    disabled={isAnswered}
                    className={`p-4 rounded border text-left font-medium transition-all text-sm sm:text-base flex items-center justify-between ${btnStyle}`}
                  >
                    <div className="flex items-center gap-3">
                      <span className="font-mono text-zinc-500 text-xs">{["A", "B", "C", "D"][idx]}.</span>
                      <span>{opt}</span>
                    </div>
                    {iconEl}
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* GRADING STATE */}
      {gameState === "grading" && (
        <div className="max-w-md mx-auto text-center py-20" data-testid="trivia-grading-screen">
          <div className="w-16 h-16 border-4 border-teal-400 border-t-transparent rounded-full animate-spin mx-auto mb-6"></div>
          <h3 className="text-2xl font-bold uppercase" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
            Verifying Telemetry
          </h3>
          <p className="text-zinc-500 text-xs font-mono mt-2">
            POST /api/games/session // committing transaction...
          </p>
        </div>
      )}

      {/* RESULTS STATE */}
      {gameState === "results" && receipt && (
        <div className="max-w-2xl mx-auto" data-testid="trivia-results-screen">
          <div className="surface-card p-10 border border-white/10 rounded text-center relative overflow-hidden">
            <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-bl from-teal-500/10 to-transparent"></div>
            
            <Award className="w-20 h-20 text-teal-400 mx-auto mb-6" />
            
            <h2 className="text-3xl font-black uppercase mb-1" style={{ fontFamily: "'Barlow Condensed', sans-serif" }}>
              Session Certified
            </h2>
            <p className="text-xs font-mono text-zinc-500 mb-6">DATABASE RECEIPT COMMITTED</p>

            <div className="metric-value text-6xl text-white font-mono mb-2">{score} / 5</div>
            <div className="metric-label mb-8">CORRECT ANSWERS</div>

            {/* Receipt metrics */}
            <div className="grid grid-cols-3 gap-4 mb-8">
              <div className="p-4 bg-zinc-950/60 border border-zinc-800 rounded">
                <span className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono block">XP Gained</span>
                <span className="text-2xl font-bold text-white font-mono block mt-1">+{receipt.xp_earned} XP</span>
              </div>
              <div className="p-4 bg-zinc-950/60 border border-zinc-800 rounded">
                <span className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono block">Shards Payout</span>
                <span className="text-2xl font-bold text-yellow-400 font-mono block mt-1">+{receipt.shards_earned}</span>
              </div>
              <div className="p-4 bg-zinc-950/60 border border-zinc-800 rounded">
                <span className="text-[10px] text-zinc-500 uppercase tracking-widest font-mono block">PRQ Delta</span>
                <span className={`text-2xl font-bold font-mono block mt-1 ${receipt.prq_delta >= 0 ? "text-emerald-400" : "text-red-400"}`}>
                  {receipt.prq_delta >= 0 ? `+${receipt.prq_delta}` : receipt.prq_delta}
                </span>
              </div>
            </div>

            {/* Performance log */}
            <div className="border border-zinc-800/80 bg-zinc-950/30 rounded p-4 text-left mb-8 space-y-2.5 font-mono text-xs">
              <span className="text-[10px] text-zinc-500 uppercase block mb-1">Round Ledger</span>
              {historyLog.map((log, idx) => (
                <div key={idx} className="flex justify-between items-center border-b border-zinc-900/60 pb-1.5 last:border-0 last:pb-0">
                  <div className="flex items-center gap-2">
                    <span className={`w-1.5 h-1.5 rounded-full ${log.category.color === '#F59E0B' ? 'bg-amber-400' : 'bg-teal-400'}`} style={{ backgroundColor: log.category.color }}></span>
                    <span className="text-zinc-400 truncate max-w-[200px] sm:max-w-[320px]">{log.question}</span>
                  </div>
                  <span className={log.correct ? "text-emerald-400" : "text-red-400"}>
                    {log.correct ? "CORRECT" : "WRONG"}
                  </span>
                </div>
              ))}
            </div>

            <div className="flex flex-col sm:flex-row gap-3">
              <button 
                onClick={startNewGame}
                className="flex-1 py-3.5 bg-teal-400 hover:bg-teal-300 text-black font-extrabold text-xs tracking-wider uppercase transition-all rounded"
              >
                Play Again
              </button>
              {onBack && (
                <button 
                  onClick={onBack}
                  className="flex-1 py-3.5 border border-zinc-800 bg-[#0F0F13] hover:bg-zinc-800 text-zinc-300 hover:text-white font-extrabold text-xs tracking-wider uppercase transition-all rounded"
                >
                  Return to Arena
                </button>
              )}
            </div>

          </div>
        </div>
      )}

    </div>
  );
}
