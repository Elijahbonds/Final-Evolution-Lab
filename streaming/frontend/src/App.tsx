import React, { useState, useEffect, useCallback, useRef } from 'react';
import { ModeSelector } from './components/ModeSelector';
import { StreamingPlayer } from './components/StreamingPlayer';
import { ExercisePanel } from './components/ExercisePanel';
import { StatusBar } from './components/StatusBar';
import { useStreamingConnection } from './hooks/useStreamingConnection';
import type { GameMode, StreamingState } from './types';
import './styles.css';

export function App() {
  const [view, setView] = useState<'menu' | 'playing' | 'exercises'>('menu');
  const [selectedMode, setSelectedMode] = useState<GameMode | null>(null);
  const { state, sendCommand, connect } = useStreamingConnection();

  useEffect(() => {
    connect();
  }, []);

  const handleLaunchMode = useCallback((mode: GameMode) => {
    setSelectedMode(mode);
    sendCommand('launch_mode', { mode_key: mode.id });
    setView('playing');
  }, [sendCommand]);

  const handleExitMode = useCallback(() => {
    sendCommand('exit_mode', {});
    setSelectedMode(null);
    setView('menu');
  }, [sendCommand]);

  const handleShowExercises = useCallback(() => {
    setView('exercises');
  }, []);

  const handleBackToMenu = useCallback(() => {
    setView('menu');
  }, []);

  return (
    <div className="fel-app">
      <StatusBar state={state} />
      
      {view === 'menu' && (
        <ModeSelector
          onLaunch={handleLaunchMode}
          onShowExercises={handleShowExercises}
          streamerConnected={state.streamerConnected}
        />
      )}
      
      {view === 'playing' && selectedMode && (
        <StreamingPlayer
          mode={selectedMode}
          state={state}
          onExit={handleExitMode}
          sendCommand={sendCommand}
        />
      )}
      
      {view === 'exercises' && (
        <ExercisePanel
          onBack={handleBackToMenu}
          sendCommand={sendCommand}
          state={state}
        />
      )}
    </div>
  );
}
