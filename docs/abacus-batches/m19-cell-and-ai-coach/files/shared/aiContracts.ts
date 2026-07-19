// M19 — shared AI contracts.

export type PersonaId = 'coach' | 'cell';

export interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  at: string;                          // ISO
}

export interface ChatRequest {
  persona: PersonaId;
  message: string;
  threadId?: string;                   // continue a thread; omit to start one
  /** Optional surface hint so replies fit the moment. */
  surface?: 'coach_tab' | 'plan_viewer' | 'result_screen' | 'hub' | 'nexus_boss';
  /** Structured event for auto-lines (Cell post-game), not free text. */
  event?: SessionEvent;
}

export interface SessionEvent {
  modeId: string;
  outcome: string;                     // 'GREAT' | 'TACKLED_17YD' | 'WAVE_6' ...
  score: number;
  personalBest: boolean;
}

export interface ChatResponse {
  threadId: string;
  reply: string;                       // full text (streaming sends chunks first)
  capRemaining: number;
}

/** Grounding context assembled server-side — the model sees a compact digest. */
export interface GroundingContext {
  handle: string;
  prq: number;
  metrics?: Partial<Record<'strength'|'speed'|'endurance'|'agility'|'power'|'flexibility'|'recovery'|'mental', number>>;
  screenSummary?: string;              // movement screen summary line (M17)
  deficits?: string[];
  todayPlanDay?: string;               // 'W2 Day 1 — hip mobility + trunk control'
  lastSessions?: { modeId: string; outcome: string; score: number }[];
  biofuel?: { intent: string; pctCalories: number };
  streakDays?: number;
  isMinor: boolean;
}

/** Quick-action chips per persona/surface. */
export const QUICK_ACTIONS: Record<PersonaId, { label: string; message: string }[]> = {
  coach: [
    { label: 'Today’s focus', message: 'What should I train today and why?' },
    { label: 'Fix my form', message: 'What does my last scan say I should fix first?' },
    { label: 'Fuel check', message: 'How am I doing on nutrition today?' },
    { label: 'Too sore', message: 'I’m sore — should I still do today’s session?' },
  ],
  cell: [
    { label: 'Run it back', message: 'Think I can’t beat that score? Watch.' },
    { label: 'Daily challenge', message: 'Give me today’s challenge.' },
    { label: 'Talk your talk', message: 'Rate my last game. Be honest.' },
  ],
};

export const DAILY_MESSAGE_CAP = 40;   // per user across both personas
