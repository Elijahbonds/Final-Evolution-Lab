import React, { useState, useEffect, useCallback } from 'react';
import { ModeSelector } from './components/ModeSelector';
import { StreamingPlayer } from './components/StreamingPlayer';
import { ExercisePanel } from './components/ExercisePanel';
import { StatusBar } from './components/StatusBar';
import { SubscriptionBanner } from './components/SubscriptionBanner';
import { WorkoutCatalogue } from './components/WorkoutCatalogue';
import { SubscriptionPrompt } from './components/SubscriptionPrompt';
import { useStreamingConnection } from './hooks/useStreamingConnection';
import type { GameMode } from './types';
import './styles.css';

type AppView = 'menu' | 'playing' | 'exercises' | 'workouts';

export function App() {
  const [view, setView] = useState<AppView>('menu');
  const [selectedMode, setSelectedMode] = useState<GameMode | null>(null);
  const [showSubscriptionPrompt, setShowSubscriptionPrompt] = useState(false);
  const { state, sendCommand, connect } = useStreamingConnection();

  useEffect(() => {
    connect();
  }, []);

  // Check if access is allowed
  const hasAccess = state.subscription.status === 'free_trial' ||
                    state.subscription.status === 'active' ||
                    state.subscription.status === 'grace_period';

  const handleLaunchMode = useCallback((mode: GameMode) => {
    if (!hasAccess) {
      setShowSubscriptionPrompt(true);
      return;
    }
    setSelectedMode(mode);
    sendCommand('launch_mode', { mode_key: mode.id });
    setView('playing');
  }, [sendCommand, hasAccess]);

  const handleExitMode = useCallback(() => {
    sendCommand('exit_mode', {});
    setSelectedMode(null);
    setView('menu');
  }, [sendCommand]);

  const handleShowExercises = useCallback(() => {
    if (!hasAccess) {
      setShowSubscriptionPrompt(true);
      return;
    }
    setView('exercises');
  }, [hasAccess]);

  const handleShowWorkouts = useCallback(() => {
    if (!hasAccess) {
      setShowSubscriptionPrompt(true);
      return;
    }
    setView('workouts');
  }, [hasAccess]);

  const handleBackToMenu = useCallback(() => {
    setView('menu');
  }, []);

  const handleSubscribe = useCallback(() => {
    sendCommand('subscribe', {});
    // Open Stripe checkout
    window.open('https://billing.finalevolutiongroup.com/checkout?plan=weekly', '_blank');
  }, [sendCommand]);

  return (
    <div className="fel-app">
      <SubscriptionBanner
        subscription={state.subscription}
        onSubscribe={handleSubscribe}
      />

      <StatusBar state={state} />
      
      {view === 'menu' && (
        <>
          <ModeSelector
            onLaunch={handleLaunchMode}
            onShowExercises={handleShowExercises}
            streamerConnected={state.streamerConnected}
          />
          <div className="menu-extra-buttons">
            <button className="btn-workouts" onClick={handleShowWorkouts}>
              🏋️ Workouts
            </button>
            <button className="btn-exercises" onClick={handleShowExercises}>
              💪 Exercises
            </button>
          </div>
        </>
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

      {view === 'workouts' && (
        <WorkoutCatalogue
          onBack={handleBackToMenu}
          sendCommand={sendCommand}
        />
      )}

      {showSubscriptionPrompt && (
        <SubscriptionPrompt
          onSubscribe={handleSubscribe}
          onClose={() => setShowSubscriptionPrompt(false)}
        />
      )}
    </div>
  );
}
