import React from "react";
import styles from "./SkeletonShimmer.module.css";

/**
 * SkeletonShimmer — loading placeholder with a sweeping shimmer.
 *
 * width/height: CSS sizes (default 100% x 16px).
 * radius: CSS radius (use "var(--fel-radius-round)" + equal w/h for avatars).
 * lines: >1 renders a stack of text-like rows (last one shortened).
 * Under prefers-reduced-motion the sweep freezes to a static tint.
 */
export default function SkeletonShimmer({
  width = "100%",
  height = 16,
  radius = "var(--fel-radius-sm)",
  lines = 1,
  className = "",
  style,
  ...rest
}) {
  if (lines > 1) {
    return (
      <div className={styles.stackWrap} aria-hidden="true" {...rest}>
        {Array.from({ length: lines }).map((_, i) => (
          <div
            key={i}
            className={`${styles.skeleton} ${className}`}
            style={{
              width: i === lines - 1 ? "60%" : width,
              height,
              borderRadius: radius,
              ...style,
            }}
          />
        ))}
      </div>
    );
  }
  return (
    <div
      className={`${styles.skeleton} ${className}`}
      style={{ width, height, borderRadius: radius, ...style }}
      aria-hidden="true"
      {...rest}
    />
  );
}
