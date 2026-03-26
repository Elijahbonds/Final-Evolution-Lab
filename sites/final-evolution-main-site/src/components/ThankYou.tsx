import { useEffect, useRef } from "react";
import {
  GOLD_MASTER_DOWNLOAD_PATH,
  GOLD_MASTER_DMG_FILENAME,
  GOLD_MASTER_DMG_URL,
} from "../constants/downloads";
import { useLabAudio } from "../hooks/useLabAudio";

export type ThankYouProps = {
  /** True after payment completes successfully (verified). */
  downloadUnlocked: boolean;
};

const DMG_HREF = import.meta.env.DEV ? GOLD_MASTER_DMG_URL : GOLD_MASTER_DOWNLOAD_PATH;

/**
 * Post-purchase — download via clean on-domain path (Netlify → Supabase Storage).
 */
export function ThankYou({ downloadUnlocked }: ThankYouProps) {
  const { playShardChime, playUnlock, warmUp } = useLabAudio();
  const prevUnlockedRef = useRef<boolean | null>(null);

  useEffect(() => {
    void warmUp();
  }, [warmUp]);

  useEffect(() => {
    if (prevUnlockedRef.current === null) {
      prevUnlockedRef.current = downloadUnlocked;
      return;
    }
    if (downloadUnlocked && !prevUnlockedRef.current) {
      playShardChime();
      const t = window.setTimeout(() => playUnlock(), 140);
      prevUnlockedRef.current = downloadUnlocked;
      return () => clearTimeout(t);
    }
    prevUnlockedRef.current = downloadUnlocked;
  }, [downloadUnlocked, playShardChime, playUnlock]);

  return (
    <section
      id="thank-you"
      className="relative z-40 border-t border-fel-cyan/20 bg-gradient-to-b from-black to-[#0a0c10] px-6 py-16 sm:px-12"
    >
      <div className="mx-auto max-w-2xl text-center">
        <p className="text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Thank you</p>
        <h2 className="mt-3 text-2xl font-black text-white sm:text-3xl">Welcome to the lab</h2>
        <p className="mt-4 text-sm leading-relaxed text-white/55">
          Your payment went through. Install the Sovereign Lab build on your Mac using the link below.
        </p>

        <div className="mt-10 flex flex-col items-center gap-4">
          {downloadUnlocked ? (
            <a
              href={DMG_HREF}
              download={GOLD_MASTER_DMG_FILENAME}
              rel="noopener noreferrer"
              title={`${GOLD_MASTER_DMG_FILENAME} — macOS 14+ (Sonoma). Universal binary (M-series optimized; Intel compatible).`}
              className="inline-flex min-h-[68px] min-w-[min(100%,320px)] max-w-full flex-col items-center justify-center gap-1 rounded-lg bg-[#5ce1e6] px-10 py-3 text-center font-black uppercase tracking-[0.08em] text-black shadow-[0_4px_24px_rgba(92,225,230,0.45)] ring-1 ring-white/20 transition hover:bg-[#7eedf2] hover:shadow-[0_8px_40px_rgba(92,225,230,0.55)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-fel-cyan sm:min-h-[76px]"
            >
              <span className="text-base sm:text-lg">Download Gold Master</span>
              <span className="text-[0.65rem] font-semibold normal-case tracking-normal text-black/70">
                Mac installer · {GOLD_MASTER_DMG_FILENAME}
              </span>
            </a>
          ) : (
            <button
              type="button"
              disabled
              className="inline-flex min-h-[56px] min-w-[260px] cursor-not-allowed flex-col items-center justify-center gap-0.5 rounded-lg border border-white/15 bg-white/[0.04] px-10 py-2 text-center font-bold uppercase tracking-wide text-white/30"
            >
              <span>Download Gold Master</span>
              <span className="text-[0.6rem] font-normal normal-case tracking-normal text-white/20">
                Unlocks after Sovereign checkout
              </span>
            </button>
          )}
          <p className="max-w-md text-xs text-white/40">
            {downloadUnlocked
              ? `Evolution Shards credited · secure delivery · ${GOLD_MASTER_DMG_FILENAME}`
              : "Complete Sovereign checkout above — shards credit instantly, then Gold Master unlocks here."}
          </p>
        </div>

        <div
          className="mx-auto mt-10 max-w-md rounded-xl border border-white/10 bg-white/[0.03] px-5 py-4 text-left text-xs text-white/60"
          role="region"
          aria-label="System requirements"
        >
          <p className="text-[0.6rem] font-bold uppercase tracking-[0.28em] text-fel-cyan">System requirements</p>
          <ul className="mt-3 list-disc space-y-1.5 pl-5">
            <li>macOS 14+ (Sonoma or later)</li>
            <li>Universal binary — M-series optimized; runs on Intel Macs</li>
            <li>Administrator privileges to mount the .dmg and copy the app</li>
          </ul>
        </div>
      </div>
    </section>
  );
}
