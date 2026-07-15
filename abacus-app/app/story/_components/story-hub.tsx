'use client';

import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import Link from 'next/link';
import { ArrowLeft, Lock, Play, MessageSquare, ShoppingBag, Zap, Shield, Brain, ChevronRight, Sparkles } from 'lucide-react';
import { PRQ_ATTRS, type PrqAttr, prqScore, prqGrade } from '@/lib/prq';
import {
  CHAPTERS, MockCoachDataProvider, generateCoachDialogue, createDefaultProgress,
  isMissionUnlocked, getUnlockedMoves, getLockedMoves, COMBAT_MOVES,
  type StoryProgress, type WearableSnapshot, type CoachLine,
} from '@/lib/story-data';

const ATTR_LABELS: Record<string, string> = {
  strength: 'STR', speed: 'SPD', endurance: 'END', agility: 'AGI',
  power: 'PWR', flexibility: 'FLX', recovery: 'REC', mental: 'MNT',
};

function RadarChart({ attrs, size = 200 }: { attrs: Record<string, number>; size?: number }) {
  const cx = size / 2, cy = size / 2, r = size * 0.38;
  const count = PRQ_ATTRS.length;
  const points = PRQ_ATTRS.map((a, i) => {
    const angle = (Math.PI * 2 * i) / count - Math.PI / 2;
    const val = Math.min((attrs[a] ?? 0) / 100, 1);
    return { x: cx + Math.cos(angle) * r * val, y: cy + Math.sin(angle) * r * val, label: ATTR_LABELS[a] ?? a, angle, val: attrs[a] ?? 0 };
  });
  const gridLevels = [0.25, 0.5, 0.75, 1];
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="mx-auto">
      {gridLevels.map(lv => (
        <polygon key={lv} points={PRQ_ATTRS.map((_, i) => {
          const a = (Math.PI * 2 * i) / count - Math.PI / 2;
          return `${cx + Math.cos(a) * r * lv},${cy + Math.sin(a) * r * lv}`;
        }).join(' ')} fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth={1} />
      ))}
      <polygon points={points.map(p => `${p.x},${p.y}`).join(' ')} fill="rgba(0,229,255,0.15)" stroke="#00E5FF" strokeWidth={2} />
      {points.map((p, i) => (
        <g key={i}>
          <circle cx={p.x} cy={p.y} r={3} fill="#00E5FF" />
          <text x={cx + Math.cos(p.angle) * (r + 16)} y={cy + Math.sin(p.angle) * (r + 16)} textAnchor="middle" dominantBaseline="middle" fill="rgba(255,255,255,0.5)" fontSize={10} fontFamily="JetBrains Mono, monospace">{p.label}</text>
          <text x={cx + Math.cos(p.angle) * (r + 28)} y={cy + Math.sin(p.angle) * (r + 28)} textAnchor="middle" dominantBaseline="middle" fill="#00E5FF" fontSize={9} fontFamily="JetBrains Mono, monospace">{Math.round(p.val)}</text>
        </g>
      ))}
    </svg>
  );
}

