export interface GameMode {
  id: string;
  displayName: string;
  venue: string;
  category: string;
  icon?: string;
}

export interface Exercise {
  id: string;
  name: string;
  description: string;
  difficulty: number;
  targetMuscles: string[];
  sportRelevance: string[];
  prqBenefit: string;
  reps: number;
  sets: number;
  category: string;
  caloriesPerMinute: number;
}

export interface WorkoutProgram {
  id: string;
  name: string;
  description: string;
  durationWeeks: number;
  daysPerWeek: number;
  goal: string;
  level: string;
}

export type SubscriptionStatus =
  | 'free_trial'
  | 'active'
  | 'expired'
  | 'cancelled'
  | 'payment_failed'
  | 'grace_period';

export interface SubscriptionInfo {
  status: SubscriptionStatus;
  trialHoursRemaining: number;
  nextBillingDate: string | null;
  weeklyPrice: number;
}

export interface StreamingState {
  connected: boolean;
  streamerConnected: boolean;
  playerId: string | null;
  activeMode: string | null;
  sessionId: string | null;
  latencyMs: number;
  subscription: SubscriptionInfo;
}

export type StreamingCommand = 
  | 'launch_mode'
  | 'exit_mode'
  | 'get_modes'
  | 'exercise_demo'
  | 'get_status'
  | 'set_prq'
  | 'toggle_hud'
  | 'start_workout'
  | 'get_workouts'
  | 'get_subscription'
  | 'start_trial'
  | 'subscribe';
