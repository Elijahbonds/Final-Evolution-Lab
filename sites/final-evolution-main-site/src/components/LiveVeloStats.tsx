import { useEffect, useMemo, useState } from "react";

export type LiveVeloStatsProps = {
  stiffnessKnPerM?: number;
  neuralDrivePct?: number;
  penultimateStretchMs?: number;
  /** Points per series for SVG sparkline */
  historyLength?: number;
  className?: string;
};

function clamp(n: number, lo: number, hi: number) {
  return Math.min(hi, Math.max(lo, n));
}

function buildSparkline(values: number[], width: number, height: number): string {
  if (values.length < 2) return "";
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const step = width / (values.length - 1);
  return values
    .map((v, i) => {
      const x = i * step;
      const y = height - ((v - min) / span) * height;
      return `${i === 0 ? "M" : "L"} ${x.toFixed(2)} ${y.toFixed(2)}`;
    })
    .join(" ");
}

function StatPanel({
  label,
  unit,
  value,
  color,
  history,
  gradientId,
}: {
  label: string;
  unit: string;
  value: number;
  color: string;
  history: number[];
  gradientId: string;
}) {
  const w = 160;
  const h = 48;
  const path = useMemo(() => buildSparkline(history, w, h), [history]);

  return (
    <div className="rounded-xl border border-white/10 bg-black/40 p-4 backdrop-blur-sm">
      <p className="text-[0.55rem] font-bold uppercase tracking-[0.28em] text-white/50">{label}</p>
      <div className="mt-1 flex items-baseline gap-2">
        <span className="font-mono text-2xl font-black tabular-nums text-white" style={{ textShadow: `0 0 20px ${color}44` }}>
          {value.toFixed(1)}
        </span>
        <span className="text-xs font-medium text-white/40">{unit}</span>
      </div>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="mt-3 w-full"
        preserveAspectRatio="none"
        aria-hidden
      >
        <defs>
          <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.35" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path
          d={`${path} L ${w} ${h} L 0 ${h} Z`}
          fill={`url(#${gradientId})`}
          opacity={0.6}
        />
        <path d={path} fill="none" stroke={color} strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
        <line x1="0" y1={h} x2={w} y2={h} stroke="rgba(255,255,255,0.08)" strokeWidth="1" />
      </svg>
    </div>
  );
}

/**
 * Live velocity / neuromechanical HUD — dynamic SVG sparklines (demo drift when uncontrolled).
 */
export function LiveVeloStats({
  stiffnessKnPerM = 42.5,
  neuralDrivePct = 78.2,
  penultimateStretchMs = 16.6,
  historyLength = 32,
  className = "",
}: LiveVeloStatsProps) {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const id = window.setInterval(() => setTick((t) => t + 1), 1200);
    return () => window.clearInterval(id);
  }, []);

  const stiffnessHist = useMemo(() => {
    const base = stiffnessKnPerM;
    return Array.from({ length: historyLength }, (_, i) => {
      const phase = (i + tick) * 0.35;
      return base + Math.sin(phase) * 4 + (Math.random() - 0.5) * 1.2;
    });
  }, [stiffnessKnPerM, historyLength, tick]);

  const neuralHist = useMemo(() => {
    const base = neuralDrivePct;
    return Array.from({ length: historyLength }, (_, i) => {
      const phase = (i + tick) * 0.28;
      return clamp(base + Math.sin(phase) * 6 + (Math.random() - 0.5) * 2, 0, 100);
    });
  }, [neuralDrivePct, historyLength, tick]);

  const penultimateHist = useMemo(() => {
    const base = penultimateStretchMs;
    return Array.from({ length: historyLength }, (_, i) => {
      const phase = (i + tick) * 0.5;
      return clamp(base + Math.sin(phase) * 1.4 + (Math.random() - 0.5) * 0.4, 12, 22);
    });
  }, [penultimateStretchMs, historyLength, tick]);

  return (
    <div className={`grid gap-4 sm:grid-cols-3 ${className}`}>
      <StatPanel
        gradientId="fel-grad-stiff"
        label="Reactive stiffness"
        unit="kN/m"
        value={stiffnessHist[stiffnessHist.length - 1] ?? stiffnessKnPerM}
        color="#5ce1e6"
        history={stiffnessHist}
      />
      <StatPanel
        gradientId="fel-grad-neural"
        label="Neural drive"
        unit="%"
        value={neuralHist[neuralHist.length - 1] ?? neuralDrivePct}
        color="#fcee0a"
        history={neuralHist}
      />
      <StatPanel
        gradientId="fel-grad-penultimate"
        label="Penultimate stretch"
        unit="ms"
        value={penultimateHist[penultimateHist.length - 1] ?? penultimateStretchMs}
        color="#ff3355"
        history={penultimateHist}
      />
    </div>
  );
}
