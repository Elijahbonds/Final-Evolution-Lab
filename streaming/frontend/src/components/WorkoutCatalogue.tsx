import React, { useState } from 'react';
import type { WorkoutProgram, StreamingCommand } from '../types';

const WORKOUT_PROGRAMS: WorkoutProgram[] = [
  {
    id: 'basketball_performance',
    name: 'Basketball Performance',
    description: '8-week program focused on vertical jump, speed, agility, and basketball-specific athleticism.',
    durationWeeks: 8,
    daysPerWeek: 4,
    goal: 'Athletic Performance',
    level: 'Intermediate',
  },
  {
    id: 'strength_foundation',
    name: 'Strength Foundation',
    description: '12-week linear periodization program building base strength through compound movements.',
    durationWeeks: 12,
    daysPerWeek: 3,
    goal: 'Strength',
    level: 'Beginner',
  },
  {
    id: 'athletic_conditioning',
    name: 'Athletic Conditioning',
    description: '6-week high-intensity conditioning combining HIIT, cardio, and strength circuits.',
    durationWeeks: 6,
    daysPerWeek: 5,
    goal: 'Endurance',
    level: 'Advanced',
  },
  {
    id: 'mobility_recovery',
    name: 'Mobility & Recovery',
    description: '4-week daily mobility and recovery program for flexibility and injury prevention.',
    durationWeeks: 4,
    daysPerWeek: 7,
    goal: 'Mobility & Recovery',
    level: 'Beginner',
  },
  {
    id: 'dunk_training',
    name: 'Dunk Training Program',
    description: '10-week vertical jump maximization combining heavy strength work, plyometrics, and approach technique.',
    durationWeeks: 10,
    daysPerWeek: 4,
    goal: 'Vertical Jump',
    level: 'Intermediate',
  },
];

interface Props {
  onBack: () => void;
  sendCommand: (cmd: StreamingCommand, data: any) => void;
}

export function WorkoutCatalogue({ onBack, sendCommand }: Props) {
  const [selected, setSelected] = useState<WorkoutProgram | null>(null);
  const [filterGoal, setFilterGoal] = useState<string>('all');

  const goals = ['all', ...new Set(WORKOUT_PROGRAMS.map(p => p.goal))];
  const filtered = filterGoal === 'all'
    ? WORKOUT_PROGRAMS
    : WORKOUT_PROGRAMS.filter(p => p.goal === filterGoal);

  const handleStart = () => {
    if (!selected) return;
    sendCommand('start_workout', { programId: selected.id });
  };

  return (
    <div className="workout-catalogue">
      <header className="catalogue-header">
        <button className="btn-back" onClick={onBack}>← Back</button>
        <h2>Workout Programs</h2>
        <div className="goal-filter">
          {goals.map(g => (
            <button
              key={g}
              className={`filter-btn ${filterGoal === g ? 'active' : ''}`}
              onClick={() => setFilterGoal(g)}
            >
              {g === 'all' ? 'All' : g}
            </button>
          ))}
        </div>
      </header>

      <div className="programme-grid">
        {filtered.map(prog => (
          <div
            key={prog.id}
            className={`programme-card ${selected?.id === prog.id ? 'selected' : ''}`}
            onClick={() => setSelected(prog)}
          >
            <h3>{prog.name}</h3>
            <p className="prog-desc">{prog.description}</p>
            <div className="prog-stats">
              <span>{prog.durationWeeks} weeks</span>
              <span>{prog.daysPerWeek} days/wk</span>
              <span className="prog-level">{prog.level}</span>
            </div>
            <div className="prog-goal">{prog.goal}</div>
          </div>
        ))}
      </div>

      {selected && (
        <div className="programme-detail">
          <h3>{selected.name}</h3>
          <p>{selected.description}</p>
          <button className="btn-start-workout" onClick={handleStart}>
            Start Program
          </button>
        </div>
      )}
    </div>
  );
}
