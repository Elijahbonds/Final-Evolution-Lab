import React from "react";
import { useHUDStream } from "@/hooks/useHUDStream";
import { getStoredUserId } from "@/lib/apiClient";

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

function pct(value) {
  return `${Math.round(Math.max(0, Math.min(1, Number(value) || 0)) * 100)}%`;
}

export default function Phase3HUD() {
  const userId = getStoredUserId();
  const { frame, connected, status, reconnect } = useHUDStream(userId);
  const hud = frame || fallbackFrame;
  const playerScore = hud.scores?.player ?? hud.home_score ?? 0;
  const opponentScore = hud.scores?.opponent ?? hud.away_score ?? 0;

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

