import React from "react";
import styles from "./StatBar.module.css";

/**
 * StatBar — health/stamina style meter.
 *
 * value / max: current and maximum (fill = value/max).
 * Fill eases over --fel-motion-slow; color steps green -> yellow (<50%)
 * -> red (<20%) with a --fel-motion-normal cross-fade.
 *
 * label: small uppercase caption ("HEALTH").
 * showValue: prints "72 / 100" on the right.
 */
export default function StatBar({
  value = 100,
  max = 100,
  label,
  showValue = true,
  className = "",
  ...rest
}) {
  const clamped = Math.min(max, Math.max(0, value));
  const pct = max > 0 ? clamped / max : 0;
  const tone = pct < 0.2 ? styles.danger : pct < 0.5 ? styles.warning : "";

  return (
    <div
      className={[styles.wrap, tone, className].filter(Boolean).join(" ")}
      role="meter"
      aria-label={label || "stat"}
      aria-valuemin={0}
      aria-valuemax={max}
      aria-valuenow={clamped}
      {...rest}
    >
      {(label || showValue) && (
        <div className={styles.header}>
          <span className={styles.label}>{label}</span>
          {showValue && (
            <span className={styles.value}>
              {Math.round(clamped)} / {max}
            </span>
          )}
        </div>
      )}
      <div className={styles.track}>
        <div className={styles.fill} style={{ width: `${pct * 100}%` }} />
      </div>
    </div>
  );
}
