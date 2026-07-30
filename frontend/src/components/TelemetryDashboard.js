/**
 * TelemetryDashboard — Nexus telemetry & metrics view (/nexus/telemetry).
 *
 * Renders computed metrics from GET /api/telemetry/dashboard as premium-dark
 * metric cards plus lightweight inline-SVG charts (no charting deps).
 *
 * Palette: cyan #00D4FF, purple #9933FF on a near-black canvas.
 */
import React, { useCallback, useEffect, useMemo, useState } from 'react';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:8000';
const API = `${BACKEND_URL}/api`;

const CYAN = '#00D4FF';
const PURPLE = '#9933FF';

const styles = {
  page: {
    background: 'radial-gradient(1200px 600px at 20% -10%, rgba(0,212,255,0.08), transparent), radial-gradient(1000px 500px at 100% 0%, rgba(153,51,255,0.10), transparent), #06070a',
    color: '#e8eaf0',
    minHeight: '100vh',
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif',
    padding: '28px 32px 64px',
  },
  header: { display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12, marginBottom: 24 },
  title: {
    fontSize: '1.7rem', fontWeight: 800, margin: 0, letterSpacing: '-0.02em',
    background: `linear-gradient(90deg, ${CYAN}, ${PURPLE})`,
    WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent', backgroundClip: 'text',
  },
  subtitle: { color: '#8b93a7', fontSize: '0.85rem', margin: '4px 0 0' },
  controls: { display: 'flex', alignItems: 'center', gap: 12 },
  refreshBtn: {
    background: 'rgba(0,212,255,0.12)', color: CYAN, border: `1px solid ${CYAN}55`,
    borderRadius: 10, padding: '8px 16px', fontWeight: 600, cursor: 'pointer', fontSize: '0.85rem',
  },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: 16, marginBottom: 28 },
  card: {
    background: 'linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015))',
    border: '1px solid rgba(255,255,255,0.08)', borderRadius: 16, padding: '18px 20px',
    boxShadow: '0 8px 30px rgba(0,0,0,0.35)',
  },
  cardLabel: { color: '#8b93a7', fontSize: '0.72rem', textTransform: 'uppercase', letterSpacing: '0.08em', margin: 0 },
  cardValue: { fontSize: '1.9rem', fontWeight: 800, margin: '8px 0 2px', color: '#fff' },
  cardHint: { color: '#6b7488', fontSize: '0.72rem', margin: 0 },
  panels: { display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 16 },
  panel: {
    background: 'linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015))',
    border: '1px solid rgba(255,255,255,0.08)', borderRadius: 16, padding: '18px 20px',
  },
  panelTitle: { fontSize: '0.95rem', fontWeight: 700, margin: '0 0 14px', color: '#dfe4ee' },
  emptyMsg: { color: '#6b7488', fontSize: '0.85rem', padding: '20px 0' },
  errorBanner: {
    background: 'rgba(255,80,80,0.12)', border: '1px solid rgba(255,80,80,0.4)', color: '#ff9a9a',
    borderRadius: 10, padding: '10px 14px', marginBottom: 20, fontSize: '0.85rem',
  },
};

function MetricCard({ label, value, hint, accent }) {
  return (
    <div style={styles.card}>
      <p style={styles.cardLabel}>{label}</p>
      <p style={{ ...styles.cardValue, color: accent || '#fff' }}>{value}</p>
      {hint ? <p style={styles.cardHint}>{hint}</p> : null}
    </div>
  );
}

/** Horizontal bar chart from a {label: count} map, rendered as inline SVG. */
function BarChart({ data, color }) {
  const entries = Object.entries(data || {}).filter(([, v]) => v > 0);
  if (entries.length === 0) return <p style={styles.emptyMsg}>No data yet.</p>;
  const max = Math.max(...entries.map(([, v]) => v));
  const rowH = 30;
  const width = 320;
  const labelW = 130;
  const barMax = width - labelW - 44;
  const height = entries.length * rowH;
  return (
    <svg viewBox={`0 0 ${width} ${height}`} width="100%" role="img" aria-label="bar chart">
      {entries.map(([label, value], i) => {
        const w = max ? Math.max(2, (value / max) * barMax) : 2;
        const y = i * rowH;
        return (
          <g key={label}>
            <text x={0} y={y + rowH / 2 + 4} fill="#9aa3b5" fontSize="11">
              {label.length > 18 ? label.slice(0, 17) + '…' : label}
            </text>
            <rect x={labelW} y={y + 6} width={w} height={rowH - 14} rx={4} fill={color} opacity="0.85" />
            <text x={labelW + w + 6} y={y + rowH / 2 + 4} fill="#dfe4ee" fontSize="11" fontWeight="600">
              {value}
            </text>
          </g>
        );
      })}
    </svg>
  );
}

