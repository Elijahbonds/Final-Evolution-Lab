// WaveModel — the wave IS the level, and it is never the same twice.
//
// WHAT SURF HAS TODAY
// `rideWorlds.buildSurfBreak()` returns `waveLipAt(tSec)` — a lip that travels
// shoreward on a loop. One wave. The same wave. Forever.
//
// That makes Surf Break a fixed obstacle course with a moving wall. Once you
// have learned the loop there is nothing left, which is the opposite of what
// the sport is: every wave is different, and reading the one in front of you
// is the entire skill.
//
// WHAT A WAVE ACTUALLY IS
// A wave is not a shape, it is a SEQUENCE OF SECTIONS that break in order as
// it moves along the reef:
//
//   SHOULDER   the unbroken face ahead of the curl. Safe, slow, low-scoring.
//   POCKET     just ahead of the breaking part. Where the power is.
//   BARREL     the lip throws over the face and you ride inside it. The
//              highest-scoring thing in surfing and the shortest-lived.
//   SECTION    a part that stands up and breaks ahead of you — get through it
//              or you are caught behind.
//   CLOSEOUT   the whole thing breaks at once. Nothing to ride.
//
// A ride is a sequence of decisions about whether to make the next section,
// and whether the barrel is worth being caught behind. THAT is the mode.
//
// DETERMINISTIC BY SEED
// Every wave here is generated from a seed, so a set is infinitely varied but
// perfectly reproducible. That is what makes a surf GHOST possible at all
// (M83): two players can be given the same wave, and a recorded ride replays
// on the wave it was actually ridden on. Procedural and replayable are usually
// in tension; seeding is what resolves it.

import { Rng } from './Rng';

export type SectionKind = 'shoulder' | 'pocket' | 'barrel' | 'section' | 'closeout';

export interface WaveSection {
  kind: SectionKind;
  /** Metres along the wave from the peak. */
  startM: number;
  lengthM: number;
  /** 0..1 — how hollow. Drives whether it can barrel and how hard it hits. */
  power: number;
  /** Seconds after the wave starts before this section breaks. */
  breaksAtSec: number;
}

export interface Wave {
  seed: number;
  /** Total rideable length, metres. */
  lengthM: number;
  /** How fast the break travels along the reef, m/s. This is the clock. */
  breakSpeed: number;
  /** Face height, metres. Drives scoring and difficulty. */
  faceM: number;
  sections: WaveSection[];
  /** Human label for the pre-ride card. */
  label: string;
}

/** Multiplier per section kind. A barrel is worth the risk; a shoulder is not. */
export const SECTION_SCORE: Record<SectionKind, number> = {
  shoulder: 1.0, pocket: 2.2, barrel: 5.0, section: 1.6, closeout: 0,
};

/**
 * Generate a wave.
 *
 * `quality` 0..1 shifts the whole distribution — a poor day gives short,
 * gutless, close-out-heavy waves and a good day gives long barrelling ones.
 * Same seed, same wave, always.
 *
 * The generator has one rule that matters: A WAVE MUST BE RIDEABLE. It always
 * opens with something makeable and never starts on a closeout. Procedural
 * generation that can produce an unplayable level is a generator that has not
 * finished being written.
 */
