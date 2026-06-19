import React, { useState, useEffect, useCallback } from "react";
import axios from "axios";
import {
  Activity, ShoppingBag, Gamepad2, GraduationCap, Award, BookOpen,
  Atom, Brain, ChevronRight, ChevronLeft, CheckCircle2, Lock, Zap,
  Trophy, Target, Flame, Crown, Sparkles, ExternalLink, Loader2,
  Share2, Download, Copy, X
} from "lucide-react";
import { BioFuelStripe, BioFuelScanner, BioFuelCookbook, BioFuelDoorDash } from "./BioFuel";
import { API } from "@/lib/api";

const TRACK_ICON = { BookOpen, Atom, Award, Brain };
const TRACK_GLOW = {
  emerald: { ring: "ring-emerald-400/40", text: "text-emerald-400", bg: "bg-emerald-400/10", border: "border-emerald-400/30" },
  cyan:    { ring: "ring-cyan-400/40",    text: "text-cyan-400",    bg: "bg-cyan-400/10",    border: "border-cyan-400/30" },
  amber:   { ring: "ring-amber-400/40",   text: "text-amber-400",   bg: "bg-amber-400/10",   border: "border-amber-400/30" },
  fuchsia: { ring: "ring-fuchsia-400/40", text: "text-fuchsia-400", bg: "bg-fuchsia-400/10", border: "border-fuchsia-400/30" },
};

// ============================================================
// 4-QUADRANT DASHBOARD
// ============================================================
export const FELOSDashboard = ({ setActiveTab }) => {
  const [scan, setScan] = useState(null);
  const [view, setView] = useState("overview"); // overview | track | lesson | final
  const [trackId, setTrackId] = useState(null);
  const [lessonId, setLessonId] = useState(null);
  const [shareOpen, setShareOpen] = useState(false);
  const [scannerOpen, setScannerOpen] = useState(false);
  const [cookbookOpen, setCookbookOpen] = useState(false);
  const [doordashOpen, setDoordashOpen] = useState(false);
  const [biofuelKey, setBiofuelKey] = useState(0); // bump to force stripe refresh after a log

  const refresh = useCallback(() => {
    axios.get(`${API}/system-scan/unified`).then((r) => setScan(r.data)).catch(console.error);
  }, []);
  useEffect(() => { refresh(); }, [refresh]);

  if (view === "lesson" && trackId && lessonId) {
    return <LessonRunner trackId={trackId} lessonId={lessonId} onBack={() => { setView("track"); refresh(); }} />;
  }
  if (view === "track" && trackId) {
    return <TrackDetail trackId={trackId} onBack={() => { setView("overview"); setTrackId(null); refresh(); }} onLesson={(lid) => { setLessonId(lid); setView("lesson"); }} onFinal={() => setView("final")} scan={scan} />;
  }
  if (view === "final" && trackId === "kinesiology") {
    return <KinesiologyFinal onBack={() => { setView("track"); refresh(); }} />;
  }

  return (
    <div className="space-y-6 fade-in" data-testid="fel-os-dashboard">
      {/* HEADER */}
      <div className="flex items-end justify-between flex-wrap gap-4">
        <div>
          <div className="text-xs tracking-[0.4em] text-cyan-400/70 uppercase">FEL OS · System</div>
          <h1 className="text-4xl sm:text-5xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>
            FINAL EVOLUTION <span className="text-cyan-400">/ OS</span>
          </h1>
          <p className="text-sm text-zinc-400 mt-1">One scan. Four pillars. Athlete-sovereign.</p>
        </div>
        {scan && (
          <div className="flex items-center gap-3" data-testid="fel-os-header-prq">
            <button
              data-testid="share-pass-btn"
              onClick={() => setShareOpen(true)}
              className="hidden sm:flex items-center gap-2 px-3 py-2 border border-cyan-400/40 text-cyan-400 hover:bg-cyan-400/10 transition-colors text-xs font-bold tracking-wider uppercase"
            >
              <Share2 className="w-3.5 h-3.5" /> Share Pass
            </button>
            <div className="text-right">
              <div className="text-xs text-zinc-500 uppercase tracking-wider">PRQ</div>
              <div className="text-3xl font-black text-cyan-400">{scan.scan.prq_score?.toFixed(1)}</div>
            </div>
            <div className="w-px h-10 bg-zinc-800" />
            <div className="text-right">
              <div className="text-xs text-zinc-500 uppercase tracking-wider">Lvl</div>
              <div className="text-3xl font-black">{scan.scan.level}</div>
            </div>
            <div className="w-px h-10 bg-zinc-800" />
            <div className="text-right">
              <div className="text-xs text-zinc-500 uppercase tracking-wider flex items-center gap-1 justify-end"><Flame className="w-3 h-3"/>Streak</div>
              <div className="text-3xl font-black text-orange-400">{scan.scan.streak_days}</div>
            </div>
          </div>
        )}
      </div>

      {!scan ? (
        <div className="flex items-center justify-center py-20"><Loader2 className="w-8 h-8 animate-spin text-cyan-400" /></div>
      ) : (
        <>
          <BioFuelStripe
            key={biofuelKey}
            onOpenScanner={() => setScannerOpen(true)}
            onOpenCookbook={() => setCookbookOpen(true)}
            onOpenDoorDash={() => setDoordashOpen(true)}
          />
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
            <ScanQuadrant scan={scan.scan} onOpen={() => setActiveTab && setActiveTab("scan")} />
            <CardsQuadrant cards={scan.cards} onOpen={() => setActiveTab && setActiveTab("cards")} />
            <ArenaQuadrant arena={scan.arena} onOpen={() => setActiveTab && setActiveTab("games")} />
            <AcademyQuadrant academy={scan.academy} onTrack={(tid) => { setTrackId(tid); setView("track"); }} />
          </div>
        </>
      )}

      {shareOpen && scan && (
        <SharePassModal userId={scan.user.user_id} onClose={() => setShareOpen(false)} />
      )}
      {scannerOpen && (
        <BioFuelScanner onClose={() => setScannerOpen(false)} onLogged={() => { setBiofuelKey((k) => k + 1); refresh(); }} />
      )}
      {cookbookOpen && (
        <BioFuelCookbook onClose={() => setCookbookOpen(false)} />
      )}
      {doordashOpen && (
        <BioFuelDoorDash onClose={() => setDoordashOpen(false)} onLogged={() => { setBiofuelKey((k) => k + 1); refresh(); }} />
      )}
    </div>
  );
};

