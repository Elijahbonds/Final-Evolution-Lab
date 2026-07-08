import React from "react";
import styles from "./FELCard.module.css";

/**
 * FELCard — elevation-1 surface, 12px radius.
 *
 * interactive: adds hover/tap scale(1.02) + elevation lift. Pass onClick to
 * make it clickable (renders tabIndex + keyboard activation for a11y).
 * glow: "cyan" | "purple" — accent glow on hover (interactive only).
 */
const FELCard = React.forwardRef(function FELCard(
  { interactive = false, glow, className = "", children, onClick, ...rest },
  ref,
) {
  const clickable = interactive && typeof onClick === "function";
  const cls = [
    styles.card,
    interactive ? styles.interactive : "",
    glow === "cyan" ? styles.glowCyan : "",
    glow === "purple" ? styles.glowPurple : "",
    className,
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <div
      ref={ref}
      className={cls}
      onClick={onClick}
      {...(clickable
        ? {
            role: "button",
            tabIndex: 0,
            onKeyDown: (e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onClick(e);
              }
            },
          }
        : {})}
      {...rest}
    >
      {children}
    </div>
  );
});

export default FELCard;
