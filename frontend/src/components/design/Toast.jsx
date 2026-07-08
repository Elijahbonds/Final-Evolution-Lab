import React, { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { motionMs, prefersReducedMotion } from "@/design/tokens";
import styles from "./Toast.module.css";

/**
 * Toast — slide-up + fade notification, auto-dismisses.
 *
 * Presentational unit: <Toast tone="success" onDismiss={...}>Saved</Toast>
 * Stack manager:      <ToastStack toasts={[{id, tone, message}]} onDismiss={id => ...} />
 *
 * tone: "info" (cyan) | "success" | "danger" | "warning"
 * duration: ms before auto-dismiss (default 4000; 0 = sticky).
 */
export function Toast({ tone = "info", duration = 4000, onDismiss, children }) {
  const [leaving, setLeaving] = useState(false);

  useEffect(() => {
    if (!duration) return;
    const t = setTimeout(() => setLeaving(true), duration);
    return () => clearTimeout(t);
  }, [duration]);

  useEffect(() => {
    if (!leaving) return;
    const exitMs = prefersReducedMotion() ? 0 : motionMs.normal;
    const t = setTimeout(() => onDismiss && onDismiss(), exitMs);
    return () => clearTimeout(t);
  }, [leaving, onDismiss]);

  return (
    <div
      className={[styles.toast, styles[tone] || "", leaving ? styles.leaving : ""].filter(Boolean).join(" ")}
      role="status"
    >
      <span className={styles.message}>{children}</span>
      <button
        type="button"
        className={styles.dismiss}
        aria-label="Dismiss notification"
        onClick={() => setLeaving(true)}
      >
        ×
      </button>
    </div>
  );
}

/**
 * ToastStack — fixed bottom-center column. Owns nothing; the caller keeps the
 * toasts array in state and removes entries in onDismiss(id).
 */
export function ToastStack({ toasts = [], onDismiss }) {
  if (typeof document === "undefined") return null;
  return createPortal(
    <div className={styles.stack} aria-live="polite">
      {toasts.map((t) => (
        <Toast key={t.id} tone={t.tone} duration={t.duration} onDismiss={() => onDismiss && onDismiss(t.id)}>
          {t.message}
        </Toast>
      ))}
    </div>,
    document.body,
  );
}

export default Toast;