export function generateWave(seed: number, quality = 0.5): Wave {
  const rng = new Rng(seed);
  const faceM = 1.2 + rng.range(0, 2.2) + quality * 2.4;
  const lengthM = 45 + rng.range(0, 70) + quality * 60;
  const breakSpeed = 5.5 + rng.range(0, 3) + faceM * 0.5;

  const sections: WaveSection[] = [];
  let at = 0;
  // Always open with a makeable section — never a closeout on the first metre.
  const opener: SectionKind = rng.chance(0.35 + quality * 0.3) ? 'pocket' : 'shoulder';
  const openLen = 10 + rng.range(0, 14);
  sections.push({ kind: opener, startM: 0, lengthM: openLen, power: 0.3 + quality * 0.3, breaksAtSec: 0 });
  at += openLen;

  while (at < lengthM - 12) {
    const roll = rng.next();
    // Barrels need a hollow, powerful wave. On a poor day they simply do not
    // appear, which is what makes a good day feel like a good day.
    // BOTH gates are conditioned on quality. An earlier version added a flat
    // size bonus, so a big gutless wave on a poor day still barrelled — which
    // made "a poor day has no barrels" quietly false and removed the reason a
    // good day feels different.
    const qualityBase = Math.max(0, (quality - 0.35) * 0.55);
    const barrelChance = qualityBase > 0 ? qualityBase + (faceM > 2.5 ? 0.12 : 0) : 0;
    let kind: SectionKind;
    if (roll < barrelChance) kind = 'barrel';
    else if (roll < barrelChance + 0.3) kind = 'pocket';
    else if (roll < barrelChance + 0.55) kind = 'section';
    else kind = 'shoulder';

    const len = kind === 'barrel' ? 6 + rng.range(0, 10)
      : kind === 'section' ? 8 + rng.range(0, 12)
      : 12 + rng.range(0, 20);

    sections.push({
      kind,
      startM: at,
      lengthM: len,
      power: kind === 'barrel' ? 0.7 + rng.range(0, 0.3)
        : kind === 'pocket' ? 0.5 + rng.range(0, 0.3)
        : 0.2 + rng.range(0, 0.3),
      breaksAtSec: at / breakSpeed,
    });
    at += len;
  }

  // Waves end. A closeout is how, and it is the natural time limit on a ride.
  sections.push({
    kind: 'closeout', startM: at, lengthM: Math.max(6, lengthM - at),
    power: 0.4 + quality * 0.4, breaksAtSec: at / breakSpeed,
  });

  return { seed, lengthM, breakSpeed, faceM, sections, label: describeWave(faceM, sections) };
}

/** The pre-ride card. Surfers read a wave before they take it; so should a player. */
export function describeWave(faceM: number, sections: WaveSection[]): string {
  const barrels = sections.filter((s) => s.kind === 'barrel').length;
  const size = faceM < 1.8 ? 'Waist-high' : faceM < 2.8 ? 'Chest-high' : faceM < 4 ? 'Overhead' : 'Double overhead';
  if (barrels > 1) return `${size}, ${barrels} barrel sections`;
  if (barrels === 1) return `${size}, one barrel`;
  const fast = sections.filter((s) => s.kind === 'section').length;
  return fast > 2 ? `${size}, fast and sectiony` : `${size}, open face`;
}

/** Which section is at this distance along the wave. */
export function sectionAt(wave: Wave, distanceM: number): WaveSection | null {
  return wave.sections.find((s) => distanceM >= s.startM && distanceM < s.startM + s.lengthM) ?? null;
}

/** How far along the wave the break has travelled at time t. */
export function breakPositionM(wave: Wave, tSec: number): number {
  return wave.breakSpeed * tSec;
}

export type RiderZone = 'ahead' | 'pocket' | 'barrel' | 'behind' | 'wiped';

/**
 * Where the rider sits relative to the break — the read that decides everything.
 *
 *   'ahead'   out on the shoulder. Safe, and scoring almost nothing.
 *   'pocket'  just ahead of the break. Where the wave pays.
 *   'barrel'  inside it. Rare, brief, worth five times a shoulder.
 *   'behind'  the break has passed you. You are done unless you can outrun it.
 *   'wiped'   caught.
 *
 * The pocket window is DELIBERATELY NARROW — about three metres. Riding the
 * pocket has to be an active thing you hold, not a place you end up.
 */
export function riderZone(wave: Wave, riderM: number, tSec: number): RiderZone {
  const brk = breakPositionM(wave, tSec);
  const lead = riderM - brk;
  const sect = sectionAt(wave, riderM);

  if (lead < -2.5) return 'wiped';
  if (lead < 0) return 'behind';
  if (sect?.kind === 'barrel' && lead < 2.5) return 'barrel';
  if (lead <= 3) return 'pocket';
  return 'ahead';
}

