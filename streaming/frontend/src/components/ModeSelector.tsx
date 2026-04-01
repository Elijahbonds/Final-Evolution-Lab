import React, { useState } from 'react';
import type { GameMode } from '../types';

const ALL_MODES: GameMode[] = [
  { id: 'basketball_h2h', displayName: 'Street \u00b7 1v1', venue: 'Venice Beach', category: 'basketball', icon: '\ud83c\udfc0' },
  { id: 'basketball_dunk', displayName: 'Dunk Contest', venue: 'Venice Beach', category: 'basketball', icon: '\ud83e\udd3e' },
  { id: 'basketball_3v3', displayName: 'Street \u00b7 3v3', venue: 'Venice Beach', category: 'basketball', icon: '\ud83c\udfc0' },
  { id: 'karate_h2h', displayName: 'Karate \u00b7 1v1', venue: 'Dojo', category: 'combat', icon: '\ud83e\udd4b' },
  { id: 'karate_endless', displayName: 'Karate \u00b7 Endless', venue: 'Dojo', category: 'combat', icon: '\ud83e\udd4b' },
  { id: 'baseball', displayName: 'Baseball \u00b7 Ballpark', venue: 'Baseball Park', category: 'field', icon: '\u26be' },
  { id: 'football', displayName: 'Football \u00b7 Kick Return', venue: 'Gridiron', category: 'field', icon: '\ud83c\udfc8' },
  { id: 'soccer', displayName: 'Soccer \u00b7 Stadium', venue: 'Soccer Stadium', category: 'field', icon: '\u26bd' },
  { id: 'golf', displayName: 'Golf \u00b7 Links', venue: 'Links', category: 'precision', icon: '\u26f3' },
  { id: 'tennis', displayName: 'Tennis \u00b7 Court', venue: 'Tennis Court', category: 'court', icon: '\ud83c\udfbe' },
  { id: 'volleyball', displayName: 'Volleyball \u00b7 Sand', venue: 'Sand Court', category: 'court', icon: '\ud83c\udfd0' },
  { id: 'gymnastics', displayName: 'Gymnastics \u00b7 Floor', venue: 'Training Floor', category: 'performance', icon: '\ud83e\udd38' },
  { id: 'brain_brawl', displayName: 'Brain Brawl', venue: 'Neuro Arena', category: 'academy', icon: '\ud83e\udde0' },
  { id: 'surfing', displayName: 'Surf \u00b7 Line', venue: 'Venice Beach', category: 'board', icon: '\ud83c\udfc4' },
  { id: 'skateboarding', displayName: 'Skate \u00b7 Park', venue: 'Dojo', category: 'board', icon: '\ud83d\udef9' },
  { id: 'snowboarding', displayName: 'Snow \u00b7 Line', venue: 'Training Floor', category: 'board', icon: '\ud83c\udfc2' },
];

const CATEGORIES = [
  { id: 'all', label: 'All Modes' },
  { id: 'basketball', label: 'Basketball' },
  { id: 'combat', label: 'Combat' },
  { id: 'field', label: 'Field' },
  { id: 'court', label: 'Court' },
  { id: 'precision', label: 'Precision' },
  { id: 'performance', label: 'Performance' },
  { id: 'board', label: 'Board Sports' },
  { id: 'academy', label: 'Academy' },
];

interface Props {
  onLaunch: (mode: GameMode) => void;
  onShowExercises: () => void;
  streamerConnected: boolean;
}

export function ModeSelector({ onLaunch, onShowExercises, streamerConnected }: Props) {
  const [filter, setFilter] = useState('all');
  const filtered = filter === 'all' ? ALL_MODES : ALL_MODES.filter(m => m.category === filter);

  return (
    <div className="mode-selector">
      <header className="mode-header">
        <h1>Final Evolution <span className="accent">LAB</span></h1>
        <p className="subtitle">16 Arena Modes · Pixel Streaming · PRQ-Driven</p>
        <div className="header-actions">
          <button className="btn-exercises" onClick={onShowExercises}>
            \ud83c\udfcb\ufe0f\u200d\u2642\ufe0f 3D Exercises
          </button>
        </div>
      </header>

      <nav className="category-nav">
        {CATEGORIES.map(cat => (
          <button
            key={cat.id}
            className={`cat-btn ${filter === cat.id ? 'active' : ''}`}
            onClick={() => setFilter(cat.id)}
          >
            {cat.label}
          </button>
        ))}
      </nav>

      <div className="mode-grid">
        {filtered.map(mode => (
          <button
            key={mode.id}
            className="mode-card"
            onClick={() => onLaunch(mode)}
            disabled={!streamerConnected}
          >
            <span className="mode-icon">{mode.icon}</span>
            <div className="mode-info">
              <h3>{mode.displayName}</h3>
              <p className="venue">{mode.venue}</p>
            </div>
            <div className="mode-action">
              {streamerConnected ? 'PLAY' : 'OFFLINE'}
            </div>
          </button>
        ))}
      </div>

      {!streamerConnected && (
        <div className="offline-banner">
          \u26a0\ufe0f Game server not connected. Start the UE5 Pixel Streaming server.
        </div>
      )}
    </div>
  );
}
