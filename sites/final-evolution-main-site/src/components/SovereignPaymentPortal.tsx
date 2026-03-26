import { useEffect, useRef, useState } from "react";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  PAYPAL_VERIFY_URL_DEFAULT,
  TIER_SHARD_DELTA,
  type SovereignAlphaTier,
} from "../constants/paypal";

export type { SovereignAlphaTier };

/** PayPal JS SDK (loaded from index.html): Smart Buttons + Messages. */
declare global {
  interface Window {
    paypal?: PayPalNamespace;
  }
}

type PayPalMessagesFactory = (opts: {
  amount: number | string;
  currency?: string;
  placement?: string;
  style?: Record<string, unknown>;
}) => { render: (sel: HTMLElement) => Promise<void> };

type PayPalNamespace = {
  Buttons: (opts: PayPalButtonOptions) => { render: (sel: HTMLElement) => Promise<void> };
  Messages?: PayPalMessagesFactory;
};

type PayPalButtonOptions = {
  style?: Record<string, string | number | boolean | undefined>;
  createOrder: (
    data: unknown,
    actions: { order: { create: (o: PayPalOrderPayload) => Promise<string> } }
  ) => Promise<string>;
  onApprove: (
    data: { orderID: string; payerID: string },
    actions: { order: { capture: () => Promise<unknown> } }
  ) => Promise<void>;
  onError?: (err: unknown) => void;
};

type PayPalOrderPayload = {
  purchase_units: Array<{
    amount: { currency_code: string; value: string };
    description?: string;
    custom_id?: string;
  }>;
};

const TIER_CONFIG: Record<
  SovereignAlphaTier,
  { title: string; amountUsd: string; buttonColor: "gold" | "silver" }
> = {
  alpha_49: { title: "Shard Pack — Alpha", amountUsd: "49.00", buttonColor: "gold" },
  alpha_99: { title: "Shard Pack — Pro", amountUsd: "99.00", buttonColor: "silver" },
  alpha_499: { title: "VVA Academy — Sovereign", amountUsd: "499.00", buttonColor: "gold" },
};

function readAthleteId(): string {
  try {
    return (
      localStorage.getItem("fel_athlete_id") ??
      localStorage.getItem("FEL_ATHLETE_ID") ??
      ""
    ).trim();
  } catch {
    return "";
  }
}

let supabaseSingleton: SupabaseClient | null = null;

