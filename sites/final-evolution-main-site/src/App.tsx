import { lazy, Suspense, useCallback, useEffect, useState } from "react";
import type { SovereignAlphaTier } from "./constants/paypal";
import { PRODUCTION_FREWAY_URL } from "./constants/site";
import { AppView } from "./components/AppView";
import { HUDOverlay } from "./components/HUDOverlay";
import { MedicalDisclaimerGateway } from "./components/MedicalDisclaimerGateway";
import { PayPalMessagesStrip, SovereignPaymentPortal } from "./components/SovereignPaymentPortal";
import { ThankYou } from "./components/ThankYou";

const HeroSpiral = lazy(() =>
  import("./components/HeroSpiral").then((m) => ({ default: m.HeroSpiral }))
);

/** Lab PWA shell — same apex as marketing site (`/play` route or redirect). */
const LAB_PLAY_URL = `${PRODUCTION_FREWAY_URL}/play`;

function readMedicalAck(): boolean {
  try {
    return localStorage.getItem("fel_medical_ack") === "1";
  } catch {
    return false;
  }
}

export default function App() {
  const heroVideo = import.meta.env.VITE_HERO_VIDEO_URL || undefined;
  const [medicalAck, setMedicalAck] = useState(readMedicalAck);
  const [labDisclaimerOpen, setLabDisclaimerOpen] = useState(false);
  const [downloadUnlocked, setDownloadUnlocked] = useState(false);
  const [shardBalance, setShardBalance] = useState(0);

  useEffect(() => {
    try {
      if (sessionStorage.getItem("fel_dmg_unlock") === "1") {
        setDownloadUnlocked(true);
      }
    } catch {
      /* private mode */
    }
  }, []);

  const handleLandingAcknowledge = useCallback(() => {
    try {
      localStorage.setItem("fel_medical_ack", "1");
    } catch {
      /* */
    }
    setMedicalAck(true);
  }, []);

  const handlePurchaseVerified = useCallback(
    ({ shardDelta }: { tier: SovereignAlphaTier; shardDelta: number }) => {
      setShardBalance((s) => s + shardDelta);
      setDownloadUnlocked(true);
      try {
        sessionStorage.setItem("fel_dmg_unlock", "1");
      } catch {
        /* */
      }
      window.setTimeout(() => {
        document.getElementById("thank-you")?.scrollIntoView({ behavior: "smooth", block: "start" });
      }, 150);
    },
    []
  );

  const handleVerifyFailed = useCallback(() => {
    setDownloadUnlocked(false);
    try {
      sessionStorage.removeItem("fel_dmg_unlock");
    } catch {
      /* */
    }
  }, []);

  return (
    <div className="min-h-full bg-fel-black">
      <MedicalDisclaimerGateway
        open={!medicalAck}
        mode="landing"
        labUrl={LAB_PLAY_URL}
        onClose={handleLandingAcknowledge}
      />

      <MedicalDisclaimerGateway
        open={labDisclaimerOpen}
        mode="lab"
        labUrl={LAB_PLAY_URL}
        onClose={() => setLabDisclaimerOpen(false)}
      />

      <section className="relative">
        <Suspense
          fallback={
            <div className="h-[min(100dvh,900px)] w-full bg-fel-black" aria-hidden />
          }
        >
          <HeroSpiral videoUrl={heroVideo} />
        </Suspense>
        <HUDOverlay />

        <div className="pointer-events-none absolute inset-0 z-30 flex flex-col justify-end pb-16 pl-6 pr-6 sm:pb-20 sm:pl-12">
          <div className="pointer-events-auto max-w-3xl">
            <p className="text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
              Dark clinical · sovereign lab
            </p>
            <div className="mt-3 flex flex-wrap items-end gap-3">
              <h1 className="text-4xl font-black leading-[1.05] tracking-tight text-white sm:text-5xl md:text-6xl [text-shadow:0_0_40px_rgba(92,225,230,0.25)]">
                Biomechanical Truth
              </h1>
              <span
                className="inline-flex items-center rounded border border-fel-cyan/50 bg-black/50 px-2 py-1 text-[0.6rem] font-bold uppercase tracking-[0.2em] text-fel-cyan"
                title="Hero WebGL present mode and HUD cadence target 60 Hz"
              >
                60fps
              </span>
            </div>
            <h2 className="mt-2 text-xl font-semibold tracking-tight text-white/90 sm:text-2xl">
              Bypass the App Store.
              <br />
              <span className="text-fel-cyan">Enter the Lab.</span>
            </h2>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-white/65 sm:text-lg">
              Neon Spiral Line telemetry, 16.6 ms frame discipline, and a sovereign shard economy —
              clinical movement education, not medical diagnosis.
            </p>

            <div className="mt-10 flex flex-wrap items-center gap-4">
              <button
                type="button"
                onClick={() => setLabDisclaimerOpen(true)}
                className="inline-flex min-h-[52px] min-w-[200px] items-center justify-center rounded-full bg-fel-cyan px-10 text-base font-black uppercase tracking-wide text-black shadow-[0_0_32px_rgba(92,225,230,0.45)] transition hover:bg-fel-cyan/90 hover:shadow-[0_0_48px_rgba(92,225,230,0.55)]"
              >
                Open Lab
              </button>
            </div>
          </div>
        </div>
      </section>

      <AppView />

      <section
        id="sovereign-payments"
        className="relative z-40 border-t border-white/10 bg-fel-black px-6 py-16 sm:px-12"
      >
        <div className="mx-auto max-w-6xl">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h2 className="text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
                Alpha 1 — pricing
              </h2>
              <p className="mt-2 max-w-2xl text-sm text-white/55">
                PayPal Complete Payments. Download unlocks only when PayPal capture is{" "}
                <strong className="text-white/70">COMPLETED</strong> and{" "}
                <code className="text-fel-cyan/80">paypal-verify</code> succeeds. Set{" "}
                <code className="text-white/50">localStorage.fel_athlete_id</code> to link your lab athlete id.
              </p>
            </div>
            <div className="rounded-xl border border-fel-cyan/30 bg-black/40 px-4 py-3 text-right">
              <p className="text-[0.55rem] font-bold uppercase tracking-[0.28em] text-white/45">Shards</p>
              <p className="font-mono text-2xl font-black tabular-nums text-fel-cyan">{shardBalance}</p>
            </div>
          </div>

          <div className="mt-6">
            <PayPalMessagesStrip amountUsd={499} />
          </div>

          <div className="mt-10 grid gap-8 md:grid-cols-3">
            <SovereignPaymentPortal
              tier="alpha_49"
              onPurchaseVerified={handlePurchaseVerified}
              onVerifyFailed={handleVerifyFailed}
            />
            <SovereignPaymentPortal
              tier="alpha_99"
              onPurchaseVerified={handlePurchaseVerified}
              onVerifyFailed={handleVerifyFailed}
            />
            <SovereignPaymentPortal
              tier="alpha_499"
              onPurchaseVerified={handlePurchaseVerified}
              onVerifyFailed={handleVerifyFailed}
            />
          </div>
        </div>
      </section>

      <ThankYou downloadUnlocked={downloadUnlocked} />

      <footer className="border-t border-white/10 px-6 py-10 text-center text-xs text-white/35 sm:px-12">
        Freeway (live):{" "}
        <a href={PRODUCTION_FREWAY_URL} className="text-fel-cyan underline-offset-2 hover:underline">
          {PRODUCTION_FREWAY_URL.replace(/^https:\/\//, "")}
        </a>
        {" · "}
        Frame budget <span className="text-white/50">~16.67 ms</span> @ 60 Hz — clinical gate before Lab (
        <span className="text-white/45">z-index 1100</span>).
      </footer>
    </div>
  );
}
