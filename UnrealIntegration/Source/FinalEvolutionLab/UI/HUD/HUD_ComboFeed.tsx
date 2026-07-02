import React, { useState, useEffect, useRef } from 'react';

const WS_URL = 'ws://localhost:8080/ws/hud';

interface GameEvent { event_type: string; description: string; timestamp: number; }

const TYPE_COLORS: Record<string, string> = {
  score: '#ffd54f', foul: '#ef9a9a', block: '#80cbc4', ace: '#ce93d8',
  default: '#90caf9',
};

const HUD_ComboFeed: React.FC = () => {
  const [events, setEvents] = useState<GameEvent[]>([]);
  const wsRef = useRef<WebSocket | null>(null);
  const retryRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const connect = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (e) => {
      try {
        const m = JSON.parse(e.data);
        if (m.type === 'game_event') {
          setEvents(prev => [m.payload, ...prev].slice(0, 5));
        }
      } catch {}
    };
    ws.onclose = () => { retryRef.current = setTimeout(connect, 3000); };
    ws.onerror = () => ws.close();
  };

  useEffect(() => { connect(); return () => { wsRef.current?.close(); if (retryRef.current) clearTimeout(retryRef.current); }; }, []);

  return (
    <div style={{ position: 'fixed', bottom: 16, left: 16, display: 'flex', flexDirection: 'column', gap: 4, zIndex: 100 }}>
      {events.map((ev, i) => (
        <div key={ev.timestamp} style={{ background: 'rgba(0,0,0,0.72)', color: TYPE_COLORS[ev.event_type] || TYPE_COLORS.default, borderRadius: 8, padding: '4px 12px', fontSize: 13, opacity: 1 - i * 0.15, transition: 'opacity 0.3s' }}>
          <span style={{ fontWeight: 700, textTransform: 'uppercase', fontSize: 10, marginRight: 6 }}>{ev.event_type}</span>
          {ev.description}
        </div>
      ))}
    </div>
  );
};

export default HUD_ComboFeed;
