import React, { useState, useEffect, useRef } from 'react';

const WS_URL = 'ws://localhost:8080/ws/hud';

const HUD_PRQMeter = () => {
  const [data, setData] = useState({ prq_score: 0, mode_weight_label: 'x1.0', max_prq: 10 });
  const wsRef = useRef(null);
  const retryRef = useRef(null);

  const connect = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (e) => {
      try { const m = JSON.parse(e.data); if (m.type === 'prq_update') setData(m.payload); } catch {}
    };
    ws.onclose = () => { retryRef.current = setTimeout(connect, 3000); };
    ws.onerror = () => ws.close();
  };

  useEffect(() => { connect(); return () => { wsRef.current?.close(); if (retryRef.current) clearTimeout(retryRef.current); }; }, []);

  const pct = Math.min((data.prq_score / data.max_prq) * 100, 100);
  const r = 36, circ = 2 * Math.PI * r;
  const stroke = circ - (pct / 100) * circ;

  return (
    <div style={{ position: 'fixed', top: '50%', right: 16, transform: 'translateY(-50%)', background: 'rgba(0,0,0,0.7)', borderRadius: 16, padding: 16, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, color: '#fff', zIndex: 100 }}>
      <span style={{ fontSize: 11, opacity: 0.7 }}>PRQ</span>
      <svg width={90} height={90}>
        <circle cx={45} cy={45} r={r} fill="none" stroke="#333" strokeWidth={8} />
        <circle cx={45} cy={45} r={r} fill="none" stroke="#00e5ff" strokeWidth={8}
          strokeDasharray={circ} strokeDashoffset={stroke} strokeLinecap="round"
          transform="rotate(-90 45 45)" style={{ transition: 'stroke-dashoffset 0.5s' }} />
        <text x={45} y={50} textAnchor="middle" fill="#fff" fontSize={18} fontWeight={700}>{data.prq_score.toFixed(1)}</text>
      </svg>
      <span style={{ fontSize: 12, background: '#1a237e', padding: '2px 8px', borderRadius: 6 }}>{data.mode_weight_label}</span>
    </div>
  );
};

export default HUD_PRQMeter;
