import { useState, useCallback, useRef, useEffect } from 'react';
import type { StreamingState, StreamingCommand } from '../types';

const WS_URL = import.meta.env.VITE_SIGNALLING_URL || `ws://${window.location.hostname}:8888`;

export function useStreamingConnection() {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimerRef = useRef<number | null>(null);
  const [state, setState] = useState<StreamingState>({
    connected: false,
    streamerConnected: false,
    playerId: null,
    activeMode: null,
    sessionId: null,
    latencyMs: 0,
  });

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;

    try {
      const ws = new WebSocket(WS_URL);
      wsRef.current = ws;

      ws.onopen = () => {
        console.log('[FEL] Connected to signalling server');
        setState(prev => ({ ...prev, connected: true }));
      };

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          
          if (msg.type === 'playerConnected') {
            setState(prev => ({
              ...prev,
              playerId: msg.playerId,
              streamerConnected: msg.streamerConnected,
              activeMode: msg.activeMode,
              sessionId: msg.sessionId,
            }));
          }

          if (msg.response === 'launch_mode_result') {
            if (msg.success) {
              setState(prev => ({ ...prev, activeMode: msg.mode_key }));
            }
          }

          if (msg.response === 'status') {
            setState(prev => ({
              ...prev,
              streamerConnected: msg.connected,
              activeMode: msg.current_mode || null,
            }));
          }
        } catch {
          // Binary frame (video/audio) - ignore for state
        }
      };

      ws.onclose = () => {
        console.log('[FEL] Disconnected from signalling');
        setState(prev => ({ ...prev, connected: false, streamerConnected: false }));
        wsRef.current = null;
        
        // Auto-reconnect after 3 seconds
        reconnectTimerRef.current = window.setTimeout(() => connect(), 3000);
      };

      ws.onerror = (err) => {
        console.error('[FEL] WebSocket error:', err);
      };
    } catch (err) {
      console.error('[FEL] Connection failed:', err);
    }
  }, []);

  const sendCommand = useCallback((command: StreamingCommand, payload: Record<string, unknown> = {}) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify({ command, payload }));
    } else {
      console.warn('[FEL] Cannot send command - not connected');
    }
  }, []);

  useEffect(() => {
    return () => {
      if (reconnectTimerRef.current) clearTimeout(reconnectTimerRef.current);
      wsRef.current?.close();
    };
  }, []);

  return { state, sendCommand, connect };
}
