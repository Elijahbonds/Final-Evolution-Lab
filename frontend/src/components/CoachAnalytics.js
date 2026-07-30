import React, { useCallback, useEffect, useMemo, useState } from "react";
import axios from "axios";

/**
 * CoachAnalytics — /nexus/analytics
 *
 * Renders per-play analytics for a match, computed server-side from the replay
 * event stream (GET /api/analytics/match/{id}):
 *   - a spatial success heatmap grid (inline SVG, no heavy deps)
 *   - a per-play breakdown list
 *   - a per-play "Download replay" button (GET .../play/{play_id}/export)
 *
 * Premium dark theme, cyan/purple.
 */

const API_BASE = process.env.REACT_APP_BACKEND_URL || "";

// cyan -> purple ramp for success rate; intensity from attempt density.
function cellFill(cell, maxAttempts) {
  if (!cell || cell.attempts === 0) return "rgba(148,163,184,0.06)";
  const rate = cell.success_rate; // 0..1
  // hue: 190 (cyan) at high success -> 270 (purple) at low success
  const hue = 190 + (1 - rate) * 80;
  const density = maxAttempts > 0 ? cell.attempts / maxAttempts : 0;
  const alpha = 0.28 + density * 0.62;
  return `hsla(${hue}, 85%, 58%, ${alpha.toFixed(3)})`;
}

function pct(v) {
  return `${Math.round((v || 0) * 100)}%`;
}

function Heatmap({ heatmap }) {
  const grid = heatmap?.grid || 0;
  const cells = heatmap?.cells || [];
  const maxAttempts = heatmap?.max_cell_attempts || 0;
  const size = 320;
  const cellSize = grid > 0 ? size / grid : size;

  if (!grid) return null;

  return (
    <svg
      viewBox={`0 0 ${size} ${size}`}
      width="100%"
      style={{ maxWidth: 360, borderRadius: 12, background: "#0b0f1a" }}
      role="img"
      aria-label="Success heatmap grid"
    >
      {cells.map((row, r) =>
        row.map((cell, c) => (
          <g key={`${r}-${c}`}>
            <rect
              x={c * cellSize}
              y={r * cellSize}
              width={cellSize - 1.5}
              height={cellSize - 1.5}
              rx={3}
              fill={cellFill(cell, maxAttempts)}
              stroke="rgba(34,211,238,0.10)"
              strokeWidth={1}
            >
              <title>
                {`cell (${r},${c}) — ${cell.successes}/${cell.attempts} made · ${pct(
                  cell.success_rate
                )}`}
              </title>
            </rect>
            {cell.attempts > 0 && (
              <text
                x={c * cellSize + cellSize / 2}
                y={r * cellSize + cellSize / 2}
                fill="#e2e8f0"
                fontSize={Math.max(8, cellSize * 0.22)}
                textAnchor="middle"
                dominantBaseline="central"
                style={{ pointerEvents: "none", fontVariantNumeric: "tabular-nums" }}
              >
                {cell.successes}/{cell.attempts}
              </text>
            )}
          </g>
        ))
      )}
    </svg>
  );
}

function StatCard({ label, value, sub }) {
  return (
    <div
      style={{
        background: "rgba(30,41,59,0.55)",
        border: "1px solid rgba(34,211,238,0.14)",
        borderRadius: 12,
        padding: "14px 16px",
        minWidth: 120,
      }}
    >
      <div style={{ fontSize: 11, letterSpacing: 0.6, color: "#7dd3fc", textTransform: "uppercase" }}>
        {label}
      </div>
      <div style={{ fontSize: 26, fontWeight: 700, color: "#f1f5f9", lineHeight: 1.1 }}>{value}</div>
      {sub && <div style={{ fontSize: 12, color: "#94a3b8", marginTop: 2 }}>{sub}</div>}
    </div>
  );
}

