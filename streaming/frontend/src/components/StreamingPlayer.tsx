import React, { useRef, useEffect, useState } from 'react';
import type { GameMode, StreamingState, StreamingCommand } from '../types';

interface Props {
  mode: GameMode;
  state: StreamingState;
  onExit: () => void;
  sendCommand: (cmd: StreamingCommand, payload?: Record<string, unknown>) => void;
}

export function StreamingPlayer({ mode, state, onExit, sendCommand }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [showHud, setShowHud] = useState(true);
  const [fullscreen, setFullscreen] = useState(false);

  const toggleHud = () => {
    setShowHud(!showHud);
    sendCommand('toggle_hud', { visible: !showHud });
  };

  const toggleFullscreen = () => {
    if (!fullscreen) {
      document.documentElement.requestFullscreen?.();
    } else {
      document.exitFullscreen?.();
    }
    setFullscreen(!fullscreen);
  };

  return (
    <div className="streaming-player">
      {/* Video stream container */}
      <div className="stream-container">
        <video
          ref={videoRef}
          className="stream-video"
          autoPlay
          playsInline
          muted={false}
        />

        {/* Overlay: waiting for stream */}
        {!state.streamerConnected && (
          <div className="stream-waiting">
            <div className="loading-spinner" />
            <p>Connecting to {mode.displayName}...</p>
            <p className="sub">Pixel Streaming initializing</p>
          </div>
        )}

        {/* HUD overlay */}
        {showHud && (
          <div className="stream-hud">
            <div className="hud-top">
              <span className="mode-badge">{mode.icon} {mode.displayName}</span>
              <span className="venue-badge">{mode.venue}</span>
              {state.latencyMs > 0 && (
                <span className="latency-badge">{state.latencyMs}ms</span>
              )}
            </div>
          </div>
        )}
      </div>

      {/* Controls bar */}
      <div className="stream-controls">
        <button className="ctrl-btn exit" onClick={onExit}>
          \u2190 Exit Mode
        </button>
        <div className="ctrl-center">
          <span className="now-playing">{mode.icon} {mode.displayName}</span>
        </div>
        <div className="ctrl-right">
          <button className="ctrl-btn" onClick={toggleHud}>
            {showHud ? '\ud83d\udc41\ufe0f Hide HUD' : '\ud83d\udc41\ufe0f Show HUD'}
          </button>
          <button className="ctrl-btn" onClick={toggleFullscreen}>
            {fullscreen ? '\u2b1c Exit FS' : '\u2b1b Fullscreen'}
          </button>
        </div>
      </div>
    </div>
  );
}
