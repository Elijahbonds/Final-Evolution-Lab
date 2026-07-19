// clipResolver — every requested clip resolves to something playable, loudly.

import { CLIP_ALIASES, FALLBACK_CLIP } from './clipAliases';

export interface ResolvedClip { clip: string; speedRatio: number; exact: boolean }

const missing = new Set<string>();

export function resolveClip(name: string, available: Set<string>): ResolvedClip {
  if (available.has(name)) return { clip: name, speedRatio: 1, exact: true };

  const alias = CLIP_ALIASES[name];
  if (alias && available.has(alias[0])) {
    return { clip: alias[0], speedRatio: alias[1], exact: false };
  }

  if (!missing.has(name)) {
    missing.add(name);
    // Loud by design — the silent-null path is how the T-pose shipped 3 times.
    console.error(
      `[FEL-ANIM] MISSING CLIP "${name}" — no exact/alias match in ` +
      `[${[...available].join(', ')}]. Fallback "${FALLBACK_CLIP[0]}". ` +
      `Missing so far: ${[...missing].join(', ')}`,
    );
  }
  const fb = available.has(FALLBACK_CLIP[0])
    ? FALLBACK_CLIP
    : ([[...available][0] ?? '', 1] as [string, number]);
  return { clip: fb[0], speedRatio: fb[1], exact: false };
}

export const missingClipList = (): string[] => [...missing];
export const missingClipCount = (): number => missing.size;
