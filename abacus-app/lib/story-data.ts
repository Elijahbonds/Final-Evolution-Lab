/**
 * Story Mode: The Nexus Initiative — data, interfaces, and chapter definitions.
 * v1 ships Chapter 1 (The Awakening) as a playable slice.
 * Chapters 2-5 are defined but gated behind "coming soon" checks.
 */

import type { PrqAttr } from '@/lib/prq';

/* ─── Wearable / Coach data provider ─── */
export interface WearableSnapshot {
  sleepHours: number;       // 0-12
  recoveryScore: number;    // 0-100
  restingHR: number;        // bpm
  trainingLoad: number;     // 0-100 (7-day rolling)
  lastWorkout: string;      // ISO date or 'none'
  streak: number;           // consecutive active days
}

export interface CoachDataProvider {
  getSnapshot(): Promise<WearableSnapshot>;
  isAvailable(): boolean;
}

export class MockCoachDataProvider implements CoachDataProvider {
  private streak: number;
  constructor(streak = 0) { this.streak = streak; }
  isAvailable() { return true; }
  async getSnapshot(): Promise<WearableSnapshot> {
    // Seeded mock data based on streak
    const baseRecovery = Math.min(40 + this.streak * 6, 92);
    return {
      sleepHours: 5.5 + Math.random() * 3,
      recoveryScore: baseRecovery + (Math.random() - 0.5) * 15,
      restingHR: 58 + Math.random() * 12,
      trainingLoad: Math.min(20 + this.streak * 8, 85),
      lastWorkout: this.streak > 0 ? new Date(Date.now() - 86400000).toISOString() : 'none',
      streak: this.streak,
    };
  }
}

/* ─── Coach dialogue generator ─── */
export interface CoachLine {
  text: string;
  tone: 'encourage' | 'caution' | 'celebrate' | 'neutral';
}

export function generateCoachDialogue(snap: WearableSnapshot, prq: number, weakestStat: PrqAttr): CoachLine[] {
  const lines: CoachLine[] = [];

  // Recovery-adaptive (NEVER shaming)
  if (snap.recoveryScore < 40) {
    lines.push({ text: "Rest is part of training. Let's focus on precision today — your body will thank you.", tone: 'caution' });
  } else if (snap.recoveryScore < 60) {
    lines.push({ text: "Let's go lighter today, champ. Smart athletes know when to recover.", tone: 'caution' });
  } else if (snap.recoveryScore >= 80) {
    lines.push({ text: "You're fueled up — let's push the ceiling. I can feel the energy.", tone: 'celebrate' });
  } else {
    lines.push({ text: "Solid recovery. Time to put in the work.", tone: 'neutral' });
  }

  // Sleep-adaptive
  if (snap.sleepHours < 6) {
    lines.push({ text: "Looks like a short night. We'll keep the intensity smart — technique over power.", tone: 'caution' });
  } else if (snap.sleepHours >= 8) {
    lines.push({ text: "Well-rested. Your reaction time should be dialed in today.", tone: 'encourage' });
  }

  // Streak-adaptive
  if (snap.streak >= 7) {
    lines.push({ text: `${snap.streak}-day streak! Consistency builds champions. Keep showing up.`, tone: 'celebrate' });
  } else if (snap.streak >= 3) {
    lines.push({ text: `${snap.streak} days strong. The compound effect is kicking in.`, tone: 'encourage' });
  } else if (snap.streak === 0) {
    lines.push({ text: "Welcome back. Every session is a fresh start — no judgments here.", tone: 'neutral' });
  }

  // PRQ-adaptive
  if (prq >= 80) {
    lines.push({ text: "ELITE tier. You're in the top percentile. Let's see how far we can stretch it.", tone: 'celebrate' });
  } else if (prq >= 60) {
    lines.push({ text: "PRIMED and climbing. Your weakest link is " + weakestStat + " — we'll target that.", tone: 'encourage' });
  } else if (prq >= 40) {
    lines.push({ text: "Building your foundation. Focus on " + weakestStat + " today — that's where the biggest gains are.", tone: 'neutral' });
  } else {
    lines.push({ text: "Everyone starts somewhere. Let's build one rep at a time.", tone: 'encourage' });
  }

  return lines;
}