/** Score for one second spent in a zone on this wave. */
export function zoneScorePerSec(wave: Wave, zone: RiderZone, riderM: number): number {
  if (zone === 'wiped' || zone === 'behind') return 0;
  const sect = sectionAt(wave, riderM);
  const base = zone === 'barrel' ? SECTION_SCORE.barrel
    : zone === 'pocket' ? SECTION_SCORE.pocket
    : SECTION_SCORE.shoulder;
  // Face height pays: a bigger wave is worth more for the same ride.
  return base * (0.6 + wave.faceM * 0.22) * (0.7 + (sect?.power ?? 0.3) * 0.6);
}

/**
 * Can the rider make it through the section ahead?
 *
 * The core decision of a ride. A section breaking ahead of you must be beaten
 * to it — pump for speed and go, or pull off and lose the wave. Getting this
 * wrong is how surf rides end, and being able to SEE it coming is what makes
 * the decision fair.
 */
export function canMakeSection(
  wave: Wave, riderM: number, riderSpeed: number, tSec: number,
): { makeable: boolean; section: WaveSection | null; marginSec: number } {
  const next = wave.sections.find((s) => s.startM > riderM && (s.kind === 'section' || s.kind === 'closeout'));
  if (!next) return { makeable: true, section: null, marginSec: Infinity };

  const distance = next.startM - riderM;
  const riderArrives = riderSpeed > 0.1 ? distance / riderSpeed : Infinity;
  const sectionBreaks = next.breaksAtSec - tSec;
  return {
    makeable: riderArrives < sectionBreaks,
    section: next,
    marginSec: sectionBreaks - riderArrives,
  };
}

/**
 * Generate a SET — several waves, arriving in sequence.
 *
 * Sets are how surfing actually works: waves come in groups with lulls
 * between, and they are not all equal. Picking which wave of the set to take
 * is a real decision, and one that a single looping wave cannot offer at all.
 */
export function generateSet(seed: number, count = 5, conditions = 0.5): Wave[] {
  const rng = new Rng(seed);
  return Array.from({ length: count }, (_, i) => {
    // Wave quality varies within a set, and the best one is rarely the first —
    // so there is a reason to let one go.
    const positionBonus = i === Math.floor(count / 2) ? 0.2 : 0;
    const q = Math.min(1, Math.max(0, conditions + rng.range(-0.25, 0.25) + positionBonus));
    return generateWave(rng.int(1, 0x7fffffff), q);
  });
}

/** The best wave in a set, by potential score. For a "you let that one go" note. */
export function bestOfSet(set: Wave[]): { index: number; wave: Wave } {
  let best = 0;
  let bestScore = -1;
  set.forEach((w, i) => {
    const score = w.sections.reduce((s, sec) => s + SECTION_SCORE[sec.kind] * sec.lengthM, 0) * (0.6 + w.faceM * 0.2);
    if (score > bestScore) { bestScore = score; best = i; }
  });
  return { index: best, wave: set[best] };
}

/** One coaching line after a ride. */
export function surfCoaching(stats: {
  shoulderSec: number; pocketSec: number; barrelSec: number; wipeouts: number;
}): string | null {
  const total = stats.shoulderSec + stats.pocketSec + stats.barrelSec;
  if (total < 4) return null;
  if (stats.shoulderSec / total > 0.65) {
    return 'You are riding out on the shoulder where the wave has no power. Stay closer to the break.';
  }
  if (stats.wipeouts > 2) {
    return 'You are getting caught behind sections. Pump for speed BEFORE the section stands up, not after.';
  }
  if (stats.barrelSec > 1) {
    return 'You found the barrel. Nothing in the mode scores higher.';
  }
  return null;
}