export default function CoachAnalytics({ initialMatchId }) {
  const [matchId, setMatchId] = useState(initialMatchId || "");
  const [query, setQuery] = useState(initialMatchId || "");
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const fetchAnalytics = useCallback(async (id) => {
    if (!id) return;
    setLoading(true);
    setError(null);
    try {
      const resp = await axios.get(`${API_BASE}/api/analytics/match/${encodeURIComponent(id)}`);
      setData(resp.data);
    } catch (e) {
      setError(e?.response?.status === 404 ? "Match not found" : "Failed to load analytics");
      setData(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (initialMatchId) fetchAnalytics(initialMatchId);
  }, [initialMatchId, fetchAnalytics]);

  const downloadPlay = useCallback(
    async (playId) => {
      if (!matchId || !playId) return;
      try {
        const resp = await axios.get(
          `${API_BASE}/api/analytics/match/${encodeURIComponent(matchId)}/play/${encodeURIComponent(
            playId
          )}/export`
        );
        const blob = new Blob([JSON.stringify(resp.data, null, 2)], {
          type: "application/json",
        });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `replay_${matchId}_${playId}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      } catch (e) {
        // non-fatal; surface lightweight error
        setError("Failed to export play");
      }
    },
    [matchId]
  );

  const overall = data?.success_rates?.overall;
  const plays = data?.plays || [];

  const submit = (e) => {
    e.preventDefault();
    setMatchId(query.trim());
    fetchAnalytics(query.trim());
  };

  const byPlayerRows = useMemo(() => {
    const bp = data?.success_rates?.by_player || {};
    return Object.entries(bp);
  }, [data]);

  return (
    <div
      style={{
        minHeight: "100vh",
        background: "radial-gradient(1200px 600px at 20% -10%, rgba(126,34,206,0.18), transparent), #060910",
        color: "#e2e8f0",
        fontFamily: "Inter, system-ui, sans-serif",
        padding: "32px 24px 64px",
      }}
    >
      <div style={{ maxWidth: 1080, margin: "0 auto" }}>
        <div style={{ display: "flex", alignItems: "baseline", gap: 12, flexWrap: "wrap" }}>
          <h1
            style={{
              fontSize: 28,
              fontWeight: 800,
              margin: 0,
              background: "linear-gradient(90deg,#22d3ee,#a855f7)",
              WebkitBackgroundClip: "text",
              WebkitTextFillColor: "transparent",
            }}
          >
            Coach Analytics
          </h1>
          <span style={{ color: "#64748b", fontSize: 13 }}>per-play breakdown · success heatmaps · play export</span>
        </div>

        <form onSubmit={submit} style={{ display: "flex", gap: 10, marginTop: 20, flexWrap: "wrap" }}>
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Enter match_id"
            aria-label="Match ID"
            style={{
              flex: "1 1 260px",
              background: "rgba(15,23,42,0.9)",
              border: "1px solid rgba(34,211,238,0.25)",
              borderRadius: 10,
              color: "#e2e8f0",
              padding: "11px 14px",
              fontSize: 14,
              outline: "none",
            }}
          />
          <button
            type="submit"
            style={{
              background: "linear-gradient(90deg,#0891b2,#7c3aed)",
              border: "none",
              borderRadius: 10,
              color: "white",
              padding: "11px 22px",
              fontWeight: 600,
              cursor: "pointer",
            }}
          >
            Analyze
          </button>
        </form>

        {loading && <p style={{ color: "#7dd3fc", marginTop: 24 }}>Loading analytics…</p>}
        {error && (
          <p style={{ color: "#f87171", marginTop: 24 }} role="alert">
            {error}
          </p>
        )}

        {data && !loading && (
          <>
            {/* summary stats */}
            <div style={{ display: "flex", gap: 12, marginTop: 28, flexWrap: "wrap" }}>
              <StatCard label="Plays" value={data.play_count} sub={`${data.event_count} events`} />
              <StatCard
                label="Success rate"
                value={pct(overall?.success_rate)}
                sub={`${overall?.successes || 0}/${overall?.attempts || 0} made`}
              />
              <StatCard label="Points" value={overall?.points || 0} sub={`mode ${data.mode_id || "—"}`} />
              <StatCard
                label="Positioned"
                value={data.heatmap?.positioned_plays || 0}
                sub={`${data.heatmap?.unpositioned?.attempts || 0} unplaced`}
              />
            </div>

            <div style={{ display: "flex", gap: 28, marginTop: 32, flexWrap: "wrap" }}>
              {/* heatmap */}
              <div style={{ flex: "0 1 380px" }}>
                <h2 style={{ fontSize: 15, color: "#a855f7", marginBottom: 12, letterSpacing: 0.4 }}>
                  SUCCESS HEATMAP
                </h2>
                <Heatmap heatmap={data.heatmap} />
                <div style={{ display: "flex", alignItems: "center", gap: 10, marginTop: 12, fontSize: 12, color: "#94a3b8" }}>
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
                    <span style={{ width: 12, height: 12, borderRadius: 3, background: "hsla(190,85%,58%,0.85)" }} /> high success
                  </span>
                  <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
                    <span style={{ width: 12, height: 12, borderRadius: 3, background: "hsla(270,85%,58%,0.85)" }} /> low success
                  </span>
                  <span>· opacity = attempt density</span>
                </div>

                {byPlayerRows.length > 0 && (
                  <div style={{ marginTop: 24 }}>
                    <h2 style={{ fontSize: 15, color: "#a855f7", marginBottom: 10, letterSpacing: 0.4 }}>
                      BY PLAYER
                    </h2>
                    {byPlayerRows.map(([pid, b]) => (
                      <div
                        key={pid}
                        style={{
                          display: "flex",
                          justifyContent: "space-between",
                          padding: "8px 0",
                          borderBottom: "1px solid rgba(148,163,184,0.10)",
                          fontSize: 13,
                        }}
                      >
                        <span style={{ color: "#cbd5e1" }}>{pid}</span>
                        <span style={{ color: "#22d3ee" }}>
                          {b.successes}/{b.attempts} · {pct(b.success_rate)} · {b.points} pts
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* per-play list */}
              <div style={{ flex: "1 1 380px", minWidth: 300 }}>
                <h2 style={{ fontSize: 15, color: "#a855f7", marginBottom: 12, letterSpacing: 0.4 }}>
                  PER-PLAY BREAKDOWN
                </h2>
                {plays.length === 0 && (
                  <p style={{ color: "#64748b" }}>No plays recorded for this match yet.</p>
                )}
                <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                  {plays.map((p) => (
                    <div
                      key={p.play_id}
                      style={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "space-between",
                        gap: 12,
                        background: "rgba(15,23,42,0.6)",
                        border: `1px solid ${p.success ? "rgba(34,211,238,0.28)" : "rgba(168,85,247,0.22)"}`,
                        borderRadius: 10,
                        padding: "10px 14px",
                      }}
                    >
                      <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                        <span style={{ fontSize: 13, color: "#e2e8f0", fontWeight: 600 }}>
                          {p.type}{" "}
                          <span
                            style={{
                              fontSize: 11,
                              padding: "1px 7px",
                              borderRadius: 999,
                              marginLeft: 4,
                              background: p.success ? "rgba(34,211,238,0.18)" : "rgba(168,85,247,0.18)",
                              color: p.success ? "#67e8f9" : "#c4b5fd",
                            }}
                          >
                            {p.success ? "SUCCESS" : "MISS"}
                          </span>
                        </span>
                        <span style={{ fontSize: 12, color: "#94a3b8" }}>
                          {p.player_id || "—"} · {p.points} pts
                          {p.position ? ` · (${p.position.x.toFixed(2)}, ${p.position.y.toFixed(2)})` : " · no pos"}
                        </span>
                      </div>
                      <button
                        onClick={() => downloadPlay(p.play_id)}
                        style={{
                          background: "transparent",
                          border: "1px solid rgba(34,211,238,0.4)",
                          color: "#67e8f9",
                          borderRadius: 8,
                          padding: "6px 12px",
                          fontSize: 12,
                          cursor: "pointer",
                          whiteSpace: "nowrap",
                        }}
                      >
                        ↓ Replay
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