// ============================================================
// QUADRANTS
// ============================================================
const QuadrantShell = ({ icon: Icon, label, accent, onOpen, children, testId }) => (
  <div data-testid={testId} className={`relative border ${accent} bg-zinc-950/60 p-6 group hover:bg-zinc-950 transition-colors`}>
    <div className="flex items-center justify-between mb-4">
      <div className="flex items-center gap-3">
        <div className={`w-10 h-10 ${accent.replace('border-','bg-').replace('/30','/15')} flex items-center justify-center border ${accent}`}>
          <Icon className="w-5 h-5" />
        </div>
        <div>
          <div className="text-[10px] tracking-[0.4em] text-zinc-500 uppercase">FEL OS</div>
          <div className="font-bold text-lg tracking-tight">{label}</div>
        </div>
      </div>
      {onOpen && (
        <button data-testid={`${testId}-open`} onClick={onOpen} className="text-xs text-zinc-400 hover:text-cyan-400 flex items-center gap-1 transition-colors">
          Open <ChevronRight className="w-3 h-3" />
        </button>
      )}
    </div>
    {children}
  </div>
);

const ScanQuadrant = ({ scan, onOpen }) => (
  <QuadrantShell icon={Activity} label="System Scan" accent="border-cyan-400/30" onOpen={onOpen} testId="quadrant-scan">
    <div className="grid grid-cols-2 gap-3 text-sm">
      <Stat label="PRQ Score" value={scan.prq_score?.toFixed(1)} accent="text-cyan-400" />
      <Stat label="XP" value={scan.xp} />
      <Stat label="Strength" value={scan.metrics?.strength?.toFixed(0) ?? '—'} />
      <Stat label="Speed" value={scan.metrics?.speed?.toFixed(0) ?? '—'} />
      <Stat label="Power" value={scan.metrics?.power?.toFixed(0) ?? '—'} />
      <Stat label="Mental" value={scan.metrics?.mental?.toFixed(0) ?? '—'} />
    </div>
    {scan.last_vertical_jump && (
      <div className="mt-4 pt-4 border-t border-zinc-800 text-xs text-zinc-400">
        <span className="text-zinc-500">Last vertical jump:</span>{" "}
        <span className="text-cyan-400 font-mono">{scan.last_vertical_jump.height_in ?? scan.last_vertical_jump.height ?? '—'}"</span>
      </div>
    )}
  </QuadrantShell>
);

