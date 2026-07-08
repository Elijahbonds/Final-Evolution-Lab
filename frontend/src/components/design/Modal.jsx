import React, { useCallback, useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { motionMs, prefersReducedMotion } from "@/design/tokens";
import styles from "./Modal.module.css";

/**
 * Modal — dim + blur backdrop, scale+fade panel at --fel-motion-normal.
 *
 * open: controls visibility (exit animation plays before unmount).
 * onClose: called on ESC, backdrop click, or programmatic close.
 * title: optional display-font heading.
 *
 * Rendered into document.body via portal.
 */
export default function Modal({ open, onClose, title, children, className = "" }) {
  const [mounted, setMounted] = useState(open);
  const [closing, setClosing] = useState(false);
  const panelRef = useRef(null);

  const exitMs = () => (prefersReducedMotion() ? 0 : motionMs.normal);

  useEffect(() => {
    if (open) {
      setMounted(true);
      setClosing(false);
    } else if (mounted) {
      setClosing(true);
      const t = setTimeout(() => {
        setMounted(false);
        setClosing(false);
      }, exitMs());
      return () => clearTimeout(t);
    }
  }, [open, mounted]);

  const handleKey = useCallback(
    (e) => {
      if (e.key === "Escape" && onClose) onClose();
    },
    [onClose],
  );

  useEffect(() => {
    if (!mounted) return;
    document.addEventListener("keydown", handleKey);
    const el = panelRef.current;
    if (el) el.focus({ preventScroll: true });
    return () => document.removeEventListener("keydown", handleKey);
  }, [mounted, handleKey]);

  if (!mounted) return null;

  return createPortal(
    <div
      className={`${styles.backdrop} ${closing ? styles.closing : ""}`}
      onMouseDown={(e) => {
        if (e.target === e.currentTarget && onClose) onClose();
      }}
    >
      <div
        ref={panelRef}
        className={`${styles.panel} ${className}`}
        role="dialog"
        aria-modal="true"
        aria-label={typeof title === "string" ? title : undefined}
        tabIndex={-1}
      >
        {title != null && <h2 className={styles.title}>{title}</h2>}
        {children}
      </div>
    </div>,
    document.body,
  );
}
