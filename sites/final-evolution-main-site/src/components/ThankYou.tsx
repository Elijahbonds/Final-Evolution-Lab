import { useEffect, useRef } from "react";
import { GOLD_MASTER_DOWNLOAD_PATH, GOLD_MASTER_DMG_URL } from "../constants/downloads";
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
          Your payment went through. Your Mac installer is ready below.
        </p>

        <div className="mt-10 flex flex-col items-center gap-4">
          {downloadUnlocked ? (
            <a
              href={DMG_HREF}
              download="FinalEvolution.dmg"
              rel="noopener noreferrer"
              title="Requires macOS 14 or later. Apple Silicon (M-series) recommended for best performance."
              className="animate-pulse inline-flex min-h-[64px] min-w-[280px] items-center justify-center rounded-sm bg-[#5ce1e6] px-8 text-lg font-black uppercase tracking-[0.15em] text-black shadow-[0_0_40px_rgba(92,225,230,0.8)] transition hover:bg-white hover:shadow-[0_0_48px_rgba(92,225,230,0.95)]"
            >
              Download for Mac
            </a>
          ) : (
            <button
              type="button"
              disabled
              className="inline-flex min-h-[56px] min-w-[260px] cursor-not-allowed items-center justify-center rounded-full border-2 border-white/20 bg-white/5 px-10 text-base font-bold uppercase tracking-wide text-white/35"
            >
              Download for Mac
            </button>
          )}
          <p className="max-w-md text-xs text-white/40">
            {downloadUnlocked
              ? "Installer · macOS 14+ · Apple Silicon recommended."
              : "Complete checkout above to unlock your download."}
          </p>
        </div>
      </div>
    </section>
  );
}
