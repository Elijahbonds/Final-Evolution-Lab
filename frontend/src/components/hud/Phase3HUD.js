import React, { useEffect, useRef, useState } from "react";
import { useHUDStream } from "@/hooks/useHUDStream";
import { getStoredUserId, API_URL } from "@/lib/apiClient";
import axios from "axios";

const fallbackFrame = {
  frame: 0,
  mode_id: "basketball_h2h",
  scores: { player: 0, opponent: 0 },
  shot_clock: 24,
  player: { state: "Awaiting UE", stamina: 1 },
  combo: { chain_length: 0, multiplier: 1, decay_remaining: 0, last_grade: "READY" },
  prq: { score: 75.6, grade: "PRIMED", neural_drive: 62, hud_color: "#00E5FF" },
  mri: { score: 72.4, grade: "RESILIENT", strain_flagged: false, aura: "cyan_glow" },
  focus_streak: 0,
  takeover_meter: 0,
  dda: { difficulty_tier: "READY" },
};

const PULSE_HISTORY_MAX = 60;

function pct(value) {
  return `${Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * 100)}%`;
}

// Sparkline SVG for last-60s history of a metric
function Sparkline({ history, color = "#22d3ee", height = 32, width = 120 }) {
  if (!history || history.length < 2) return null;
  const max = Math.max(...history, 0.01);
  const pts = history
    .map((v, i) => {
      const x = (i / (history.length - 1)) * width;
      const y = height - (v / max) * height;
      return `${x},${y}`;
    })
    .join(" ");
  return (
    <svg width={width} height={height} style={{ display: "block" }}>
      <polyline points={pts} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" />
    </svg>
  );
}

// Horizontal bar graph for a single pulse metric
function PulseBar({ label, value, max = 1, color = "#22d3ee", unit = "" }) {
  const pctVal = Math.min(1, Math.max(0, (value || 0) / (max || 1)));
  return (
    <div style={{ marginBottom: 8 }}>
      <div style={{ display: "flex", justifyContent: "space-between", fontSize: 9, fontFamily: "monospace", marginBottom: 2, color: "rgba(255,255,255,0.5)", letterSpacing: "0.08em" }}>
        <span>{label}</span>
        <span style={{ color }}>{typeof value === "number" ? value.toFixed(2) : value}{unit}</span>
      </div>
      <div style={{ height: 4, background: "rgba(255,255,255,0.06)", borderRadius: 2, overflow: "hidden" }}>
        <div style={{ height: "100%", width: `${pctVal * 100}%`, background: color, borderRadius: 2, transition: "width 300ms ease" }} />
      </div>
    </div>
  );
}

