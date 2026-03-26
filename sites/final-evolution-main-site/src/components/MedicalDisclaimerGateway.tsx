import { useEffect } from "react";

export type MedicalDisclaimerMode = "landing" | "lab";

type MedicalDisclaimerGatewayProps = {
  open: boolean;
  /** Landing = first-run site gate; Lab = before opening PWA. */
  mode: MedicalDisclaimerMode;
  /** Production PWA shell — used when `mode="lab"`. */
  labUrl: string;
  onClose: () => void;
};

/**
 * Clinical gate — z-index 1100, above hero, HUD, and pricing chrome.
 * Mandatory first-run: use `mode="landing"` until acknowledged.
 */
export function MedicalDisclaimerGateway({
  open,
  mode,
  labUrl,
  onClose,
}: MedicalDisclaimerGatewayProps) {
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, [open]);

  if (!open) return null;

  const isLanding = mode === "landing";

  return (
    <div
      className="fixed inset-0 z-[1100] flex items-center justify-center p-4 sm:p-8"
      role="dialog"
      aria-modal="true"
      aria-labelledby="medical-disclaimer-title"
    >
      {/* First-run landing gate: backdrop does not dismiss — must acknowledge. */}
      <button
        type="button"
        className={`absolute inset-0 bg-black/85 backdrop-blur-sm ${isLanding ? "pointer-events-none" : ""}`}
        aria-label={isLanding ? undefined : "Close"}
        onClick={isLanding ? undefined : onClose}
        tabIndex={isLanding ? -1 : 0}
      />
      <div className="relative z-[1101] max-h-[min(92vh,720px)] w-full max-w-lg overflow-y-auto rounded-2xl border-2 border-fel-cyan/50 bg-[#050608] p-6 shadow-[0_0_48px_rgba(92,225,230,0.2)] sm:p-8">
        <p className="text-[0.6rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">Medical disclaimer</p>
        <h2 id="medical-disclaimer-title" className="mt-3 text-xl font-black text-white sm:text-2xl">
          Clinical movement education — not medical care
        </h2>
        <div className="mt-5 space-y-3 text-sm leading-relaxed text-white/75">
          <p>
            Final Evolution Lab provides movement education, biomechanics visualization, and training
            experiences. It is <strong className="text-white/90">not</strong> a medical device and does
            not diagnose, treat, cure, or prevent any disease or injury.
          </p>
          <p>
            Consult a qualified physician before beginning any exercise program. Stop if you feel pain,
            dizziness, or shortness of breath. By continuing, you accept responsibility for your use of
            the Lab.
          </p>
        </div>
        <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:justify-end">
          {!isLanding ? (
            <button
              type="button"
              className="rounded-full border border-white/25 px-6 py-3 text-sm font-semibold text-white/80 transition hover:bg-white/10"
              onClick={onClose}
            >
              Cancel
            </button>
          ) : null}
          {isLanding ? (
            <button
              type="button"
              className="inline-flex min-h-[48px] w-full items-center justify-center rounded-full bg-fel-cyan px-8 text-sm font-black uppercase tracking-wide text-black shadow-[0_0_24px_rgba(92,225,230,0.4)] transition hover:bg-fel-cyan/90 sm:w-auto"
              onClick={onClose}
            >
              I understand — continue
            </button>
          ) : (
            <a
              href={labUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex min-h-[48px] items-center justify-center rounded-full bg-fel-cyan px-8 text-sm font-black uppercase tracking-wide text-black shadow-[0_0_24px_rgba(92,225,230,0.4)] transition hover:bg-fel-cyan/90"
              onClick={() => onClose()}
            >
              Enter Lab — I understand
            </a>
          )}
        </div>
      </div>
    </div>
  );
}
