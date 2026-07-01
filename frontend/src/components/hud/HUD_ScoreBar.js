import React, { useState, useEffect, useRef } from 'react';

const WS_URL = 'ws://localhost:8080/ws/hud';

const HUD_ScoreBar = () => {
  const [data, setData] = useState({ home_score: 0, away_score: 0, timer_seconds: 600, period: 1 });
  const wsRef = useRef(null);
  const retryRef = useRef(null);

  const connect = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'score_update') setData(msg.payload);
      } catch {}
    };
    ws.onclose = () => { retryRef.current = setTimeout(connect, 3000); };
    ws.onerror = () => { ws.close(); };
  };

  useEffect(() => {
    connect();
    return () => {
      wsRef.current?.close();
      if (retryRef.current) clearTimeout(retryRef.current);
    };
  }, []);

  const fmt = (s) => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

  return (
    <div style={{ position: 'fixed', top: 0, left: '50%', transform: 'translateX(-50%)', background: 'rgba(0,0,0,0.75)', color: '#fff', borderRadius: '0 0 12px 12px', padding: '8px 32px', display: 'flex', gap: 24, alignItems: 'center', fontFamily: 'monospace', fontSize: 22, zIndex: 100 }}>
      <span style={{ fontWeight: 700, color: '#4fc3f7' }}>{data.home_score}</span>
      <span style={{ fontSize: 14, opacity: 0.7 }}>HOME</span>
      <span style={{ fontSize: 18, background: '#1a237e', padding: '2px 12px', borderRadius: 8 }}>{fmt(data.timer_seconds)}</span>
      <span style={{ fontSize: 12, opacity: 0.6 }}>P{data.period}</span>
      <span style={{ fontSize: 14, opacity: 0.7 }}>AWAY</span>
      <span style={{ fontWeight: 700, color: '#ef9a9a' }}>{data.away_score}</span>
    </div>
  );
};

export default HUD_ScoreBar;