export default function Phase3HUD() {
  const userId = getStoredUserId();
  const { frame, connected, status, reconnect } = useHUDStream(userId);
  const hud = frame || fallbackFrame;
  const playerScore = hud.scores?.player ?? hud.home_score ?? 0;
  const opponentScore = hud.scores?.opponent ?? hud.away_score ?? 0;

  // Live telemetry polling (500ms)
  const [pulse, setPulse] = useState(null);
  const [pulseHistory, setPulseHistory] = useState({
    impulse_y: [],
    breath_boost: [],
    catch_radius_normalized: [],
  });

  useEffect(() => {
    let active = true;
    const poll = async () => {
      try {
        const r = await axios.get(`${API_URL}/telemetry/live`);
        const p = r.data?.telemetry?.last_pulse || r.data?.last_pulse || null;
        if (!p || !active) return;
        setPulse(p);
        setPulseHistory((prev) => ({
          impulse_y: [...prev.impulse_y, p.impulse_y ?? 0].slice(-PULSE_HISTORY_MAX),
          breath_boost: [...prev.breath_boost, p.breath_boost ?? 0].slice(-PULSE_HISTORY_MAX),
          catch_radius_normalized: [...prev.catch_radius_normalized, p.catch_radius_normalized ?? 0].slice(-PULSE_HISTORY_MAX),
        }));
      } catch {
        // telemetry unavailable — keep showing last known
      }
    };
    const iv = setInterval(poll, 500);
    poll();
    return () => { active = false; clearInterval(iv); };
  }, []);

  return (
    <main className="phase3-hud">
      <section className="hud-score-strip">
        <div className="hud-score">{playerScore}</div>
        <div className="hud-score-center">
          <span className={`hud-dot ${connected ? "online" : "offline"}`} />
          <span>{hud.mode_id || "arena"}</span>
          <small>{connected ? `LIVE FRAME ${hud.frame ?? "--"}` : `HUD ${status.toUpperCase()}`}</small>
        </div>
        <div className="hud-score opponent">{opponentScore}</div>
      </section>

      <section className="hud-left-stack">
        <div className="hud-card">
          <span className="hud-label">COMBO</span>
          <strong>{hud.combo?.chain_length ?? 0}</strong>
          <small>{hud.combo?.last_grade ?? "READY"} · x{hud.combo?.multiplier ?? 1}</small>
        </div>
        <div className="hud-card">
          <span className="hud-label">FOCUS</span>
          <strong>{hud.focus_streak ?? 0}</strong>
          <small>streak</small>
        </div>
      </section>

      <section className="hud-right-stack">
        <div className="hud-meter-card">
          <span className="hud-label">PRQ</span>
          <strong style={{ color: hud.prq?.hud_color || "var(--primary)" }}>
            {(hud.prq?.score ?? 0).toFixed(1)}
          </strong>
          <small>{hud.prq?.grade ?? "READY"}</small>
        </div>
        <div className="hud-meter-card">
          <span className="hud-label">MRI</span>
          <strong>{(hud.mri?.score ?? 0).toFixed(1)}</strong>
          <small>{hud.mri?.grade ?? "ADAPTING"}</small>
        </div>
        <div className="hud-card">
          <span className="hud-label">TAKEOVER</span>
          <div className="hud-progress">
            <div style={{ width: pct(hud.takeover_meter) }} />
          </div>
          <small>{pct(hud.takeover_meter)}</small>
        </div>
      </section>

      {/* Pulse Envelope Panel */}
      {pulse && (
        <section
          style={{
            position: "absolute",
            bottom: 60,
            left: "50%",
            transform: "translateX(-50%)",
            background: "rgba(5,5,15,0.85)",
            border: "1px solid rgba(92,225,230,0.2)",
            borderRadius: 8,
            padding: "10px 16px",
            minWidth: 280,
            backdropFilter: "blur(6px)",
          }}
        >
          <div style={{ fontSize: 8, fontFamily: "monospace", letterSpacing: "0.2em", color: "rgba(255,255,255,0.35)", marginBottom: 8, textTransform: "uppercase" }}>
            LIVE PULSE ENVELOPE
          </div>
          <PulseBar label="IMPULSE Y" value={pulse.impulse_y} max={20} color="#5ce1e6" />
          <PulseBar label="BREATH BOOST" value={pulse.breath_boost} max={0.15} color="#34d399" unit="%" />
          <PulseBar label="CATCH RADIUS" value={pulse.catch_radius_normalized} max={1} color="#a78bfa" />
          <div style={{ marginTop: 6, display: "flex", gap: 16 }}>
            <div>
              <div style={{ fontSize: 8, fontFamily: "monospace", color: "rgba(255,255,255,0.3)", marginBottom: 2 }}>LAST 60s IMPULSE</div>
              <Sparkline history={pulseHistory.impulse_y} color="#5ce1e6" width={100} />
            </div>
            <div>
              <div style={{ fontSize: 8, fontFamily: "monospace", color: "rgba(255,255,255,0.3)", marginBottom: 2 }}>LAST 60s BREATH</div>
              <Sparkline history={pulseHistory.breath_boost} color="#34d399" width={100} />
            </div>
          </div>
          <div style={{ marginTop: 6, fontSize: 8, fontFamily: "monospace", color: "rgba(255,255,255,0.25)" }}>
            CATCH GRADE: {pulse.catch_feedback ?? "—"} · SOURCE: {pulse.source ?? "live"}
          </div>
        </section>
      )}

      <section className="hud-bottom-strip">
        <span>STATE: {hud.player?.state ?? "Ready"}</span>
        <span>STAMINA: {pct(hud.player?.stamina ?? 1)}</span>
        <span>DDA: {hud.dda?.difficulty_tier ?? "READY"}</span>
        {!connected && (
          <button type="button" onClick={reconnect}>
            Reconnect
          </button>
        )}
      </section>
    </main>
  );
}