const CardsQuadrant = ({ cards, onOpen }) => (
  <QuadrantShell icon={ShoppingBag} label="Creator Cards" accent="border-violet-400/30" onOpen={onOpen} testId="quadrant-cards">
    <div className="grid grid-cols-2 gap-3 text-sm">
      <Stat label="Owned" value={cards.owned_count} accent="text-violet-400" />
      <Stat label="Lifetime Buys" value={cards.lifetime_purchases} />
    </div>
    {cards.recent?.length ? (
      <div className="mt-4 pt-4 border-t border-zinc-800">
        <div className="text-[10px] uppercase tracking-wider text-zinc-500 mb-2">Recent</div>
        <div className="space-y-1">
          {cards.recent.slice(0, 3).map((c, i) => (
            <div key={i} className="text-xs text-zinc-300 truncate">· {c.card_id || c.title || 'Card'}</div>
          ))}
        </div>
      </div>
    ) : (
      <div className="mt-4 pt-4 border-t border-zinc-800 text-xs text-zinc-500">No cards yet — visit the marketplace.</div>
    )}
  </QuadrantShell>
);

const ArenaQuadrant = ({ arena, onOpen }) => (
  <QuadrantShell icon={Gamepad2} label="Arena · 19 Modes" accent="border-orange-400/30" onOpen={onOpen} testId="quadrant-arena">
    <div className="grid grid-cols-2 gap-3 text-sm">
      <Stat label="Modes Played" value={arena.modes_played} accent="text-orange-400" />
      <Stat label="Sovereign Sess." value={arena.sovereign_sessions} />
    </div>
    <div className="mt-4 pt-4 border-t border-zinc-800 flex items-center justify-between text-xs">
      <span className="text-zinc-500">UE5 Bridge</span>
      <span className="text-emerald-400 font-mono flex items-center gap-1">
        <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
        {arena.ue5_bridge?.toUpperCase()}
      </span>
    </div>
  </QuadrantShell>
);

const AcademyQuadrant = ({ academy, onTrack }) => (
  <QuadrantShell icon={GraduationCap} label="Academy · 4 Tracks" accent="border-amber-400/30" testId="quadrant-academy">
    <div className="flex items-baseline gap-2 mb-3">
      <div className="text-3xl font-black text-amber-400">{academy.overall_completion_pct}%</div>
      <div className="text-xs text-zinc-500">{academy.lessons_completed}/{academy.lessons_total} lessons</div>
    </div>
    <div className="space-y-2">
      {academy.tracks.map((t) => (
        <button
          key={t.track_id}
          data-testid={`academy-track-${t.track_id}`}
          onClick={() => onTrack(t.track_id)}
          className="w-full flex items-center justify-between p-2 hover:bg-zinc-900 transition-colors text-left group"
        >
          <div className="flex items-center gap-2 flex-1 min-w-0">
            {t.certificate_issued ? (
              <Crown className="w-4 h-4 text-amber-400 shrink-0" />
            ) : (
              <CheckCircle2 className={`w-4 h-4 shrink-0 ${t.completion_pct === 100 ? 'text-emerald-400' : 'text-zinc-700'}`} />
            )}
            <div className="text-xs truncate">
              <div className="text-zinc-200 group-hover:text-cyan-400 transition-colors">{t.title}</div>
              <div className="text-zinc-600">{t.completion_pct}% · {t.is_certificate ? 'Certificate' : 'Track'}</div>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-zinc-700 group-hover:text-cyan-400" />
        </button>
      ))}
    </div>
    {academy.kinesiology_certificate?.issued ? (
      <div className="mt-3 p-2 border border-amber-400/40 bg-amber-400/5 text-xs text-amber-400 flex items-center gap-2">
        <Crown className="w-3 h-3" /> Applied Kinesiology — Certified
      </div>
    ) : null}
  </QuadrantShell>
);

const Stat = ({ label, value, accent }) => (
  <div>
    <div className="text-[10px] uppercase tracking-wider text-zinc-500">{label}</div>
    <div className={`text-2xl font-black ${accent || 'text-zinc-100'}`}>{value ?? '—'}</div>
  </div>
);

