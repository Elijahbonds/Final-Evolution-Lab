import { useEffect, useRef } from "react";
import { GOLD_MASTER_DMG_URL } from "../constants/downloads";
import { useLabAudio } from "../hooks/useLabAudio";

export type ThankYouProps = {
  /** True after PayPal capture COMPLETED + `paypal-verify` OK. */
  downloadUnlocked: boolean;
};

/**
 * Post-purchase surface — Gold Master DMG download (Supabase Storage public URL).
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
        <h2 className="mt-3 text-2xl font-black text-white sm:text-3xl">Sovereign Alpha — welcome</h2>
        <p className="mt-4 text-sm leading-relaxed text-white/55">
          After PayPal returns <strong className="text-white/75">COMPLETED</strong> and{" "}
          <code className="text-fel-cyan/80">paypal-verify</code> succeeds, shards credit and this download unlocks.
        </p>

        <div className="mt-10 flex flex-col items-center gap-4">
          {downloadUnlocked ? (
            <a
              href={GOLD_MASTER_DMG_URL}
              download
              className="animate-pulse inline-flex min-h-[64px] min-w-[280px] items-center justify-center rounded-sm bg-[#5ce1e6] px-8 text-lg font-black uppercase tracking-[0.15em] text-black shadow-[0_0_40px_rgba(92,225,230,0.8)] transition hover:bg-white hover:shadow-[0_0_48px_rgba(92,225,230,0.95)]"
            >
              DOWNLOAD GOLD MASTER
            </a>
          ) : (
            <button
              type="button"
              disabled
              className="inline-flex min-h-[56px] min-w-[260px] cursor-not-allowed items-center justify-center rounded-full border-2 border-white/20 bg-white/5 px-10 text-base font-bold uppercase tracking-wide text-white/35"
            >
              Download Gold Master
            </button>
          )}
          <p className="max-w-md text-xs text-white/40">
            {downloadUnlocked
              ? "Direct link — Supabase public storage (macOS .dmg)."
              : "Completes a PayPal purchase above to unlock this download."}
          </p>
        </div>
      </div>
    </section>
  );
}