/* ─── Boss System ─── */
export interface BossPhase {
  name: string;
  mechanic: 'dodge' | 'combo' | 'qte' | 'endurance';
  duration: number;   // seconds
  difficulty: number;  // 1-10
}

export interface GlitchBoss {
  id: string;
  name: string;
  chapter: number;
  targetStat: PrqAttr;
  bossStrength: number;  // scales inversely to player's stat
  phases: BossPhase[];
  defeatCondition: string;
  accent: string;
}

export function createGlitchBoss(weakestStat: PrqAttr, weakestValue: number): GlitchBoss {
  const strength = Math.max(10, 90 - weakestValue);  // weaker player → stronger boss
  return {
    id: 'vertigo',
    name: 'THE VERTIGO',
    chapter: 1,
    targetStat: weakestStat,
    bossStrength: strength,
    accent: '#FF3366',
    phases: [
      { name: 'DODGE STORM', mechanic: 'dodge', duration: 15, difficulty: Math.ceil(strength / 15) },
      { name: 'COMBO BREAK', mechanic: 'combo', duration: 20, difficulty: Math.ceil(strength / 12) },
      { name: 'AERIAL FINISHER', mechanic: 'qte', duration: 12, difficulty: Math.ceil(strength / 10) },
    ],
    defeatCondition: `Defeat all 3 phases. Boss strength scales with your weakest stat (${weakestStat}: ${weakestValue}).`,
  };
}

/* ─── Skill-to-Combat Mapping ─── */
export interface CombatMove {
  id: string;
  name: string;
  type: 'opener' | 'chain' | 'finisher' | 'counter' | 'ultimate';
  requiredLesson: string;   // trackKey/lessonKey
  damage: number;
  description: string;
}

export const COMBAT_MOVES: CombatMove[] = [
  { id: 'quick-strike', name: 'Quick Strike', type: 'opener', requiredLesson: 'karate-fundamentals/l1', damage: 8, description: 'Fast jab opener — unlocked by mastering The Jab.' },
  { id: 'heavy-finisher', name: 'Heavy Finisher', type: 'finisher', requiredLesson: 'karate-fundamentals/l2', damage: 18, description: 'Powerful kick finisher — from Kick mastery.' },
  { id: 'dodge-counter', name: 'Dodge Counter', type: 'counter', requiredLesson: 'karate-fundamentals/l1', damage: 12, description: 'Perfect dodge into counter — from Block Cone mastery.' },
  { id: 'aerial-launcher', name: 'Aerial Launcher', type: 'chain', requiredLesson: 'dunk-fundamentals/l1', damage: 14, description: 'Launch into air combo — from Charge Mechanics.' },
  { id: 'air-combo', name: 'Air Combo Extension', type: 'chain', requiredLesson: 'dunk-fundamentals/l2', damage: 10, description: 'Extend air time for extra hits — from Hang Time Physics.' },
  { id: 'neural-ultimate', name: 'Neural Burst Strike', type: 'ultimate', requiredLesson: 'karate-fundamentals/l3', damage: 30, description: 'Devastating special — from The Special mastery.' },
];

export function getUnlockedMoves(completedLessons: string[]): CombatMove[] {
  return COMBAT_MOVES.filter(m => completedLessons.includes(m.requiredLesson));
}

export function getLockedMoves(completedLessons: string[]): CombatMove[] {
  return COMBAT_MOVES.filter(m => !completedLessons.includes(m.requiredLesson));
}

/* ─── Chapter definitions ─── */
export interface ChapterMission {
  id: string;
  type: 'traversal' | 'boss' | 'sanctum' | 'marketplace';
  title: string;
  description: string;
}

export interface Chapter {
  id: number;
  title: string;
  subtitle: string;
  accent: string;
  gateMinPrq: number;
  gateMinLessons: number;
  missions: ChapterMission[];
  available: boolean;  // v1: only chapter 1
}

