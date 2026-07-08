import React, { useEffect, useRef, useState } from "react";
import styles from "./ScoreOdometer.module.css";

/**
 * ScoreOdometer — rolling-digit score roll-up.
 *
 * Each digit is a vertical 0-9 reel translated to the current digit; digit
 * changes roll over --fel-motion-slow with a per-digit stagger, and the whole
 * number does a subtle scale bump on change.
 *
 * value: non-negative integer.
 * minDigits: zero-pad width (padding digits render dimmed).
 * fontSize: any CSS size (default 36px = --fel-text-2xl-size).
 */
const REEL = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

export default function ScoreOdometer({
  value = 0,
  minDigits = 4,
  fontSize = "var(--fel-text-2xl-size)",
  className = "",
  ...rest
}) {
  const safe = Math.max(0, Math.floor(Number(value) || 0));
  const str = String(safe).padStart(minDigits, "0");
  const padCount = Math.max(0, str.length - String(safe).length);

  const [bump, setBump] = useState(false);
  const prev = useRef(safe);
  useEffect(() => {
    if (prev.current !== safe) {
      prev.current = safe;
      setBump(true);
      const t = setTimeout(() => setBump(false), 300);
      return () => clearTimeout(t);
    }
  }, [safe]);

  return (
    <span
      className={[styles.odometer, bump ? styles.bumping : "", className].filter(Boolean).join(" ")}
      style={{ fontSize }}
      role="status"
      aria-label={String(safe)}
      {...rest}
    >
      {str.split("").map((ch, i) => (
        <span key={str.length - i} className={styles.digitWindow} aria-hidden="true">
          <span
            className={styles.reel}
            style={{
              transform: `translateY(-${Number(ch)}em)`,
              transitionDelay: `calc(var(--fel-motion-stagger) * ${str.length - 1 - i})`,
            }}
          >
            {REEL.map((d) => (
              <span key={d} className={`${styles.reelDigit} ${i < padCount ? styles.dim : ""}`}>
                {d}
              </span>
            ))}
          </span>
        </span>
      ))}
    </span>
  );
}