export default function StoryHub() {
  const router = useRouter();
  const [profile, setProfile] = useState<any>(null);
  const [education, setEducation] = useState<string[]>([]);
  const [coachLines, setCoachLines] = useState<CoachLine[]>([]);
  const [progress, setProgress] = useState<StoryProgress>(createDefaultProgress());
  const [coachIdx, setCoachIdx] = useState(0);
  const [showMoves, setShowMoves] = useState(false);

  useEffect(() => {
    // Load profile
    fetch('/api/profile').then(r => r.ok ? r.json() : null).then(j => {
      if (j?.profile) setProfile(j);
      else router.replace('/login');
    }).catch(() => {});
    // Load education progress
    fetch('/api/education').then(r => r.ok ? r.json() : null).then(j => {
      if (j?.completed) setEducation(j.completed);
    }).catch(() => {});
    // Load story progress from localStorage
    try {
      const saved = localStorage.getItem('fel-story-progress');
      if (saved) setProgress(JSON.parse(saved));
    } catch {}
  }, [router]);

  // Generate coach dialogue once profile loads
  useEffect(() => {
    if (!profile?.profile) return;
    const coach = new MockCoachDataProvider(profile.profile.streakDays ?? 0);
    coach.getSnapshot().then(snap => {
      const attrs = profile.profile;
      const weakest = PRQ_ATTRS.reduce((w, a) => (attrs[a] ?? 0) < (attrs[w] ?? 999) ? a : w, PRQ_ATTRS[0]);
      setCoachLines(generateCoachDialogue(snap, profile.prq ?? 50, weakest));
    });
  }, [profile]);

  if (!profile) return <div className="flex min-h-screen items-center justify-center bg-[#050505]"><Sparkles className="h-8 w-8 animate-spin text-[#00E5FF]" /></div>;

  const attrs = profile.profile ?? {};
  const score = profile.prq ?? 50;
  const grade = profile.grade ?? prqGrade(score);
  const chapter = CHAPTERS[progress.currentChapter - 1] ?? CHAPTERS[0];
  const lessonsComplete = education.length;
  const unlockedMoves = getUnlockedMoves(education);
  const lockedMoves = getLockedMoves(education);
  const weakest = PRQ_ATTRS.reduce((w, a) => (attrs[a] ?? 0) < (attrs[w] ?? 999) ? a : w, PRQ_ATTRS[0]);

  // Check chapter gate
  const gateOpen = score >= chapter.gateMinPrq && lessonsComplete >= chapter.gateMinLessons;

  const advanceCoach = () => setCoachIdx(i => (i + 1) % Math.max(coachLines.length, 1));

  const completeMission = (missionId: string) => {
    const updated = { ...progress, completedMissions: [...progress.completedMissions, missionId] };
    setProgress(updated);
    try { localStorage.setItem('fel-story-progress', JSON.stringify(updated)); } catch {}
  };

  return (
    <div className="min-h-screen bg-[#050505]">
      {/* Header */}
      <header className="sticky top-0 z-40 border-b border-white/10 bg-[#050505]/85 backdrop-blur-md">
        <div className="mx-auto flex max-w-[1200px] items-center gap-3 px-4 py-2.5">
          <Link href="/" className="flex items-center gap-1.5 rounded-md border border-white/10 px-2.5 py-1.5 text-xs font-medium text-white/60 transition-colors hover:border-[#00E5FF]/50 hover:text-[#00E5FF]">
            <ArrowLeft className="h-3.5 w-3.5" /> HUB
          </Link>
          <div>
            <h1 className="fel-heading text-xl font-bold leading-none text-white">THE NEXUS INITIATIVE</h1>
            <p className="font-mono text-[10px] text-white/55">STORY MODE · CHAPTER {chapter.id}: {chapter.title.toUpperCase()}</p>
          </div>
          <span className="ml-auto rounded-md border px-2.5 py-1 font-mono text-xs" style={{ borderColor: `${grade.color}55`, color: grade.color }}>
            PRQ {Math.round(score)} · {grade.label}
          </span>
        </div>
      </header>

      <div className="mx-auto max-w-[1200px] px-4 py-6">
        {/* Training Sanctum */}
        <div className="grid gap-6 lg:grid-cols-3">
          {/* PRQ Radar */}
          <div className="fel-panel rounded-xl p-5">
            <h2 className="fel-heading text-lg font-bold text-white">TRAINING SANCTUM</h2>
            <p className="mt-1 font-mono text-[10px] text-white/55">PRQ ANALYSIS · {PRQ_ATTRS.length} ATTRIBUTES</p>
            <RadarChart attrs={attrs} size={220} />
            <div className="mt-3 text-center">
              <span className="font-mono text-2xl font-bold" style={{ color: grade.color }}>{Math.round(score)}</span>
              <span className="ml-2 text-sm text-white/50">PRQ · {grade.label}</span>
            </div>
            <div className="mt-2 text-center font-mono text-[10px] text-white/50">
              Weakest: <span className="text-[#FF3366]">{ATTR_LABELS[weakest]} ({Math.round(attrs[weakest] ?? 0)})</span>
            </div>
          </div>

          {/* Coach Panel */}
          <div className="fel-panel rounded-xl p-5">
            <div className="flex items-center gap-2">
              <MessageSquare className="h-4 w-4 text-[#00E5FF]" />
              <h2 className="fel-heading text-lg font-bold text-white">COACH</h2>
            </div>
            <p className="mt-1 font-mono text-[10px] text-white/55">ADAPTIVE GUIDANCE · WEARABLE DATA</p>
            <div className="mt-4 min-h-[120px] rounded-lg border border-white/5 bg-black/30 p-4">
              {coachLines.length > 0 ? (
                <AnimatePresence mode="wait">
                  <motion.div key={coachIdx} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }}>
                    <p className="text-sm leading-relaxed text-white/80">
                      "{coachLines[coachIdx % coachLines.length]?.text}"
                    </p>
                    <p className="mt-2 font-mono text-[10px] text-white/50">
                      TONE: {coachLines[coachIdx % coachLines.length]?.tone?.toUpperCase()}
                    </p>
                  </motion.div>
                </AnimatePresence>
              ) : <p className="text-sm text-white/55">Loading coach data…</p>}
            </div>
            <button onClick={advanceCoach} className="mt-3 w-full rounded-md border border-white/10 py-2 text-xs font-medium text-white/60 transition hover:border-[#00E5FF]/50 hover:text-[#00E5FF]">
              NEXT INSIGHT <ChevronRight className="ml-1 inline h-3 w-3" />
            </button>
          </div>

          {/* Progress & Moves */}
          <div className="fel-panel rounded-xl p-5">
            <div className="flex items-center gap-2">
              <Zap className="h-4 w-4 text-[#FFD700]" />
              <h2 className="fel-heading text-lg font-bold text-white">COMBAT MOVES</h2>
            </div>
            <p className="mt-1 font-mono text-[10px] text-white/55">{unlockedMoves.length}/{COMBAT_MOVES.length} UNLOCKED · SKILL LAB MASTERY</p>
            <div className="mt-3 space-y-2">
              {unlockedMoves.slice(0, 3).map(m => (
                <div key={m.id} className="flex items-center gap-2 rounded-md border border-[#00FF9D]/20 bg-[#00FF9D]/5 px-3 py-2">
                  <Shield className="h-3.5 w-3.5 text-[#00FF9D]" />
                  <div className="flex-1">
                    <span className="text-xs font-bold text-[#00FF9D]">{m.name}</span>
                    <span className="ml-2 font-mono text-[10px] text-white/55">{m.type.toUpperCase()} · {m.damage} DMG</span>
                  </div>
                </div>
              ))}
              {lockedMoves.slice(0, 2).map(m => (
                <div key={m.id} className="flex items-center gap-2 rounded-md border border-white/5 bg-white/[0.02] px-3 py-2 opacity-50">
                  <Lock className="h-3.5 w-3.5 text-white/50" />
                  <div className="flex-1">
                    <span className="text-xs font-medium text-white/55">{m.name}</span>
                    <span className="ml-2 font-mono text-[10px] text-white/50">LOCKED</span>
                  </div>
                </div>
              ))}
            </div>
            <Link href="/education" className="mt-3 block w-full rounded-md border border-white/10 py-2 text-center text-xs font-medium text-white/60 transition hover:border-[#A855F7]/50 hover:text-[#A855F7]">
              SKILL LAB → UNLOCK MORE
            </Link>
          </div>
        </div>

        {/* Chapter Gate */}
        {!gateOpen && (
          <div className="mt-6 rounded-xl border border-[#FF3366]/30 bg-[#FF3366]/5 p-4 text-center">
            <Lock className="mx-auto h-5 w-5 text-[#FF3366]" />
            <p className="mt-2 text-sm font-medium text-[#FF3366]">
              Chapter {chapter.id} requires PRQ ≥ {chapter.gateMinPrq} (yours: {Math.round(score)}) and {chapter.gateMinLessons}+ lessons (yours: {lessonsComplete}).
            </p>
            <p className="mt-1 font-mono text-[10px] text-white/55">Train in game modes and complete Skill Lab lessons to advance.</p>
          </div>
        )}

        {/* Mission List */}
        <div className="mt-6">
          <h2 className="fel-heading text-xl font-bold text-white">CHAPTER {chapter.id}: {chapter.title.toUpperCase()}</h2>
          <p className="mt-1 text-sm text-white/50">{chapter.subtitle}</p>
          <div className="mt-4 space-y-3">
            {chapter.missions.map((m, i) => {
              const unlocked = gateOpen && isMissionUnlocked(progress, m.id, chapter);
              const completed = progress.completedMissions.includes(m.id);
              const icon = m.type === 'traversal' ? Zap : m.type === 'boss' ? Shield : m.type === 'marketplace' ? ShoppingBag : Brain;
              const Icon = icon;
              const href = m.type === 'traversal' ? '/story/rail' : m.type === 'boss' ? '/story/boss' : m.type === 'marketplace' ? '/shop' : '#';
              return (
                <motion.div key={m.id} initial={{ opacity: 0, x: -16 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.08 }}>
                  {unlocked && !completed ? (
                    <Link href={href} className="group flex items-center gap-4 rounded-xl border border-white/10 bg-white/[0.02] p-4 transition hover:border-[#00E5FF]/40 hover:bg-[#00E5FF]/5">
                      <div className="flex h-10 w-10 items-center justify-center rounded-lg" style={{ background: `${chapter.accent}15`, border: `1px solid ${chapter.accent}33` }}>
                        <Icon className="h-5 w-5" style={{ color: chapter.accent }} />
                      </div>
                      <div className="flex-1">
                        <h3 className="text-sm font-bold text-white">{m.title}</h3>
                        <p className="text-xs text-white/55">{m.description}</p>
                      </div>
                      <Play className="h-5 w-5 text-[#00E5FF] opacity-0 transition group-hover:opacity-100" />
                    </Link>
                  ) : (
                    <div className={`flex items-center gap-4 rounded-xl border p-4 ${completed ? 'border-[#00FF9D]/30 bg-[#00FF9D]/5' : 'border-white/5 bg-white/[0.01] opacity-40'}`}>
                      <div className="flex h-10 w-10 items-center justify-center rounded-lg border border-white/10 bg-white/5">
                        {completed ? <Sparkles className="h-5 w-5 text-[#00FF9D]" /> : <Lock className="h-5 w-5 text-white/50" />}
                      </div>
                      <div className="flex-1">
                        <h3 className="text-sm font-bold text-white/60">{m.title}</h3>
                        <p className="text-xs text-white/50">{completed ? 'COMPLETED' : m.description}</p>
                      </div>
                    </div>
                  )}
                </motion.div>
              );
            })}
          </div>
        </div>

        {/* Future Chapters Preview */}
        <div className="mt-8">
          <h3 className="fel-heading text-sm font-bold text-white/55">UPCOMING CHAPTERS</h3>
          <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {CHAPTERS.filter(c => !c.available).map(c => (
              <div key={c.id} className="rounded-xl border border-white/5 bg-white/[0.01] p-4 opacity-50">
                <div className="flex items-center gap-2">
                  <Lock className="h-3.5 w-3.5 text-white/50" />
                  <span className="text-xs font-bold text-white/55">CH.{c.id}</span>
                </div>
                <h4 className="mt-1 text-sm font-bold" style={{ color: `${c.accent}CC` }}>{c.title}</h4>
                <p className="mt-0.5 font-mono text-[10px] text-white/50">PRQ ≥{c.gateMinPrq} · {c.gateMinLessons} lessons</p>
              </div>
            ))}
          </div>
        </div>

        {/* Economy tie-in */}
        <div className="mt-6 rounded-xl border border-[#FFD700]/20 bg-[#FFD700]/5 p-4">
          <div className="flex items-center gap-2">
            <ShoppingBag className="h-4 w-4 text-[#FFD700]" />
            <span className="text-xs font-bold text-[#FFD700]">MARKETPLACE DISTRICT</span>
          </div>
          <p className="mt-1 text-xs text-white/50">Creator Cards upgrade your combat abilities. Visit the shop to power up.</p>
          <Link href="/shop" className="mt-2 inline-block rounded-md border border-[#FFD700]/30 px-4 py-1.5 text-xs font-bold text-[#FFD700] transition hover:bg-[#FFD700]/10">
            ENTER MARKETPLACE
          </Link>
        </div>
      </div>
    </div>
  );
}