export const CHAPTERS: Chapter[] = [
  {
    id: 1,
    title: 'The Awakening',
    subtitle: 'Fundamentals — discover your potential',
    accent: '#00E5FF',
    gateMinPrq: 30,
    gateMinLessons: 2,
    available: true,
    missions: [
      { id: '1-sanctum', type: 'sanctum', title: 'Training Sanctum', description: 'Review your PRQ stats and speak with the Coach.' },
      { id: '1-rail', type: 'traversal', title: 'Nexus Rail', description: 'Grind the rail to the Arena District. Collect orbs and dodge obstacles.' },
      { id: '1-boss', type: 'boss', title: 'The Vertigo', description: 'Face the Glitch — a boss born from your weakest stat.' },
      { id: '1-market', type: 'marketplace', title: 'Marketplace District', description: 'Upgrade your abilities with Creator Cards.' },
    ],
  },
  {
    id: 2,
    title: 'The Glitch',
    subtitle: 'Adaptability — the system fights back',
    accent: '#FF3366',
    gateMinPrq: 45,
    gateMinLessons: 6,
    available: false,
    missions: [
      { id: '2-sanctum', type: 'sanctum', title: 'Training Sanctum', description: 'Prepare for the Glitch.' },
      { id: '2-rail', type: 'traversal', title: 'Corrupted Rail', description: 'Navigate glitching rail segments.' },
      { id: '2-boss', type: 'boss', title: 'The Fracture', description: 'A boss that mirrors your attack patterns.' },
    ],
  },
  {
    id: 3,
    title: 'Rising Tide',
    subtitle: 'Team dynamics — strength in numbers',
    accent: '#00FF9D',
    gateMinPrq: 55,
    gateMinLessons: 9,
    available: false,
    missions: [
      { id: '3-sanctum', type: 'sanctum', title: 'Training Sanctum', description: 'Rally your team.' },
      { id: '3-rail', type: 'traversal', title: 'Storm Rail', description: 'Team traversal challenge.' },
      { id: '3-boss', type: 'boss', title: 'The Tide', description: 'Endurance boss — outlast the waves.' },
    ],
  },
  {
    id: 4,
    title: 'Mastery Lab',
    subtitle: 'Peak performance — prove your readiness',
    accent: '#A855F7',
    gateMinPrq: 70,
    gateMinLessons: 12,
    available: false,
    missions: [
      { id: '4-sanctum', type: 'sanctum', title: 'Training Sanctum', description: 'Final preparations.' },
      { id: '4-rail', type: 'traversal', title: 'Precision Rail', description: 'Zero-error traversal gauntlet.' },
      { id: '4-boss', type: 'boss', title: 'The Mirror', description: 'Fight your own perfect clone.' },
    ],
  },
  {
    id: 5,
    title: 'The Nexus Core',
    subtitle: 'Synthesis — become the evolution',
    accent: '#FFD700',
    gateMinPrq: 80,
    gateMinLessons: 12,
    available: false,
    missions: [
      { id: '5-sanctum', type: 'sanctum', title: 'Final Sanctum', description: 'The last conversation with your Coach.' },
      { id: '5-rail', type: 'traversal', title: 'Nexus Rail', description: 'The ultimate run — all mechanics combined.' },
      { id: '5-boss', type: 'boss', title: 'The Nexus', description: 'The system itself. Every stat matters.' },
    ],
  },
];

/* ─── Story progress (client-side for v1, DB model in future) ─── */
export interface StoryProgress {
  currentChapter: number;
  completedMissions: string[];  // mission ids
  bossDefeated: string[];       // boss ids
  bestBossScore: Record<string, number>;
}

export function createDefaultProgress(): StoryProgress {
  return { currentChapter: 1, completedMissions: [], bossDefeated: [], bestBossScore: {} };
}

export function isMissionUnlocked(progress: StoryProgress, missionId: string, chapter: Chapter): boolean {
  const idx = chapter.missions.findIndex(m => m.id === missionId);
  if (idx <= 0) return true;  // first mission always unlocked
  // previous mission must be completed
  const prev = chapter.missions[idx - 1];
  return progress.completedMissions.includes(prev.id);
}

/* ─── Nexus mode registration ─── */
export const STORY_MODE_KEY = 'storyMode';
