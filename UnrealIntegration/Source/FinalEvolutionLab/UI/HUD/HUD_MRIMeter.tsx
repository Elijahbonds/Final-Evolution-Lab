import React, { useState, useEffect, useRef } from 'react';

const WS_URL = 'ws://localhost:8080/ws/hud';

interface MRIPayload { mri_score: number; arv: number; esi: number; pacing: number; }

const HUD_MRIMeter: React.FC = () => {
  const [data, setData] = useState<MRIPayload>({ mri_score: 0, arv: 0, esi: 0, pacing: 0 });
  const wsRef = useRef<WebSocket | null>(null);
  const retryRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const connect = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (e) => {
      try { const m = JSON.parse(e.data); if (m.type === 'mri_update') setData(m.payload); } catch {}
    };
    ws.onclose = () => { retryRef.current = setTimeout(connect, 3000); };
    ws.onerror = () => ws.close();
  };

  useEffect(() => { connect(); return () => { wsRef.current?.close(); if (retryRef.current) clearTimeout(retryRef.current); }; }, []);

  const segments = [
    { label: 'ARV', value: data.arv, weight: 40, color: '#4fc3f7' },
    { label: 'ESI', value: 100 - data.esi, weight: 35, color: '#ce93d8' },
    { label: 'PAC', value: data.pacing, weight: 25, color: '#a5d6a7' },
  ];

  return (
    <div style={{ position: 'fixed', top: '50%', left: 16, transform: 'translateY(-50%)', background: 'rgba(0,0,0,0.7)', borderRadius: 16, padding: '16px 12px', color: '#fff', zIndex: 100, minWidth: 80 }}>
      <div style={{ textAlign: 'center', fontSize: 11, opacity: 0.7, marginBottom: 8 }}>MRI</div>
      <div style={{ textAlign: 'center', fontWeight: 700, fontSize: 20, marginBottom: 12 }}>{data.mri_score.toFixed(1)}</div>
      {segments.map(s => (
        <div key={s.label} style={{ marginBottom: 8 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 10, marginBottom: 2 }}>
            <span style={{ opacity: 0.7 }}>{s.label}</span>
            <span style={{ opacity: 0.7 }}>{s.weight}%</span>
          </div>
          <div style={{ background: '#333', borderRadius: 4, height: 8, overflow: 'hidden' }}>
            <div style={{ background: s.color, width: `${Math.min(s.value, 100)}%`, height: '100%', transition: 'width 0.4s', borderRadius: 4 }} />
          </div>
        </div>
      ))}
    </div>
  );
};

export default HUD_MRIMeter;
