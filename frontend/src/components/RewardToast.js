/**
 * RewardToast — animated XP / Shards / PRQ delta toast notification.
 * Usage:
 *   <RewardToast reward={reward} onDone={() => setReward(null)} />
 *   reward = { xp, shards, prq_delta }
 */
import React, { useEffect, useState } from "react";
import { Star, Zap } from "lucide-react";

export default function RewardToast({ reward, onDone }) {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    if (!reward) return;
    setVisible(true);
    const t = setTimeout(() => {
      setVisible(false);
      setTimeout(() => onDone?.(), 350);
    }, 3200);
    return () => clearTimeout(t);
  }, [reward, onDone]);

  if (!reward) return null;

  return (
    <div
      style={{
        position: "fixed",
        bottom: 24,
        right: 24,
        zIndex: 9999,
        transition: "opacity 350ms, transform 350ms",
        opacity: visible ? 1 : 0,
        transform: visible ? "translateY(0)" : "translateY(16px)",
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          background: "rgba(10,10,15,0.95)",
          border: "1px solid rgba(92,225,230,0.35)",
          borderRadius: 12,
          padding: "14px 20px",
          display: "flex",
          flexDirection: "column",
          gap: 8,
          minWidth: 200,
          boxShadow: "0 0 24px rgba(92,225,230,0.15)",
        }}
      >
        <div
          style={{
            fontSize: 9,
            fontFamily: "monospace",
            letterSpacing: "0.12em",
            color: "rgba(255,255,255,0.4)",
            textTransform: "uppercase",
          }}
        >
          SESSION REWARDS
        </div>
        <div style={{ display: "flex", gap: 20, alignItems: "center" }}>
          {reward.xp > 0 && (
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
              <Star style={{ width: 16, height: 16, color: "#fbbf24", marginBottom: 2 }} />
              <span
                style={{
                  fontFamily: "'Barlow Condensed', sans-serif",
                  fontSize: 22,
                  fontWeight: 900,
                  color: "#fbbf24",
                  lineHeight: 1,
                }}
              >
                +{reward.xp}
              </span>
              <span style={{ fontSize: 9, fontFamily: "monospace", color: "rgba(255,255,255,0.4)", letterSpacing: "0.1em" }}>
                XP
              </span>
            </div>
          )}
          {reward.shards > 0 && (
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
              <Zap style={{ width: 16, height: 16, color: "#5ce1e6", marginBottom: 2 }} />
              <span
                style={{
                  fontFamily: "'Barlow Condensed', sans-serif",
                  fontSize: 22,
                  fontWeight: 900,
                  color: "#5ce1e6",
                  lineHeight: 1,
                }}
              >
                +{reward.shards}
              </span>
              <span style={{ fontSize: 9, fontFamily: "monospace", color: "rgba(255,255,255,0.4)", letterSpacing: "0.1em" }}>
                SHARDS
              </span>
            </div>
          )}
          {reward.prq_delta !== undefined && (
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
              <div
                style={{
                  width: 16,
                  height: 16,
                  borderRadius: "50%",
                  background: reward.prq_delta >= 0 ? "rgba(52,211,153,0.2)" : "rgba(239,68,68,0.2)",
                  border: `1px solid ${reward.prq_delta >= 0 ? "#34d399" : "#ef4444"}`,
                  marginBottom: 2,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  fontSize: 9,
                  color: reward.prq_delta >= 0 ? "#34d399" : "#ef4444",
                }}
              >
                {reward.prq_delta >= 0 ? "▲" : "▼"}
              </div>
              <span
                style={{
                  fontFamily: "'Barlow Condensed', sans-serif",
                  fontSize: 22,
                  fontWeight: 900,
                  color: reward.prq_delta >= 0 ? "#34d399" : "#ef4444",
                  lineHeight: 1,
                }}
              >
                {reward.prq_delta >= 0 ? `+${reward.prq_delta}` : reward.prq_delta}
              </span>
              <span style={{ fontSize: 9, fontFamily: "monospace", color: "rgba(255,255,255,0.4)", letterSpacing: "0.1em" }}>
                PRQ Δ
              </span>
            </div>
          )}
        </div>
        {reward.pacing_bonus_applied && (
          <div
            style={{
              fontSize: 9,
              fontFamily: "monospace",
              color: "#34d399",
              letterSpacing: "0.1em",
              borderTop: "1px solid rgba(255,255,255,0.06)",
              paddingTop: 6,
            }}
          >
            ✓ PACING BONUS APPLIED
          </div>
        )}
      </div>
    </div>
  );
}