function getSupabase(): SupabaseClient | null {
  const url = import.meta.env.VITE_SUPABASE_URL;
  const key = import.meta.env.VITE_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  if (!supabaseSingleton) {
    supabaseSingleton = createClient(url, key, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
  }
  return supabaseSingleton;
}

function verifyEndpoint(): string {
  const explicit = import.meta.env.VITE_PAYPAL_VERIFY_URL?.trim();
  if (explicit) return explicit.replace(/\/$/, "");
  const base = import.meta.env.VITE_SUPABASE_URL?.replace(/\/$/, "");
  if (base) return `${base}/functions/v1/paypal-verify`;
  return PAYPAL_VERIFY_URL_DEFAULT;
}

let scriptPromise: Promise<PayPalNamespace> | null = null;

function waitForPayPal(timeoutMs = 20000): Promise<PayPalNamespace> {
  if (window.paypal) return Promise.resolve(window.paypal);
  if (scriptPromise) return scriptPromise;

  scriptPromise = new Promise((resolve, reject) => {
    const clientId = import.meta.env.VITE_PAYPAL_CLIENT_ID || "YOUR_PAYPAL_CLIENT_ID";
    const script = document.createElement("script");
    script.src = `https://www.paypal.com/sdk/js?client-id=${clientId}&components=buttons,messages&currency=USD&enable-funding=venmo,paylater,card`;
    script.defer = true;
    
    const timeout = setTimeout(() => {
      reject(new Error("PayPal SDK load timed out."));
    }, timeoutMs);

    script.onload = () => {
      clearTimeout(timeout);
      if (window.paypal) resolve(window.paypal);
      else reject(new Error("PayPal SDK namespace not found."));
    };
    script.onerror = () => {
      clearTimeout(timeout);
      reject(new Error("Failed to load PayPal SDK script."));
    };
    
    document.head.appendChild(script);
  });
  return scriptPromise;
}

export type SovereignPaymentPortalProps = {
  tier: SovereignAlphaTier;
  className?: string;
  /** After server verify succeeds (optional; use with optimistic capture). */
  onSuccess?: () => void;
  /** Immediately after PayPal capture, before Edge verify — optimistic shards + unlock. */
  onCaptureOptimistic?: (info: { tier: SovereignAlphaTier; shardDelta: number }) => void;
  /** Roll back optimistic UI if `paypal-verify` fails. */
  onVerifyFailed?: () => void;
};

/**
 * PayPal Smart Payment Buttons (PayPal, card, Pay Later).
 * onApprove: capture order, POST { orderID, athlete_id } to `paypal-verify`.
 */
export function SovereignPaymentPortal({
  tier,
  className = "",
  onSuccess,
  onCaptureOptimistic,
  onVerifyFailed,
}: SovereignPaymentPortalProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const onSuccessRef = useRef(onSuccess);
  onSuccessRef.current = onSuccess;
  const onCaptureOptimisticRef = useRef(onCaptureOptimistic);
  onCaptureOptimisticRef.current = onCaptureOptimistic;
  const onVerifyFailedRef = useRef(onVerifyFailed);
  onVerifyFailedRef.current = onVerifyFailed;
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const cfg = TIER_CONFIG[tier];

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    let cancelled = false;
    const localCfg = TIER_CONFIG[tier];

    (async () => {
      if (!getSupabase()) {
        setError("Configure VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY.");
        return;
      }

      try {
        const paypal = await waitForPayPal();
        if (cancelled) return;
        el.replaceChildren();

        const buttons = paypal.Buttons({
          style: {
            layout: "vertical",
            color: localCfg.buttonColor,
            shape: "rect",
            borderRadius: 10,
            tagline: false,
            height: 48,
          },
          createOrder: async (_data, actions) => {
            const supabase = getSupabase();
            if (!supabase) throw new Error("Supabase not configured");
            const { data } = await supabase.auth.getSession();
            const uid = data.session?.user?.id;
            if (!uid) {
              setError("Sign in (Wallet) before checkout.");
              throw new Error("auth");
            }
            return actions.order.create({
              purchase_units: [
                {
                  amount: { currency_code: "USD", value: localCfg.amountUsd },
                  description: localCfg.title,
                  custom_id: `${tier}:${uid}`,
                },
              ],
            });
          },
          onApprove: async (data, actions) => {
            setBusy(true);
            setError(null);
            try {
              await actions.order.capture();

              const shardDelta = TIER_SHARD_DELTA[tier];
              onCaptureOptimisticRef.current?.({ tier, shardDelta });

              const supabase = getSupabase();
              if (!supabase) {
                setError("Supabase not configured.");
                onVerifyFailedRef.current?.();
                return;
              }

              const { data: auth } = await supabase.auth.getSession();
              const session = auth.session;
              if (!session?.user?.id) {
                setError("Session expired.");
                onVerifyFailedRef.current?.();
                return;
              }

              const endpoint = verifyEndpoint();
              const athleteId = readAthleteId();

              const res = await fetch(endpoint, {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  Authorization: `Bearer ${session.access_token}`,
                  apikey: import.meta.env.VITE_SUPABASE_ANON_KEY,
                },
                body: JSON.stringify({
                  orderID: data.orderID,
                  athlete_id: athleteId || undefined,
                }),
              });

              const payload = (await res.json().catch(() => ({}))) as { error?: string };
              if (!res.ok) {
                setError(payload.error ?? `Verify failed (${res.status})`);
                onVerifyFailedRef.current?.();
                return;
              }

              onSuccessRef.current?.();
            } catch (e) {
              setError(e instanceof Error ? e.message : "Checkout error");
              onVerifyFailedRef.current?.();
            } finally {
              setBusy(false);
            }
          },
          onError: (err) => {
            console.error(err);
            setError("PayPal error — try again.");
          },
        });

        await buttons.render(el);
      } catch (e) {
        if (!cancelled) {
          setError(e instanceof Error ? e.message : "Failed to load PayPal");
        }
      }
    })();

    return () => {
      cancelled = true;
      el.replaceChildren();
    };
  }, [tier]);

  return (
    <div
      className={`rounded-2xl border-2 border-fel-cyan/60 bg-black/40 p-4 shadow-[0_0_24px_rgba(92,225,230,0.12)] backdrop-blur-md ${className}`}
    >
      <div className="mb-3 flex items-baseline justify-between gap-2">
        <h3 className="text-sm font-bold uppercase tracking-[0.2em] text-fel-cyan">{cfg.title}</h3>
        <span className="text-lg font-black text-white/90">${cfg.amountUsd}</span>
      </div>
      <p className="mb-4 text-xs leading-relaxed text-white/50">
        PayPal, credit card, or Pay Later — shards update optimistically on capture; server verifies in background.
      </p>
      <div
        ref={containerRef}
        className={`min-h-[120px] w-full max-w-md ${busy ? "pointer-events-none opacity-60" : ""}`}
      />
      {error ? (
        <p className="mt-3 text-xs text-amber-300/95" role="alert">
          {error}
        </p>
      ) : null}
    </div>
  );
}

/** Pay Later / messaging strip (PayPal Messages component). */
export function PayPalMessagesStrip({ amountUsd }: { amountUsd: number }) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let cancelled = false;

    (async () => {
      try {
        const paypal = await waitForPayPal();
        if (cancelled || !paypal.Messages) return;
        el.replaceChildren();
        await paypal
          .Messages({
            amount: amountUsd,
            currency: "USD",
            placement: "product",
            style: { layout: "text", text: { color: "white" } },
          })
          .render(el);
      } catch {
        /* optional */
      }
    })();

    return () => {
      cancelled = true;
      el.replaceChildren();
    };
  }, [amountUsd]);

  return (
    <div
      ref={ref}
      className="min-h-[40px] w-full max-w-3xl rounded-xl border border-fel-cyan/30 bg-black/30 p-3 text-xs text-white/70"
    />
  );
}
