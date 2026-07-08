import React, { useEffect, useRef, useState } from "react";
import felTokens, { motion, audio } from "@/design/tokens";
import {
  TimerRing,
  ScoreOdometer,
  StatBar,
  FELButton,
  FELCard,
  Modal,
  ToastStack,
  SkeletonShimmer,
} from "./index";
import styles from "./DesignPlayground.module.css";

/**
 * /design-playground — dev-only living reference for the FELDesign kit.
 * Renders every token group and every component in every state.
 * This page substitutes for Storybook; keep it in sync as components land.
 */

const SWATCHES = [
  "ink",
  "surface-1",
  "surface-2",
  "surface-3",
  "accent-primary",
  "accent-secondary",
  "success",
  "danger",
  "warning",
];

const SPACES = ["1", "2", "3", "4", "5", "6", "7", "8"];

function Section({ title, children }) {
  return (
    <section className={styles.section}>
      <h2 className={styles.sectionTitle}>{title}</h2>
      {children}
    </section>
  );
}

let toastSeq = 0;

export default function DesignPlayground() {
  // Timer demo: loops 30s -> 0.
  const [timer, setTimer] = useState(0.82);
  const timerRef = useRef(null);
  const [timerRunning, setTimerRunning] = useState(true);
  useEffect(() => {
    if (!timerRunning) return;
    timerRef.current = setInterval(() => {
      setTimer((t) => (t <= 0.02 ? 1 : t - 1 / 30));
    }, 1000);
    return () => clearInterval(timerRef.current);
  }, [timerRunning]);

  const [score, setScore] = useState(12480);
  const [health, setHealth] = useState(78);
  const [stamina, setStamina] = useState(42);
  const [modalOpen, setModalOpen] = useState(false);
  const [toasts, setToasts] = useState([]);

  const pushToast = (tone, message) =>
    setToasts((list) => [...list, { id: ++toastSeq, tone, message }]);
  const dismissToast = (id) => setToasts((list) => list.filter((t) => t.id !== id));

  return (
    <div className={styles.page}>
      <div className={styles.inner}>
        <header>
          <h1 className={styles.pageTitle}>
            FEL<span>Design</span> Playground
          </h1>
          <p className={styles.subtitle}>
            Living reference for infra/design_tokens.json + the HUD component kit. Dev builds only.
            Toggle OS reduce-motion to verify instant-motion fallbacks.
          </p>
        </header>

        <Section title="Color tokens">
          <div className={styles.swatchGrid}>
            {SWATCHES.map((name) => (
              <div key={name} className={styles.swatch}>
                <div
                  className={styles.swatchChip}
                  style={{ background: `var(--fel-color-${name})` }}
                />
                <div className={styles.swatchMeta}>
                  <span className={styles.swatchName}>--fel-color-{name}</span>
                  <span className={styles.swatchValue}>{felTokens.color[name]}</span>
                </div>
              </div>
            ))}
          </div>
        </Section>

        <Section title="Type ramp">
          {["3xl", "2xl", "xl", "lg", "base", "sm"].map((step) => (
            <p
              key={step}
              className={styles.typeRow}
              style={{
                fontSize: `var(--fel-text-${step}-size)`,
                lineHeight: `var(--fel-text-${step}-line)`,
                fontWeight: `var(--fel-text-${step}-weight)`,
                letterSpacing: `var(--fel-text-${step}-tracking)`,
                fontFamily:
                  step === "3xl" || step === "2xl" ? "var(--fel-font-display)" : "var(--fel-font-ui)",
              }}
            >
              {step} — Final Evolution Lab
            </p>
          ))}
        </Section>

        <Section title="Spacing (8pt grid)">
          {SPACES.map((s) => (
            <div key={s} className={styles.spacingRow}>
              <span className={styles.spacingLabel}>--fel-space-{s} ({felTokens.space[s]})</span>
              <div className={styles.spacingBlock} style={{ width: `var(--fel-space-${s})` }} />
            </div>
          ))}
        </Section>

        <Section title="Motion + audio tokens">
          <table className={styles.motionTable}>
            <thead>
              <tr>
                <th>token</th>
                <th>value</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(motion).map(([k, v]) => (
                <tr key={k}>
                  <td>motion.{k}</td>
                  <td>{v}</td>
                </tr>
              ))}
              {Object.entries(audio).map(([k, v]) => (
                <tr key={k}>
                  <td>audio.{k}</td>
                  <td>{v} dB</td>
                </tr>
              ))}
            </tbody>
          </table>
        </Section>

        <Section title="TimerRing">
          <div className={styles.row}>
            <TimerRing progress={timer} size={112}>
              {Math.max(0, Math.round(timer * 30))}s
            </TimerRing>
            <TimerRing progress={0.72} size={80}>
              72%
            </TimerRing>
            <TimerRing progress={0.4} size={80}>
              40%
            </TimerRing>
            <TimerRing progress={0.12} size={80}>
              12%
            </TimerRing>
            <TimerRing progress={0.55} size={48} strokeWidth={5} />
          </div>
          <div className={styles.controls}>
            <FELButton variant="ghost" size="sm" onClick={() => setTimerRunning((r) => !r)}>
              {timerRunning ? "Pause loop" : "Resume loop"}
            </FELButton>
            <FELButton variant="ghost" size="sm" onClick={() => setTimer(1)}>
              Reset to 30s
            </FELButton>
          </div>
          <p className={styles.caption}>Cyan above 50%, warning below 50%, danger + pulse below 25%.</p>
        </Section>

        <Section title="ScoreOdometer">
          <div className={styles.row}>
            <ScoreOdometer value={score} minDigits={6} fontSize="var(--fel-text-3xl-size)" />
            <ScoreOdometer value={score % 1000} minDigits={4} />
          </div>
          <div className={styles.controls}>
            <FELButton size="sm" onClick={() => setScore((s) => s + 250)}>
              +250
            </FELButton>
            <FELButton size="sm" onClick={() => setScore((s) => s + Math.floor(Math.random() * 5000))}>
              +random
            </FELButton>
            <FELButton variant="ghost" size="sm" onClick={() => setScore(0)}>
              Reset
            </FELButton>
          </div>
        </Section>

        <Section title="StatBar">
          <div className={`${styles.row} ${styles.rowStart}`}>
            <div className={styles.statCol}>
              <StatBar label="Health" value={health} max={100} />
              <StatBar label="Stamina" value={stamina} max={100} />
              <StatBar label="No value readout" value={64} max={100} showValue={false} />
            </div>
            <div className={styles.statCol}>
              <StatBar label="Healthy (&gt;50%)" value={86} max={100} />
              <StatBar label="Caution (&lt;50%)" value={38} max={100} />
              <StatBar label="Critical (&lt;20%)" value={11} max={100} />
            </div>
          </div>
          <div className={styles.controls}>
            <FELButton
              variant="danger"
              size="sm"
              onClick={() => {
                setHealth((h) => Math.max(0, h - 18));
                setStamina((s) => Math.max(0, s - 12));
              }}
            >
              Take damage
            </FELButton>
            <FELButton
              variant="ghost"
              size="sm"
              onClick={() => {
                setHealth(100);
                setStamina(100);
              }}
            >
              Full restore
            </FELButton>
          </div>
        </Section>

        <Section title="FELButton">
          <div className={styles.row}>
            <FELButton>Primary</FELButton>
            <FELButton variant="ghost">Ghost</FELButton>
            <FELButton variant="danger">Danger</FELButton>
            <FELButton disabled>Disabled</FELButton>
            <FELButton variant="ghost" disabled>
              Ghost disabled
            </FELButton>
          </div>
          <div className={styles.row}>
            <FELButton size="sm">Small</FELButton>
            <FELButton size="md">Medium</FELButton>
            <FELButton size="lg">Large</FELButton>
          </div>
          <p className={styles.caption}>44px minimum touch target on every size; 120ms press scale to 0.96.</p>
        </Section>

        <Section title="FELCard">
          <div className={styles.cardGrid}>
            <FELCard>
              <p className={styles.cardTitle}>Static</p>
              <p className={styles.cardBody}>Elevation-1, 12px radius, surface-2 fill.</p>
            </FELCard>
            <FELCard interactive onClick={() => pushToast("info", "Card tapped")}>
              <p className={styles.cardTitle}>Interactive</p>
              <p className={styles.cardBody}>Hover/tap scales to 1.02 and lifts to elevation-2.</p>
            </FELCard>
            <FELCard interactive glow="cyan" onClick={() => pushToast("info", "Cyan glow card")}>
              <p className={styles.cardTitle}>Cyan glow</p>
              <p className={styles.cardBody}>Primary-accent hover glow.</p>
            </FELCard>
            <FELCard interactive glow="purple" onClick={() => pushToast("info", "Purple glow card")}>
              <p className={styles.cardTitle}>Purple glow</p>
              <p className={styles.cardBody}>Secondary-accent hover glow.</p>
            </FELCard>
          </div>
        </Section>

        <Section title="Modal">
          <div className={styles.controls}>
            <FELButton onClick={() => setModalOpen(true)}>Open modal</FELButton>
          </div>
          <Modal open={modalOpen} onClose={() => setModalOpen(false)} title="Match complete">
            <p className={styles.cardBody}>
              Dim + 8px blur backdrop; panel scales/fades in over motion.normal (240ms). ESC or
              backdrop click closes with a mirrored exit.
            </p>
            <div className={styles.controls} style={{ marginTop: "var(--fel-space-4)" }}>
              <FELButton onClick={() => setModalOpen(false)}>Continue</FELButton>
              <FELButton variant="ghost" onClick={() => setModalOpen(false)}>
                Dismiss
              </FELButton>
            </div>
          </Modal>
        </Section>

        <Section title="Toast">
          <div className={styles.controls}>
            <FELButton size="sm" onClick={() => pushToast("info", "Recording synced to Nexus")}>
              Info
            </FELButton>
            <FELButton size="sm" onClick={() => pushToast("success", "Personal best saved")}>
              Success
            </FELButton>
            <FELButton size="sm" onClick={() => pushToast("warning", "Low bandwidth — quality reduced")}>
              Warning
            </FELButton>
            <FELButton size="sm" variant="danger" onClick={() => pushToast("danger", "Connection lost")}>
              Danger
            </FELButton>
          </div>
          <p className={styles.caption}>Slide-up + fade in, auto-dismiss after 4s (or via the × button).</p>
        </Section>

        <Section title="SkeletonShimmer">
          <div className={`${styles.row} ${styles.rowStart}`}>
            <SkeletonShimmer width={64} height={64} radius="var(--fel-radius-round)" />
            <div style={{ flex: 1, minWidth: 220 }}>
              <SkeletonShimmer lines={3} height={14} />
            </div>
            <SkeletonShimmer width={220} height={120} radius="var(--fel-radius-md)" />
          </div>
        </Section>

        <ToastStack toasts={toasts} onDismiss={dismissToast} />
      </div>
    </div>
  );
}