/** Simple gauge for a 0..1 rate, rendered as inline SVG. */
function RateGauge({ value, color, caption }) {
  const pct = Math.max(0, Math.min(1, value || 0));
  const w = 320, h = 16;
  return (
    <div>
      <svg viewBox={`0 0 ${w} ${h}`} width="100%" role="img" aria-label="rate gauge">
        <rect x={0} y={0} width={w} height={h} rx={8} fill="rgba(255,255,255,0.06)" />
        <rect x={0} y={0} width={Math.max(4, pct * w)} height={h} rx={8} fill={color} />
      </svg>
      <p style={{ ...styles.cardHint, marginTop: 6 }}>{caption}: {(pct * 100).toFixed(1)}%</p>
    </div>
  );
}

export default function TelemetryDashboard() {
  const [metrics, setMetrics] = useState(null);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const res = await fetch(`${API}/telemetry/dashboard`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setMetrics(data);
      setError(null);
    } catch (e) {
      setError(e.message || 'Failed to load telemetry');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
    const id = setInterval(load, 10000);
    return () => clearInterval(id);
  }, [load]);

  const m = useMemo(() => metrics || {}, [metrics]);
  const eventsByType = useMemo(() => m.events_by_type || {}, [m]);
  const perMode = useMemo(() => m.per_mode_play_counts || {}, [m]);

  return (
    <div style={styles.page}>
      <div style={styles.header}>
        <div>
          <h1 style={styles.title}>Nexus Telemetry</h1>
          <p style={styles.subtitle}>
            Live event ingest & computed metrics · {loading ? 'refreshing…' : `${m.total_events ?? 0} events`}
          </p>
        </div>
        <div style={styles.controls}>
          <button style={styles.refreshBtn} onClick={load}>Refresh</button>
        </div>
      </div>

      {error ? <div style={styles.errorBanner}>Telemetry unavailable: {error}</div> : null}

      <div style={styles.grid}>
        <MetricCard label="Total Events" value={m.total_events ?? 0} accent={CYAN} hint="all ingested" />
        <MetricCard label="Frame Time P95" value={`${m.frame_time_p95_ms ?? 0} ms`} accent={PURPLE}
          hint={`p50 ${m.frame_time_p50_ms ?? 0} ms · ${m.latency_sample_count ?? 0} samples`} />
        <MetricCard label="Desync Rate" value={`${((m.desync_rate ?? 0) * 100).toFixed(1)}%`}
          accent={(m.desync_rate ?? 0) > 0.05 ? '#ff7a7a' : CYAN} hint="of latency samples" />
        <MetricCard label="Replay Failures" value={m.replay_validator_failures ?? 0}
          accent={(m.replay_validator_failures ?? 0) > 0 ? '#ff7a7a' : CYAN}
          hint={`of ${m.replay_export_count ?? 0} exports`} />
        <MetricCard label="Card Conversion" value={`${((m.creator_card_conversion_rate ?? 0) * 100).toFixed(1)}%`}
          accent={PURPLE} hint={`${m.creator_card_conversions ?? 0}/${m.creator_card_applies ?? 0} applies`} />
        <MetricCard label="Avg Dunk Score" value={m.avg_dunk_score ?? 0} accent={CYAN} hint="across dunk_score events" />
        <MetricCard label="Question Accuracy" value={`${((m.question_accuracy ?? 0) * 100).toFixed(1)}%`}
          accent={PURPLE} hint={`${m.question_count ?? 0} answered`} />
      </div>

      <div style={styles.panels}>
        <div style={styles.panel}>
          <h2 style={styles.panelTitle}>Per-Mode Play Counts</h2>
          <BarChart data={perMode} color={CYAN} />
        </div>
        <div style={styles.panel}>
          <h2 style={styles.panelTitle}>Events by Type</h2>
          <BarChart data={eventsByType} color={PURPLE} />
        </div>
        <div style={styles.panel}>
          <h2 style={styles.panelTitle}>Health Rates</h2>
          <div style={{ display: 'grid', gap: 18 }}>
            <RateGauge value={m.desync_rate ?? 0} color="#ff7a7a" caption="Desync rate" />
            <RateGauge value={m.replay_failure_rate ?? 0} color="#ffb020" caption="Replay failure rate" />
            <RateGauge value={m.creator_card_conversion_rate ?? 0} color={PURPLE} caption="Card conversion" />
            <RateGauge value={m.question_accuracy ?? 0} color={CYAN} caption="Question accuracy" />
          </div>
        </div>
      </div>
    </div>
  );
}
