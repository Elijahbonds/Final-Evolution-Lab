import React from 'react';
import type { StreamingState } from '../types';

interface Props {
  state: StreamingState;
}

export function StatusBar({ state }: Props) {
  return (
    <div className="status-bar">
      <div className="status-left">
        <span className="brand">FEL</span>
        <span className="version">v1.0</span>
      </div>
      <div className="status-center">
        {state.activeMode && (
          <span className="active-mode">Now Playing: {state.activeMode}</span>
        )}
      </div>
      <div className="status-right">
        <span className={`indicator ${state.connected ? 'on' : 'off'}`}>
          {state.connected ? '\u25cf WS' : '\u25cb WS'}
        </span>
        <span className={`indicator ${state.streamerConnected ? 'on' : 'off'}`}>
          {state.streamerConnected ? '\u25cf UE5' : '\u25cb UE5'}
        </span>
        {state.latencyMs > 0 && (
          <span className="latency">{state.latencyMs}ms</span>
        )}
      </div>
    </div>
  );
}
