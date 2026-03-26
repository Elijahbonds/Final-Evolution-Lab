import { useEffect } from "react";

type MedicalDisclaimerGatewayProps = {
  open: boolean;
  onClose: () => void;
};

/**
 * Clinical gate — first visit only. Above hero, HUD, and pricing chrome.
 */
export function MedicalDisclaimerGateway({ open, onClose }: MedicalDisclaimerGatewayProps) {
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[1100] flex items-center justify-center p-4 sm:p-8"
      role="dialog"
      aria-modal="true"
      aria-labelledby="medical-disclaimer-title"
    >
      <div className="pointer-events-none absolute inset-0 bg-black/85 backdrop-blur-sm" aria-hidden />
      <div className="relative z-[1101] max-h-[min(92vh,720px)] w-full max-w-lg overflow-y-auto rounded-2xl border-2 border-fel-cyan/50 bg-[#050608] p-6 shadow-[0_0_48px_rgba(92,225,230,0.2)] sm:p-8">
        <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Medical disclaimer</p>
        <h2 id="medical-disclaimer-title" className="mt-3 text-xl font-black text-white sm:text-2xl">
          Movement education — not medical care
        </h2>
        <div className="mt-5 space-y-3 text-sm leading-relaxed text-white/75">
          <p>
            Final Evolution Lab offers movement education and training visualization. It is{" "}
            <strong className="text-white/90">not</strong> a medical device and does not diagnose, treat,
            cure, or prevent any disease or injury.
          </p>
          <p>
            Talk to a qualified clinician before starting a new exercise program. Stop if you feel pain,
            dizziness, or shortness of breath.
          </p>
        </div>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:justify-end">
          <button
            type="button"
            className="inline-flex min-h-[48px] w-full items-center justify-center rounded-full bg-fel-cyan px-8 text-sm font-black uppercase tracking-wide text-black shadow-[0_0_24px_rgba(92,225,230,0.4)] transition hover:bg-fel-cyan/90 sm:w-auto"
            onClick={onClose}
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  );
}
