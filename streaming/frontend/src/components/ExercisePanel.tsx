import React, { useState } from 'react';
import type { StreamingState, StreamingCommand, Exercise } from '../types';

const EXERCISES: Exercise[] = [
  { id: 'dynamic_lunge_walk', name: 'Dynamic Lunge Walk', description: 'Walking lunges with torso rotation', difficulty: 0.3, targetMuscles: ['hip_flexors', 'glutes'], sportRelevance: ['basketball_h2h', 'soccer', 'football'], prqBenefit: 'hip_mobility', reps: 10, sets: 2 },
  { id: 'squat_form', name: 'Perfect Form Squat', description: 'Full-depth bodyweight squat with form focus', difficulty: 0.4, targetMuscles: ['quadriceps', 'glutes', 'core'], sportRelevance: ['basketball_dunk', 'volleyball', 'gymnastics'], prqBenefit: 'lower_body_strength', reps: 12, sets: 3 },
  { id: 'box_jump', name: 'Box Jump', description: 'Explosive vertical jump with soft landing', difficulty: 0.6, targetMuscles: ['quadriceps', 'glutes', 'calves'], sportRelevance: ['basketball_dunk', 'volleyball'], prqBenefit: 'vertical_power', reps: 8, sets: 3 },
  { id: 'hip_90_90', name: '90/90 Hip Rotation', description: 'Seated hip rotation for mobility', difficulty: 0.3, targetMuscles: ['hip_rotators', 'glutes'], sportRelevance: ['soccer', 'karate_h2h', 'gymnastics'], prqBenefit: 'hip_mobility', reps: 8, sets: 2 },
  { id: 'dunk_approach', name: 'Dunk Approach Pattern', description: 'Sprint \u2192 gather \u2192 leap timing drill', difficulty: 0.7, targetMuscles: ['hip_flexors', 'glutes', 'calves'], sportRelevance: ['basketball_dunk'], prqBenefit: 'dunk_mechanics', reps: 6, sets: 3 },
  { id: 'golf_swing_drill', name: 'Golf Swing Plane', description: 'Slow-motion swing focus on plane', difficulty: 0.5, targetMuscles: ['obliques', 'hip_rotators'], sportRelevance: ['golf', 'baseball'], prqBenefit: 'swing_plane', reps: 10, sets: 3 },
  { id: 'karate_kata_basic', name: 'Basic Kata Sequence', description: 'Foundational strikes, blocks, stances', difficulty: 0.5, targetMuscles: ['core', 'hip_rotators'], sportRelevance: ['karate_h2h'], prqBenefit: 'strike_precision', reps: 1, sets: 3 },
  { id: 'surf_popup', name: 'Surf Pop-Up Drill', description: 'Prone to standing for takeoff speed', difficulty: 0.4, targetMuscles: ['core', 'shoulders'], sportRelevance: ['surfing', 'skateboarding'], prqBenefit: 'popup_speed', reps: 10, sets: 3 },
  { id: 'balance_board', name: 'Balance Board Training', description: 'Single-leg balance for proprioception', difficulty: 0.4, targetMuscles: ['ankles', 'core'], sportRelevance: ['surfing', 'skateboarding', 'snowboarding'], prqBenefit: 'balance_proprioception', reps: 0, sets: 4 },
  { id: 'serve_motion', name: 'Tennis Serve Motion', description: 'Full kinetic chain serve drill', difficulty: 0.6, targetMuscles: ['shoulders', 'core'], sportRelevance: ['tennis', 'volleyball'], prqBenefit: 'serve_mechanics', reps: 8, sets: 3 },
  { id: 'kick_form', name: 'Soccer Kick Form', description: 'Plant foot positioning and follow-through', difficulty: 0.5, targetMuscles: ['hip_flexors', 'quadriceps'], sportRelevance: ['soccer', 'football'], prqBenefit: 'kick_accuracy', reps: 8, sets: 3 },
  { id: 'tumbling_roundoff', name: 'Gymnastics Roundoff', description: 'Roundoff entry for tumbling passes', difficulty: 0.7, targetMuscles: ['shoulders', 'core'], sportRelevance: ['gymnastics'], prqBenefit: 'tumbling_form', reps: 6, sets: 3 },
  { id: 'breathing_box', name: 'Box Breathing', description: '4-4-4-4 breathing for recovery', difficulty: 0.1, targetMuscles: ['diaphragm'], sportRelevance: ['brain_brawl', 'golf'], prqBenefit: 'parasympathetic_recovery', reps: 0, sets: 1 },
];

