/**
 * PRQRadarChart — SVG spider / radar chart for all 8 PRQ metrics.
 * Pure SVG, no extra dependencies.
 */
import React from "react";

const METRICS = [
  { key: "strength",   label: "STR", color: "#FF6B6B" },
  { key: "speed",      label: "SPD", color: "#4ECDC4" },
  { key: "endurance",  label: "END", color: "#45B7D1" },
  { key: "agility",    label: "AGI", color: "#96CEB4" },
  { key: "power",      label: "PWR", color: "#FFEAA7" },
  { key: "flexibility",label: "FLX", color: "#DDA0DD" },
  { key: "recovery",   label: "REC", color: "#98D8C8" },
  { key: "mental",     label: "MNT", color: "#F7DC6F" },
];

const CX = 120;
const CY = 120;
const R  = 90;
const LEVELS = 4;

function toCartesian(angle, radius) {
  const rad = (angle - 90) * (Math.PI / 180);
  return {
    x: CX + radius * Math.cos(rad),
    y: CY + radius * Math.sin(rad),
  };
}

function polyPoints(values) {
  return values
    .map((v, i) => {
      const angle = (360 / values.length) * i;
      const r = (v / 100) * R;
      const { x, y } = toCartesian(angle, r);
      return `${x},${y}`;
    })
    .join(" ");
}

export default function PRQRadarChart({ prq = {}, size = 240 }) {
  const values = METRICS.map((m) => Math.min(100, Math.max(0, prq[m.key] ?? 0)));
  const scale = size / 240;

  return (
    <div style={{ width: size, height: size, flexShrink: 0 }}>
      <svg
        viewBox="0 0 240 240"
        width={size}
        height={size}
        style={{ overflow: "visible" }}
      >
        {/* Grid rings */}
        {Array.from({ length: LEVELS }).map((_, l) => {
          const radius = ((l + 1) / LEVELS) * R;
          const pts = METRICS.map((_, i) => {
            const angle = (360 / METRICS.length) * i;
            const { x, y } = toCartesian(angle, radius);
            return `${x},${y}`;
          }).join(" ");
          return (
            <polygon
              key={l}
              points={pts}
              fill="none"
              stroke="rgba(255,255,255,0.06)"
              strokeWidth="1"
            />
          );
        })}

        {/* Axis spokes */}
        {METRICS.map((m, i) => {
          const angle = (360 / METRICS.length) * i;
          const { x, y } = toCartesian(angle, R);
          return (
            <line
              key={m.key}
              x1={CX}
              y1={CY}
              x2={x}
              y2={y}
              stroke="rgba(255,255,255,0.08)"
              strokeWidth="1"
            />
          );
        })}

        {/* Filled data polygon */}
        <polygon
          points={polyPoints(values)}
          fill="rgba(92,225,230,0.15)"
          stroke="#5ce1e6"
          strokeWidth="1.5"
          strokeLinejoin="round"
        />

        {/* Data point dots */}
        {values.map((v, i) => {
          const angle = (360 / values.length) * i;
          const r = (v / 100) * R;
          const { x, y } = toCartesian(angle, r);
          return (
            <circle
              key={i}
              cx={x}
              cy={y}
              r="3"
              fill={METRICS[i].color}
              stroke="#0a0a0f"
              strokeWidth="1"
            />
          );
        })}

        {/* Labels */}
        {METRICS.map((m, i) => {
          const angle = (360 / METRICS.length) * i;
          const { x, y } = toCartesian(angle, R + 16);
          return (
            <text
              key={m.key}
              x={x}
              y={y}
              textAnchor="middle"
              dominantBaseline="middle"
              fontSize="9"
              fontFamily="monospace"
              fontWeight="700"
              fill={m.color}
              style={{ letterSpacing: "0.08em" }}
            >
              {m.label}
            </text>
          );
        })}

        {/* Centre score */}
        {prq.overall_score !== null && prq.overall_score !== undefined && (
          <>
            <text
              x={CX}
              y={CY - 6}
              textAnchor="middle"
              fontSize="18"
              fontWeight="900"
              fontFamily="'Barlow Condensed', sans-serif"
              fill="#5ce1e6"
            >
              {Math.round(prq.overall_score)}
            </text>
            <text
              x={CX}
              y={CY + 10}
              textAnchor="middle"
              fontSize="7"
              fontFamily="monospace"
              fill="rgba(255,255,255,0.4)"
              style={{ letterSpacing: "0.12em" }}
            >
              PRQ
            </text>
          </>
        )}
      </svg>
    </div>
  );
}
