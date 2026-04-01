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
}

export interface StreamingState {
  connected: boolean;
  streamerConnected: boolean;
  playerId: string | null;
  activeMode: string | null;
  sessionId: string | null;
  latencyMs: number;
}

export type StreamingCommand = 
  | 'launch_mode'
  | 'exit_mode'
  | 'get_modes'
  | 'exercise_demo'
  | 'get_status'
  | 'set_prq'
  | 'toggle_hud';