interface Props {
  onBack: () => void;
  sendCommand: (cmd: StreamingCommand, payload?: Record<string, unknown>) => void;
  state: StreamingState;
}

export function ExercisePanel({ onBack, sendCommand, state }: Props) {
  const [activeExercise, setActiveExercise] = useState<string | null>(null);
  const [sportFilter, setSportFilter] = useState<string>('all');

  const filtered = sportFilter === 'all'
    ? EXERCISES
    : EXERCISES.filter(e => e.sportRelevance.includes(sportFilter));

  const playDemo = (exerciseId: string) => {
    setActiveExercise(exerciseId);
    sendCommand('exercise_demo', { exercise_id: exerciseId });
  };

  const getDifficultyLabel = (d: number) => {
    if (d <= 0.2) return { text: 'Easy', color: '#4ade80' };
    if (d <= 0.4) return { text: 'Moderate', color: '#facc15' };
    if (d <= 0.6) return { text: 'Challenging', color: '#fb923c' };
    return { text: 'Advanced', color: '#f87171' };
  };

  return (
    <div className="exercise-panel">
      <header className="exercise-header">
        <button className="btn-back" onClick={onBack}>\u2190 Back</button>
        <h2>3D Exercise Demonstrations</h2>
        <p className="subtitle">{EXERCISES.length} exercises · PRQ-optimized · 3D animated</p>
      </header>

      <div className="sport-filter">
        <button className={sportFilter === 'all' ? 'active' : ''} onClick={() => setSportFilter('all')}>All</button>
        <button className={sportFilter === 'basketball_dunk' ? 'active' : ''} onClick={() => setSportFilter('basketball_dunk')}>Basketball</button>
        <button className={sportFilter === 'soccer' ? 'active' : ''} onClick={() => setSportFilter('soccer')}>Soccer</button>
        <button className={sportFilter === 'tennis' ? 'active' : ''} onClick={() => setSportFilter('tennis')}>Tennis</button>
        <button className={sportFilter === 'karate_h2h' ? 'active' : ''} onClick={() => setSportFilter('karate_h2h')}>Karate</button>
        <button className={sportFilter === 'golf' ? 'active' : ''} onClick={() => setSportFilter('golf')}>Golf</button>
        <button className={sportFilter === 'surfing' ? 'active' : ''} onClick={() => setSportFilter('surfing')}>Board Sports</button>
        <button className={sportFilter === 'gymnastics' ? 'active' : ''} onClick={() => setSportFilter('gymnastics')}>Gymnastics</button>
      </div>

      <div className="exercise-grid">
        {filtered.map(ex => {
          const diff = getDifficultyLabel(ex.difficulty);
          const isActive = activeExercise === ex.id;
          return (
            <div key={ex.id} className={`exercise-card ${isActive ? 'active' : ''}`}>
              <div className="exercise-top">
                <h3>{ex.name}</h3>
                <span className="difficulty-badge" style={{ background: diff.color + '22', color: diff.color }}>
                  {diff.text}
                </span>
              </div>
              <p className="exercise-desc">{ex.description}</p>
              <div className="exercise-meta">
                <span>\ud83d\udcaa {ex.targetMuscles.join(', ')}</span>
                {ex.reps > 0 && <span>{ex.reps} reps \u00d7 {ex.sets} sets</span>}
              </div>
              <div className="exercise-footer">
                <span className="prq-badge">PRQ: {ex.prqBenefit.replace(/_/g, ' ')}</span>
                <button
                  className={`btn-demo ${isActive ? 'playing' : ''}`}
                  onClick={() => playDemo(ex.id)}
                  disabled={!state.streamerConnected}
                >
                  {isActive ? '\u25b6 Playing...' : '\ud83c\udfac View 3D Demo'}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
