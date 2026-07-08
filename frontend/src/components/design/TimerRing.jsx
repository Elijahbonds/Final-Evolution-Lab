import React from "react";
import styles from "./TimerRing.module.css";

/**
 * TimerRing — SVG radial countdown / progress ring.
 *
 * progress: 0..1 fraction REMAINING (1 = full ring, 0 = empty).
 * Color shifts cyan -> warning (<50%) -> danger (<25%, with pulse).
 * The dash offset animates via CSS (--fel-motion-slow), so feeding it
 * once-per-second updates still renders a smooth sweep.
 *
 * size: outer px. strokeWidth: ring thickness px.
 * children: center label (e.g. "0:42"); defaults to nothing.
 */
export default function TimerRing({
  progress = 1,
  size = 96,
  strokeWidth = 8,
  className = "",
  children,
  ...rest
}) {
  const p = Math.min(1, Math.max(0, progress));
  const r = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * r;
  const offset = circumference * (1 - p);
  const tone = p < 0.25 ? styles.danger : p < 0.5 ? styles.warning : "";
  const fontSize = Math.max(12, Math.round(size * 0.24));

  return (
    <div
      className={[styles.wrap, tone, className].filter(Boolean).join(" ")}
      style={{ width: size, height: size }}
      role="timer"
      aria-valuemin={0}
      aria-valuemax={1}
      aria-valuenow={Number(p.toFixed(3))}
      {...rest}
    >
      <svg className={styles.svg} width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        <circle className={styles.track} cx={size / 2} cy={size / 2} r={r} strokeWidth={strokeWidth} />
        <circle
          className={styles.progress}
          cx={size / 2}
          cy={size / 2}
          r={r}
          strokeWidth={strokeWidth}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
        />
      </svg>
      {children != null && (
        <div className={styles.label} style={{ fontSize }}>
          {children}
        </div>
      )}
    </div>
  );
}
