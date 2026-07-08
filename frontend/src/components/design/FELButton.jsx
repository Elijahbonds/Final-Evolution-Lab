import React from "react";
import styles from "./FELButton.module.css";

/**
 * FELButton — core action button.
 *
 * variant: "primary" (filled cyan) | "ghost" (outline) | "danger"
 * size: "sm" | "md" | "lg" (all keep a >=44px touch target)
 * block: full-width
 *
 * Press feedback: 0.96 scale over --fel-motion-fast (120ms).
 */
const FELButton = React.forwardRef(function FELButton(
  { variant = "primary", size = "md", block = false, className = "", children, ...rest },
  ref,
) {
  const cls = [
    styles.button,
    styles[variant] || styles.primary,
    size !== "md" ? styles[size] : "",
    block ? styles.block : "",
    className,
  ]
    .filter(Boolean)
    .join(" ");
  return (
    <button ref={ref} type="button" className={cls} {...rest}>
      {children}
    </button>
  );
});

export default FELButton;
