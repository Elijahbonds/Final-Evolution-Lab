import React, { useState, useEffect, useRef } from 'react';

const WS_URL = 'ws://localhost:8080/ws/hud';

const HUD_ShardCounter = () => {
  const [data, setData] = useState({ shards: 0, xp: 0, xp_cap: 500 });
  const wsRef = useRef(null);
  const retryRef = useRef(null);

  const connect = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (e) => {
      try { const m = JSON.parse(e.data); if (m.type === 'economy_update') setData(m.payload); } catch {}
    };
    ws.onclose = () => { retryRef.current = setTimeout(connect, 3000); };
    ws.onerror = () => ws.close();
  };

  useEffect(() => { connect(); return () => { wsRef.current?.close(); if (retryRef.current) clearTimeout(retryRef.current); }; }, []);

  const xpPct = Math.min((data.xp / data.xp_cap) * 100, 100);

  return (
    <div style={{ position: 'fixed', top: 12, right: 16, background: 'rgba(0,0,0,0.75)', borderRadius: 12, padding: '8px 14px', color: '#fff', zIndex: 100, minWidth: 120 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
        <span style={{ fontSize: 18 }}>💎</span>
        <span style={{ fontWeight: 700, fontSize: 18 }}>{data.shards}</span>
      </div>
      <div style={{ fontSize: 11, opacity: 0.7, marginBottom: 4 }}>XP {data.xp} / {data.xp_cap}</div>
      <div style={{ background: '#333', borderRadius: 4, height: 6, overflow: 'hidden' }}>
        <div style={{ background: '#ffd54f', width: `${xpPct}%`, height: '100%', transition: 'width 0.4s', borderRadius: 4 }} />
      </div>
    </div>
  );
};

export default HUD_ShardCounter;
