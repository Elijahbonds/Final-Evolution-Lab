// PrqMeter — PRQ, on screen, while you play.
//
// The whole argument of this product is that your athletic readiness is a
// mechanic rather than a statistic. Right now PRQ appears on a results screen
// after the fact, which makes it a statistic. This is the difference.
//
// THREE THINGS IT SHOWS, AND WHY EACH ONE EARNS ITS PIXELS
//   1. The number and its tier — who you are today.
//   2. WHAT THAT DID TO THE OPPONENT. "ELITE · opponent reacts 0.22s faster"
//      is the line that makes PRQ legible. Without it the meter is decoration,
//      and a player has no way to learn that showing up rested changed the
//      match they just played.
//   3. What the session is earning, live, via estimatePrqDelta.
//
// Never blocks. If PRQ has not loaded, it renders the neutral state rather
// than a spinner — a guest still gets a game and still gets a meter.

import { useEffect, useState } from 'react';
import { PRQDrivenDDA, aiResponseDelay, type DifficultyTier } from '../core/DDA';
import { estimatePrqDelta, scoresPrq } from '../core/prqWeights';
import { a11y } from '../core/a11y';
import { signalFor } from '../core/palette';

const TIER_ORDER: DifficultyTier[] = ['ROOKIE', 'DEVELOPING', 'COMPETITIVE', 'ELITE', 'LEGENDARY'];

export interface PrqMeterProps {
  dda: PRQDrivenDDA;
  modeId: string;
  score: number;
  aiScore: number;
  durationSec: number;
  /** Hide the live earning line before the match starts. */
  live?: boolean;
}

/**
 * One sentence naming what this player's PRQ is doing to this match.
 *
 * Compared against a neutral player, not against zero — "the opponent reacts
 * faster than it would for someone average" is a claim a player can check
 * against their own experience. "0.55s reaction" is a number they cannot.
 */
function consequence(dda: PRQDrivenDDA): string {
  const neutral = new PRQDrivenDDA({ playerPRQ: 75, modeId: dda.modeId });
  const dt = neutral.aiReactionSpeed(0, 0) - dda.aiReactionSpeed(0, 0);
  if (Math.abs(dt) < 0.02) return 'opponent tuned to your level';
  return dt > 0
    ? `opponent reacts ${dt.toFixed(2)}s faster`
    : `opponent reacts ${Math.abs(dt).toFixed(2)}s slower`;
}

export default function PrqMeter({
  dda, modeId, score, aiScore, durationSec, live = true,
}: PrqMeterProps) {
  const [textScale, setTextScale] = useState(() => a11y.get().textScale);
  useEffect(() => a11y.subscribe((s) => setTextScale(s.textScale)), []);

  // A shop is not a match. Rendering an earning line for market_browse would
  // be a promise the economy does not keep.
  const earns = scoresPrq(modeId);
  const delta = earns ? estimatePrqDelta(modeId, score, durationSec, false) : 0;
  const tierIndex = TIER_ORDER.indexOf(dda.tier);
  const fill = Math.min(100, Math.max(0, dda.playerPRQ));
  const style = signalFor(delta > 0 ? 'success' : 'neutral', a11y.get().colorMode);

  return (
    <div className="fel-prq" style={{ fontSize: `${textScale}rem` }}
         role="status" aria-live="off"
         aria-label={`PRQ ${Math.round(dda.playerPRQ)}, ${dda.tier}`}>
      <div className="fel-prq__head">
        <span className="fel-prq__value">{Math.round(dda.playerPRQ)}</span>
        <span className="fel-prq__tier">{dda.tier}</span>
      </div>

      <div className="fel-prq__track" aria-hidden="true">
        <div className="fel-prq__fill" style={{ width: `${fill}%` }} />
        {/* Tier boundaries as ticks — a bar with no landmarks tells you
            nothing about how close the next tier is. */}
        {[35, 55, 75, 90].map((t) => (
          <span key={t} className="fel-prq__tick" style={{ left: `${t}%` }} />
        ))}
      </div>

      {/* The line that turns a stat into a mechanic. */}
      <div className="fel-prq__consequence">{consequence(dda)}</div>

      {live && earns && delta > 0 ? (
        <div className="fel-prq__delta" style={{ color: style.color }}>
          {style.glyph} +{delta.toFixed(2)} this session
        </div>
      ) : null}

      {tierIndex >= 0 && tierIndex < TIER_ORDER.length - 1 ? (
        <div className="fel-prq__next">next: {TIER_ORDER[tierIndex + 1]}</div>
      ) : null}
    </div>
  );
}

/**
 * The pre-match card.
 *
 * Shown on the READY gate, before the countdown. This is the moment PRQ should
 * land — the player learns what today's readiness means for the match they are
 * about to start, rather than reading about it afterwards.
 */
export function PrqBriefing({ dda }: { dda: PRQDrivenDDA }) {
  const neutralDelay = aiResponseDelay(0, 0);
  return (
    <div className="fel-prq-brief" role="note">
      <h3>Today you are <strong>{dda.tier}</strong></h3>
      <ul>
        <li>{consequence(dda)}</li>
        <li>opponent blocks {Math.round(dda.aiBlockChance(0, 0) * 100)}% of the time</li>
        <li>your timing windows are {Math.round(dda.qteWindowScale(0, 0, 10) * 100)}% of standard</li>
      </ul>
      <small>
        Baseline reaction {neutralDelay.toFixed(2)}s. Readiness is measured from your
        health data — rest changes this.
      </small>
    </div>
  );
}
