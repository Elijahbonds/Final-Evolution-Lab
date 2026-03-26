import { lazy, Suspense, useCallback, useEffect, useState } from "react";
import type { SovereignAlphaTier } from "./constants/paypal";
import { PRODUCTION_FREWAY_URL } from "./constants/site";
import { AppView } from "./components/AppView";
import {
  SectionAcademy,
  SectionArena,
  SectionPRQ,
  SectionSystemScan,
} from "./components/ClinicalGatewaySections";
import { HUDOverlay } from "./components/HUDOverlay";
import { MedicalDisclaimerGateway } from "./components/MedicalDisclaimerGateway";
import { PayPalMessagesStrip, SovereignPaymentPortal } from "./components/SovereignPaymentPortal";
import { SiteNav } from "./components/SiteNav";
import { ThankYou } from "./components/ThankYou";

const HeroSpiral = lazy(() =>
  import("./components/HeroSpiral").then((m) => ({ default: m.HeroSpiral }))
);

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
  const [downloadUnlocked, setDownloadUnlocked] = useState(false);
  const [creditBalance, setCreditBalance] = useState(0);

  /** Athlete readiness dashboard — same-page, no external routes. */
  const scrollToTruthDashboard = useCallback(() => {
    document.getElementById("fel-lab")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, []);

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
      setCreditBalance((s) => s + shardDelta);
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
      <MedicalDisclaimerGateway open={!medicalAck} onClose={handleLandingAcknowledge} />

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
              Final Evolution Lab
            </p>
            <h1 className="mt-4 text-4xl font-black leading-[1.05] tracking-tight text-white sm:text-5xl md:text-6xl [text-shadow:0_0_40px_rgba(92,225,230,0.25)]">
              THE BIOMECHANICAL TRUTH
            </h1>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-white/75 sm:text-lg">
              Your <strong className="font-semibold text-white/90">Performance Readiness Quotient (PRQ)</strong>,{" "}
              <strong className="font-semibold text-white/90">System Scan</strong> intake, and{" "}
              <strong className="font-semibold text-white/90">12-Module Academy</strong> — one sovereign lane for
              athletes and staff who train with intent.
            </p>

            <div className="mt-10">
              <button
                type="button"
                onClick={scrollToTruthDashboard}
                className="inline-flex min-h-[56px] min-w-[220px] items-center justify-center rounded-full bg-fel-cyan px-12 text-base font-black uppercase tracking-[0.14em] text-black shadow-[0_0_36px_rgba(92,225,230,0.5)] transition hover:bg-fel-cyan/90 hover:shadow-[0_0_52px_rgba(92,225,230,0.6)]"
              >
                Open lab
              </button>
              <p className="mt-4 max-w-md text-xs text-white/40">
                Movement education — not medical diagnosis or treatment. Opens the calibration and readiness dashboard
                on this page.
              </p>
            </div>
          </div>
        </div>
      </section>

      <SiteNav />
      <SectionPRQ />
      <SectionSystemScan />
      <SectionAcademy />
      <SectionArena />
      <AppView />

      <section
        id="sovereign-access"
        className="relative z-40 border-t border-white/10 bg-fel-black px-6 py-16 sm:px-12"
      >
        <div className="mx-auto max-w-6xl">
          <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h2 className="text-[0.65rem] font-bold uppercase tracking-[0.35em] text-fel-cyan">
                Sovereign access
              </h2>
              <p className="mt-2 max-w-2xl text-sm text-white/55">
                Secure PayPal checkout. <strong className="text-white/90">Evolution Shards</strong> for progression,{" "}
                <strong className="text-white/90">System calibration credits</strong> for advanced protocol builds, and
                full <strong className="text-white/90">12-Module Academy</strong> access at the top tier. The Mac
                installer unlocks when payment completes successfully.
              </p>
            </div>
            <div className="rounded-xl border border-fel-cyan/30 bg-black/40 px-4 py-3 text-right">
              <p className="text-[0.55rem] font-bold uppercase tracking-[0.28em] text-white/45">Evolution Shards</p>
              <p className="font-mono text-2xl font-black tabular-nums text-fel-cyan">{creditBalance}</p>
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
        <a href={PRODUCTION_FREWAY_URL} className="text-fel-cyan underline-offset-2 hover:underline">
          {PRODUCTION_FREWAY_URL.replace(/^https:\/\//, "")}
        </a>
        {" · "}Movement education. Not medical advice.
      </footer>
    </div>
  );
}