// ============================================================
// TRACK DETAIL
// ============================================================
const TrackDetail = ({ trackId, onBack, onLesson, onFinal, scan }) => {
  const [track, setTrack] = useState(null);
  const [progress, setProgress] = useState(null);
  const [eligibility, setEligibility] = useState(null);
  const [claiming, setClaiming] = useState(false);
  const [claimResult, setClaimResult] = useState(null);
  const [bbLaunch, setBbLaunch] = useState(null);

  const refresh = useCallback(() => {
    axios.get(`${API}/education/tracks/${trackId}`).then((r) => setTrack(r.data)).catch(console.error);
    axios.get(`${API}/education/progress`).then((r) => {
      const t = r.data.tracks.find((x) => x.track_id === trackId);
      setProgress(t);
    }).catch(console.error);
    if (trackId === "kinesiology") {
      axios.get(`${API}/education/kinesiology/eligibility`).then((r) => setEligibility(r.data)).catch(console.error);
    }
  }, [trackId]);
  useEffect(() => { refresh(); }, [refresh]);

  if (!track || !progress) return <div className="flex items-center justify-center py-20"><Loader2 className="w-8 h-8 animate-spin text-cyan-400" /></div>;

  const palette = TRACK_GLOW[track.color] || TRACK_GLOW.cyan;
  const Icon = TRACK_ICON[track.icon] || BookOpen;
  const completed = new Set(Object.keys(progress.quiz_scores || {}).filter(lid => (progress.quiz_scores[lid] >= 75)));

  const claimCert = async () => {
    setClaiming(true);
    try {
      const r = await axios.post(`${API}/education/kinesiology/certify`);
      setClaimResult(r.data);
      refresh();
    } catch (e) {
      setClaimResult({ error: e.response?.data?.detail || 'Failed' });
    } finally {
      setClaiming(false);
    }
  };

  const launchBrainBrawl = async () => {
    try {
      const r = await axios.post(`${API}/education/brain-brawl/launch`);
      setBbLaunch(r.data);
      // Native iOS deep link
      window.location.href = r.data.deep_link;
    } catch (e) {
      console.error(e);
    }
  };

  return (
    <div className="space-y-6 fade-in" data-testid={`track-detail-${trackId}`}>
      <button data-testid="track-back-btn" onClick={onBack} className="flex items-center gap-2 text-sm text-zinc-400 hover:text-cyan-400">
        <ChevronLeft className="w-4 h-4" /> Back to FEL OS
      </button>

      <div className={`border ${palette.border} ${palette.bg} p-6`}>
        <div className="flex items-start gap-4">
          <div className={`w-14 h-14 border ${palette.border} flex items-center justify-center`}>
            <Icon className={`w-7 h-7 ${palette.text}`} />
          </div>
          <div className="flex-1 min-w-0">
            <div className={`text-[10px] tracking-[0.4em] uppercase ${palette.text}`}>{track.category} · {track.level}</div>
            <h2 className="text-3xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>{track.title}</h2>
            <div className="text-sm text-zinc-400 mt-1">{track.subtitle}</div>
            <p className="text-sm text-zinc-300 mt-3 leading-relaxed">{track.description}</p>
          </div>
          <div className="text-right">
            <div className="text-[10px] uppercase tracking-wider text-zinc-500">Progress</div>
            <div className={`text-3xl font-black ${palette.text}`}>{progress.completion_pct}%</div>
          </div>
        </div>
      </div>

      {/* Brain Brawl special: deep-link launch */}
      {trackId === "brain_brawl" && (
        <div className="border border-fuchsia-400/30 bg-fuchsia-400/5 p-5">
          <div className="flex items-center justify-between flex-wrap gap-3">
            <div>
              <div className="font-bold flex items-center gap-2"><Brain className="w-4 h-4 text-fuchsia-400" /> Live Combat — UE5</div>
              <div className="text-xs text-zinc-400 mt-1">Web exposes briefings & cooldowns. Live arena runs in iOS via deep link.</div>
            </div>
            <button data-testid="brain-brawl-launch-btn" onClick={launchBrainBrawl} className="px-4 py-2 bg-fuchsia-400 text-black font-bold text-sm flex items-center gap-2 hover:bg-fuchsia-300 transition-colors">
              <ExternalLink className="w-4 h-4" /> Launch in iOS
            </button>
          </div>
          {bbLaunch && (
            <div className="mt-3 pt-3 border-t border-fuchsia-400/20 text-xs font-mono text-fuchsia-300">
              session: {bbLaunch.session_id} → {bbLaunch.deep_link}
            </div>
          )}
        </div>
      )}

      {/* Lessons */}
      <div>
        <div className="text-[10px] tracking-[0.3em] uppercase text-zinc-500 mb-3">Lessons</div>
        <div className="grid gap-2">
          {track.lessons.map((l, i) => {
            const score = progress.quiz_scores?.[l.id];
            const done = completed.has(l.id);
            return (
              <button
                key={l.id}
                data-testid={`lesson-${l.id}`}
                onClick={() => onLesson(l.id)}
                className="w-full text-left flex items-center gap-3 border border-zinc-800 hover:border-cyan-400/40 bg-zinc-950 p-4 transition-colors group"
              >
                <div className={`w-8 h-8 flex items-center justify-center text-xs font-bold ${done ? 'bg-emerald-400/20 text-emerald-400' : 'bg-zinc-900 text-zinc-500'}`}>
                  {done ? <CheckCircle2 className="w-4 h-4" /> : i + 1}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="font-medium group-hover:text-cyan-400 transition-colors truncate">{l.title}</div>
                  <div className="text-xs text-zinc-500 truncate">{l.summary}</div>
                </div>
                <div className="text-right shrink-0">
                  {score !== undefined && <div className={`text-xs font-mono ${done ? 'text-emerald-400' : 'text-amber-400'}`}>{score}%</div>}
                  <div className="text-[10px] text-zinc-600">{l.duration_min} min · {l.question_count} q</div>
                </div>
                <ChevronRight className="w-4 h-4 text-zinc-700 group-hover:text-cyan-400" />
              </button>
            );
          })}
        </div>
      </div>

      {/* Kinesiology cert panel */}
      {trackId === "kinesiology" && eligibility && (
        <div className="border border-amber-400/30 bg-amber-400/5 p-5 space-y-3">
          <div className="flex items-center justify-between flex-wrap gap-3">
            <div className="flex items-center gap-2">
              <Crown className="w-5 h-5 text-amber-400" />
              <div className="font-bold">Applied Kinesiology Certificate</div>
            </div>
            {progress.certificate_issued ? (
              <div className="flex items-center gap-2 px-3 py-1 bg-amber-400/20 border border-amber-400/40 text-xs font-mono text-amber-300">
                <Sparkles className="w-3 h-3" /> {progress.certificate_id}
              </div>
            ) : (
              <button
                data-testid="claim-kinesiology-cert-btn"
                disabled={!eligibility.all_met || claiming}
                onClick={claimCert}
                className={`px-4 py-2 text-sm font-bold transition-colors ${eligibility.all_met ? 'bg-amber-400 text-black hover:bg-amber-300' : 'bg-zinc-900 text-zinc-600 cursor-not-allowed'}`}
              >
                {claiming ? <Loader2 className="w-4 h-4 animate-spin" /> : eligibility.all_met ? 'Claim Certificate' : 'Locked'}
              </button>
            )}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
            {Object.entries(eligibility.checks).map(([k, v]) => (
              <div key={k} data-testid={`elig-${k}`} className={`flex items-center gap-2 p-2 border ${v.met ? 'border-emerald-400/30 bg-emerald-400/5' : 'border-zinc-800 bg-zinc-950'}`}>
                {v.met ? <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" /> : <Lock className="w-4 h-4 text-zinc-600 shrink-0" />}
                <div className="min-w-0">
                  <div className={v.met ? 'text-emerald-300' : 'text-zinc-300'}>{k.replace(/_/g, ' ')}</div>
                  <div className="text-zinc-500 truncate">{v.detail}</div>
                </div>
              </div>
            ))}
          </div>

          {!progress.final_passed && (
            <button data-testid="open-final-assessment-btn" onClick={onFinal} className="w-full py-2 border border-amber-400/40 text-amber-400 hover:bg-amber-400/10 transition-colors text-sm font-medium">
              Take Final Assessment ({track.final_assessment.question_count} questions · 80% to pass)
            </button>
          )}

          {claimResult?.certificate_id && (
            <div className="p-3 bg-emerald-400/10 border border-emerald-400/40 text-xs text-emerald-300">
              ✓ Certificate issued: <span className="font-mono">{claimResult.certificate_id}</span> · +{claimResult.xp_earned} XP
            </div>
          )}
          {claimResult?.error && <div className="p-3 bg-red-400/10 border border-red-400/40 text-xs text-red-300">{typeof claimResult.error === 'string' ? claimResult.error : claimResult.error.message}</div>}
        </div>
      )}

      {/* Bio-Digital module helper for kinesiology */}
      {trackId === "kinesiology" && eligibility && !eligibility.checks.bio_digital_modules.met && (
        <BioDigitalQuickComplete onChange={refresh} />
      )}
    </div>
  );
};

// ============================================================
// LESSON RUNNER (quiz)
// ============================================================
const LessonRunner = ({ trackId, lessonId, onBack }) => {
  const [lesson, setLesson] = useState(null);
  const [answers, setAnswers] = useState({});
  const [result, setResult] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    axios.get(`${API}/education/tracks/${trackId}/lesson/${lessonId}`).then((r) => setLesson(r.data)).catch(console.error);
  }, [trackId, lessonId]);

  const submit = async () => {
    setSubmitting(true);
    try {
      const arr = lesson.quiz.map((_, i) => answers[i] ?? -1);
      const r = await axios.post(`${API}/education/tracks/${trackId}/lesson/${lessonId}/submit`, { answers: arr });
      setResult(r.data);
    } catch (e) { console.error(e); }
    finally { setSubmitting(false); }
  };

  if (!lesson) return <div className="flex items-center justify-center py-20"><Loader2 className="w-8 h-8 animate-spin text-cyan-400" /></div>;

  const allAnswered = lesson.quiz.every((_, i) => answers[i] !== undefined);

  return (
    <div className="space-y-5 fade-in max-w-3xl" data-testid={`lesson-runner-${lessonId}`}>
      <button data-testid="lesson-back-btn" onClick={onBack} className="flex items-center gap-2 text-sm text-zinc-400 hover:text-cyan-400">
        <ChevronLeft className="w-4 h-4" /> Back
      </button>
      <div>
        <div className="text-[10px] tracking-[0.4em] uppercase text-cyan-400/70">Lesson · {lesson.duration_min} min</div>
        <h2 className="text-3xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>{lesson.title}</h2>
        <p className="text-sm text-zinc-300 mt-2 leading-relaxed">{lesson.summary}</p>
      </div>

      <div className="space-y-4">
        {lesson.quiz.map((q, i) => (
          <div key={i} data-testid={`quiz-question-${i}`} className="border border-zinc-800 bg-zinc-950 p-4">
            <div className="text-xs text-zinc-500 mb-2">Q{i + 1}</div>
            <div className="font-medium mb-3">{q.q}</div>
            <div className="grid gap-2">
              {q.options.map((opt, j) => {
                const isPicked = answers[i] === j;
                const isCorrectAfter = result && result.results[i].correct_index === j;
                const isWrongPickAfter = result && isPicked && !result.results[i].correct;
                return (
                  <button
                    key={j}
                    data-testid={`q${i}-opt${j}`}
                    disabled={!!result}
                    onClick={() => setAnswers({ ...answers, [i]: j })}
                    className={`text-left p-2 text-sm border transition-colors ${
                      result
                        ? isCorrectAfter
                          ? 'border-emerald-400/50 bg-emerald-400/10 text-emerald-300'
                          : isWrongPickAfter
                          ? 'border-red-400/50 bg-red-400/10 text-red-300'
                          : 'border-zinc-800 text-zinc-400'
                        : isPicked
                        ? 'border-cyan-400 bg-cyan-400/10 text-cyan-100'
                        : 'border-zinc-800 hover:border-zinc-600'
                    }`}
                  >
                    <span className="font-mono text-xs text-zinc-500 mr-2">{String.fromCharCode(65 + j)}</span>
                    {opt}
                  </button>
                );
              })}
            </div>
          </div>
        ))}
      </div>

      {!result ? (
        <button
          data-testid="quiz-submit-btn"
          disabled={!allAnswered || submitting}
          onClick={submit}
          className={`w-full py-3 font-bold transition-colors ${allAnswered ? 'bg-cyan-400 text-black hover:bg-cyan-300' : 'bg-zinc-900 text-zinc-600 cursor-not-allowed'}`}
        >
          {submitting ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Submit Quiz'}
        </button>
      ) : (
        <div className={`p-5 border ${result.passed ? 'border-emerald-400/40 bg-emerald-400/5' : 'border-amber-400/40 bg-amber-400/5'}`} data-testid="quiz-result">
          <div className="flex items-center justify-between mb-2">
            <div className="font-bold">{result.passed ? 'Passed!' : 'Below threshold (75%)'}</div>
            <div className={`text-2xl font-black ${result.passed ? 'text-emerald-400' : 'text-amber-400'}`}>{result.score_pct}%</div>
          </div>
          <div className="text-xs text-zinc-400">{result.correct}/{result.total} correct {result.first_pass && `· +${result.xp_earned} XP earned`}</div>
          <button data-testid="quiz-done-btn" onClick={onBack} className="mt-4 px-4 py-2 bg-zinc-100 text-black text-sm font-bold hover:bg-white">Done</button>
        </div>
      )}
    </div>
  );
};

