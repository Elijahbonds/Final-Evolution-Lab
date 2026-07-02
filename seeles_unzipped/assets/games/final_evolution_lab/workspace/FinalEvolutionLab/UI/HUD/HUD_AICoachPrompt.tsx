import React, { useState, useEffect, useRef } from 'react';

const WS_URL = 'ws://localhost:8080/ws/hud';

interface CoachPayload { tip_text: string; mode_name: string; }

const HUD_AICoachPrompt: React.FC = () => {
  const [data, setData] = useState<CoachPayload | null>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const retryRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const dismissRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const connect = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (e) => {
      try {
        const m = JSON.parse(e.data);
        if (m.type === 'coach_tip') {
          setData(m.payload);
          if (dismissRef.current) clearTimeout(dismissRef.current);
          dismissRef.current = setTimeout(() => setData(null), 5000);
        }
      } catch {}
    };
    ws.onclose = () => { retryRef.current = setTimeout(connect, 3000); };
    ws.onerror = () => ws.close();
  };

  useEffect(() => {
    connect();
    return () => {
      wsRef.current?.close();
      if (retryRef.current) clearTimeout(retryRef.current);
      if (dismissRef.current) clearTimeout(dismissRef.current);
    };
  }, []);

  if (!data) return null;

  return (
    <div style={{ position: 'fixed', bottom: 32, left: '50%', transform: 'translateX(-50%)', background: 'rgba(13,71,161,0.92)', color: '#fff', borderRadius: 16, padding: '14px 24px', maxWidth: 360, textAlign: 'center', zIndex: 100, boxShadow: '0 4px 24px rgba(0,0,0,0.4)', animation: 'fadeInUp 0.3s ease' }}>
      <div style={{ fontSize: 11, opacity: 0.7, marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 }}>🤖 AI Coach · {data.mode_name}</div>
      <div style={{ fontSize: 15, lineHeight: 1.5 }}>{data.tip_text}</div>
    </div>
  );
};

export default HUD_AICoachPrompt;
