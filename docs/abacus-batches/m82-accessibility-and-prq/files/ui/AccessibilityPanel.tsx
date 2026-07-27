// AccessibilityPanel — the settings screen, because settings with no UI are
// inert.
//
// Deliberately reachable from the PAUSE menu, not buried in a profile page.
// Someone discovers they need the assist slider in the middle of the mode that
// is beating them, not while browsing account settings. Every control here
// applies live — `a11y.set()` notifies subscribers and modes re-read on the
// next frame, so nothing needs restarting.
//
// One thing this panel does NOT do: gate anything behind an account. A guest
// who needs captions needs them on their first dunk.

import { useEffect, useState } from 'react';
import {
  a11y, assistWindowScale, type A11ySettings, type AssistLevel, type ColorMode,
} from '../core/a11y';
import { captions } from '../core/captions';
import { signalFor } from '../core/palette';

const ASSIST_LABEL: Record<AssistLevel, string> = {
  off: 'Off',
  light: 'Light — 20% wider timing',
  standard: 'Standard — 40% wider',
  full: 'Full — 60% wider',
};

const COLOR_LABEL: Record<ColorMode, string> = {
  default: 'Default',
  deuteranopia: 'Deuteranopia (red-green)',
  protanopia: 'Protanopia (red-green)',
  tritanopia: 'Tritanopia (blue-yellow)',
  'high-contrast': 'High contrast',
};

function Row({ label, hint, children }: {
  label: string; hint?: string; children: React.ReactNode;
}) {
  return (
    <label className="fel-a11y-row">
      <span className="fel-a11y-label">
        {label}
        {hint ? <small className="fel-a11y-hint">{hint}</small> : null}
      </span>
      {children}
    </label>
  );
}

export default function AccessibilityPanel({ onClose }: { onClose?: () => void }) {
  const [s, setS] = useState<A11ySettings>(() => a11y.load());

  useEffect(() => a11y.subscribe(setS), []);
  // Captions are a separate bus so gameplay code never imports the settings
  // store; keeping them in step is this one line.
  useEffect(() => { captions.setEnabled(s.captions); }, [s.captions]);

  const set = (patch: Partial<A11ySettings>) => a11y.set(patch);

  return (
    <div className="fel-a11y" role="dialog" aria-label="Accessibility settings">
      <header>
        <h2>Accessibility</h2>
        {onClose ? <button onClick={onClose} aria-label="Close">✕</button> : null}
      </header>

      <section aria-label="Difficulty assistance">
        <Row label="Timing assist"
             hint="Widens every timing window. Stacks with the game's own catch-up help.">
          <select value={s.assist} onChange={(e) => set({ assist: e.target.value as AssistLevel })}>
            {(Object.keys(ASSIST_LABEL) as AssistLevel[]).map((k) => (
              <option key={k} value={k}>{ASSIST_LABEL[k]}</option>
            ))}
          </select>
        </Row>
        {/* Show the actual number. "Light" means nothing on its own, and a
            player deciding how much help to take deserves the real figure. */}
        <p className="fel-a11y-readout">
          A 100 ms window becomes <strong>{Math.round(100 * assistWindowScale(s.assist))} ms</strong>.
        </p>
      </section>

      <section aria-label="Motion and flashing">
        <Row label="Reduce motion" hint="Removes camera shake and screen movement.">
          <input type="checkbox" checked={s.reducedMotion}
                 onChange={(e) => set({ reducedMotion: e.target.checked })} />
        </Row>
        <Row label="No flashing" hint="Blocks rapid flashes. Recommended for photosensitivity.">
          <input type="checkbox" checked={s.noFlashing}
                 onChange={(e) => set({ noFlashing: e.target.checked })} />
        </Row>
      </section>

      <section aria-label="Sound">
        <Row label="Captions" hint="Shows a caption for every sound you need to react to.">
          <input type="checkbox" checked={s.captions}
                 onChange={(e) => set({ captions: e.target.checked })} />
        </Row>
      </section>

      <section aria-label="Colour">
        <Row label="Colour mode">
          <select value={s.colorMode} onChange={(e) => set({ colorMode: e.target.value as ColorMode })}>
            {(Object.keys(COLOR_LABEL) as ColorMode[]).map((k) => (
              <option key={k} value={k}>{COLOR_LABEL[k]}</option>
            ))}
          </select>
        </Row>
        {/* A live preview, so the choice is made by looking rather than by
            reading a clinical term most people have to guess at. */}
        <div className="fel-a11y-preview" aria-label="Preview">
          {(['success', 'failure', 'warning', 'perfect'] as const).map((sig) => {
            const st = signalFor(sig, s.colorMode);
            return (
              <span key={sig} style={{ color: st.color }} className={`fel-sig fel-sig--${st.shape}`}>
                {st.glyph} {st.label || sig}
              </span>
            );
          })}
        </div>
      </section>

      <section aria-label="Controls">
        <Row label="Hold becomes toggle"
             hint="Press once to start charging, again to release. No holding.">
          <input type="checkbox" checked={s.holdToToggle}
                 onChange={(e) => set({ holdToToggle: e.target.checked })} />
        </Row>
        <Row label="One-handed layout" hint="Puts every control within one thumb's reach.">
          <input type="checkbox" checked={s.oneHanded}
                 onChange={(e) => set({ oneHanded: e.target.checked })} />
        </Row>
        <Row label="Mirror controls" hint="Swaps the stick and buttons left-to-right.">
          <input type="checkbox" checked={s.mirrorControls}
                 onChange={(e) => set({ mirrorControls: e.target.checked })} />
        </Row>
      </section>

      <section aria-label="Text">
        <Row label={`HUD text size — ${Math.round(s.textScale * 100)}%`}>
          <input type="range" min={1} max={2} step={0.1} value={s.textScale}
                 onChange={(e) => set({ textScale: Number(e.target.value) })} />
        </Row>
      </section>
    </div>
  );
}