// ============================================================
// KINESIOLOGY FINAL ASSESSMENT
// ============================================================
const KinesiologyFinal = ({ onBack }) => {
  const [fa, setFa] = useState(null);
  const [answers, setAnswers] = useState({});
  const [result, setResult] = useState(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    axios.get(`${API}/education/kinesiology/final-assessment`).then((r) => setFa(r.data)).catch(console.error);
  }, []);

  const submit = async () => {
    setSubmitting(true);
    try {
      const arr = fa.questions.map((_, i) => answers[i] ?? -1);
      const r = await axios.post(`${API}/education/kinesiology/final-assessment/submit`, { answers: arr });
      setResult(r.data);
    } catch (e) { console.error(e); }
    finally { setSubmitting(false); }
  };

  if (!fa) return <div className="flex items-center justify-center py-20"><Loader2 className="w-8 h-8 animate-spin text-cyan-400" /></div>;
  const allAnswered = fa.questions.every((_, i) => answers[i] !== undefined);

  return (
    <div className="space-y-5 fade-in max-w-3xl" data-testid="kin-final-runner">
      <button data-testid="final-back-btn" onClick={onBack} className="flex items-center gap-2 text-sm text-zinc-400 hover:text-amber-400">
        <ChevronLeft className="w-4 h-4" /> Back
      </button>
      <div>
        <div className="text-[10px] tracking-[0.4em] uppercase text-amber-400/70">Final Assessment · {fa.pass_threshold_pct}% to pass</div>
        <h2 className="text-3xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>{fa.title}</h2>
      </div>

      <div className="space-y-3">
        {fa.questions.map((q, i) => (
          <div key={i} data-testid={`final-question-${i}`} className="border border-zinc-800 bg-zinc-950 p-4">
            <div className="text-xs text-zinc-500 mb-2">Q{i + 1}</div>
            <div className="font-medium mb-3">{q.q}</div>
            <div className="grid gap-2">
              {q.options.map((opt, j) => (
                <button
                  key={j}
                  data-testid={`final-q${i}-opt${j}`}
                  disabled={!!result}
                  onClick={() => setAnswers({ ...answers, [i]: j })}
                  className={`text-left p-2 text-sm border transition-colors ${
                    answers[i] === j ? 'border-amber-400 bg-amber-400/10 text-amber-100' : 'border-zinc-800 hover:border-zinc-600'
                  }`}
                >
                  <span className="font-mono text-xs text-zinc-500 mr-2">{String.fromCharCode(65 + j)}</span>{opt}
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>

      {!result ? (
        <button
          data-testid="final-submit-btn"
          disabled={!allAnswered || submitting}
          onClick={submit}
          className={`w-full py-3 font-bold ${allAnswered ? 'bg-amber-400 text-black hover:bg-amber-300' : 'bg-zinc-900 text-zinc-600 cursor-not-allowed'}`}
        >
          {submitting ? <Loader2 className="w-4 h-4 animate-spin mx-auto" /> : 'Submit Final Assessment'}
        </button>
      ) : (
        <div className={`p-5 border ${result.passed ? 'border-emerald-400/40 bg-emerald-400/5' : 'border-red-400/40 bg-red-400/5'}`} data-testid="final-result">
          <div className="flex items-center justify-between mb-1">
            <div className="font-bold">{result.passed ? 'Final Assessment Passed' : 'Below threshold'}</div>
            <div className={`text-2xl font-black ${result.passed ? 'text-emerald-400' : 'text-red-400'}`}>{result.score_pct}%</div>
          </div>
          <div className="text-xs text-zinc-400">{result.correct}/{result.total} correct</div>
          <button data-testid="final-done-btn" onClick={onBack} className="mt-3 px-4 py-2 bg-zinc-100 text-black text-sm font-bold hover:bg-white">Back to Track</button>
        </div>
      )}
    </div>
  );
};

// ============================================================
// BIO-DIGITAL QUICK COMPLETE (kinesiology gating helper)
// ============================================================
const BioDigitalQuickComplete = ({ onChange }) => {
  const [state, setState] = useState({ modules_completed: [], required: [] });
  const [busy, setBusy] = useState(null);

  useEffect(() => {
    axios.get(`${API}/system-scan/unified`).then((r) => {
      setState({
        modules_completed: r.data.academy.bio_digital.modules_completed,
        required: r.data.academy.bio_digital.modules_required,
      });
    }).catch(console.error);
  }, []);

  const complete = async (mid) => {
    setBusy(mid);
    try {
      const r = await axios.post(`${API}/education/bio-digital/complete-module`, { module_id: mid });
      setState({ modules_completed: r.data.modules_completed, required: r.data.required });
      if (onChange) onChange();
    } catch (e) { console.error(e); }
    finally { setBusy(null); }
  };

  const done = new Set(state.modules_completed);
  return (
    <div className="border border-cyan-400/30 bg-cyan-400/5 p-5" data-testid="bio-digital-quick-complete">
      <div className="font-bold flex items-center gap-2 mb-1"><Target className="w-4 h-4 text-cyan-400" /> Bio-Digital Mastery — Required for Cert</div>
      <div className="text-xs text-zinc-400 mb-3">Mark anatomy overlay modules as mastered after completing them in the live arena.</div>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
        {state.required.map((m) => {
          const isDone = done.has(m);
          return (
            <button
              key={m}
              data-testid={`bd-mod-${m}`}
              disabled={isDone || busy === m}
              onClick={() => complete(m)}
              className={`flex items-center justify-between p-2 text-sm border transition-colors ${
                isDone ? 'border-emerald-400/30 bg-emerald-400/5 text-emerald-300' : 'border-zinc-800 bg-zinc-950 hover:border-cyan-400/40'
              }`}
            >
              <span className="capitalize">{m.replace(/_/g, ' ')}</span>
              {isDone ? <CheckCircle2 className="w-4 h-4" /> : busy === m ? <Loader2 className="w-4 h-4 animate-spin" /> : <Zap className="w-4 h-4 text-zinc-600" />}
            </button>
          );
        })}
      </div>
    </div>
  );
};

// ============================================================
// SHARE PASS MODAL
// ============================================================
const SharePassModal = ({ userId, onClose }) => {
  const [meta, setMeta] = useState(null);
  const [copied, setCopied] = useState(false);
  const [bust] = useState(() => Date.now());
  const passUrl = `${BACKEND_URL}/api/system-scan/pass/${userId}.png`;
  const passUrlBust = `${passUrl}?t=${bust}`;

  useEffect(() => {
    axios.get(`${API}/system-scan/pass-meta/${userId}`).then((r) => setMeta(r.data)).catch(console.error);
  }, [userId]);

  const copyUrl = async () => {
    try {
      await navigator.clipboard.writeText(passUrl);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch (e) { console.error(e); }
  };

  return (
    <div
      data-testid="share-pass-modal"
      className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 fade-in"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-3xl bg-zinc-950 border border-cyan-400/30 p-6 space-y-5"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          data-testid="share-pass-close"
          onClick={onClose}
          className="absolute top-4 right-4 text-zinc-500 hover:text-white transition-colors"
          aria-label="Close"
        >
          <X className="w-5 h-5" />
        </button>

        <div>
          <div className="text-[10px] tracking-[0.4em] uppercase text-cyan-400">FEL OS · Pass</div>
          <h3 className="text-2xl font-black tracking-tight" style={{fontFamily:'Barlow Condensed'}}>SHARE YOUR ATHLETE PASS</h3>
          <p className="text-xs text-zinc-400 mt-1">Server-rendered. Public. Drives scouts back to your profile.</p>
        </div>

        <div className="border border-zinc-800 bg-black overflow-hidden">
          <img
            data-testid="share-pass-preview-img"
            src={passUrlBust}
            alt="FEL OS Pass"
            className="w-full block"
          />
        </div>

        {meta && (
          <div className="text-xs text-zinc-400 font-mono p-3 border border-zinc-800 bg-zinc-900/40 break-all">
            {meta.share_text}
          </div>
        )}

        <div className="flex flex-col sm:flex-row gap-2">
          <button
            data-testid="share-pass-copy"
            onClick={copyUrl}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-cyan-400 text-black font-bold text-sm hover:bg-cyan-300 transition-colors"
          >
            {copied ? <CheckCircle2 className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
            {copied ? 'Copied!' : 'Copy Public URL'}
          </button>
          <a
            data-testid="share-pass-download"
            href={passUrlBust}
            download={`fel-os-pass-${userId}.png`}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 border border-zinc-700 text-zinc-100 hover:border-cyan-400/40 hover:text-cyan-400 transition-colors text-sm font-bold"
          >
            <Download className="w-4 h-4" /> Download PNG
          </a>
        </div>
      </div>
    </div>
  );
};

export default FELOSDashboard;
