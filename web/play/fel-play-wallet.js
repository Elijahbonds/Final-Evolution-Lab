/**
 * Compact Sovereign wallet status on /play/ — same Supabase project as /wallet/ and iOS.
 * Requires fel-public-config.js (parent sets window.FEL_SUPABASE_URL / FEL_SUPABASE_ANON_KEY).
 */
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm";

function el(id) {
  return document.getElementById(id);
}

async function main() {
  const url = typeof window.FEL_SUPABASE_URL === "string" ? window.FEL_SUPABASE_URL.trim() : "";
  const key = typeof window.FEL_SUPABASE_ANON_KEY === "string" ? window.FEL_SUPABASE_ANON_KEY.trim() : "";
  const status = el("fel-play-wallet-status");
  if (!status) return;
  if (!url || !key) {
    status.innerHTML =
      'Configure <code>fel-public-config.js</code> (see <code>fel-public-config.example.js</code>) to enable wallet sync.';
    return;
  }

  const supabase = createClient(url, key, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  });

  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    status.innerHTML =
      '<a href="/wallet/">Open Sovereign Wallet</a> to sign in — same account as TestFlight and shard purchases.';
    return;
  }

  const { data: row, error } = await supabase
    .from("user_balances")
    .select("shard_balance, cortex_credits")
    .eq("user_id", session.user.id)
    .maybeSingle();

  if (error) {
    status.textContent = "Could not load balance (check RLS / sign-in).";
    return;
  }

  const shards = row?.shard_balance ?? 0;
  const cortex = row?.cortex_credits ?? 0;
  status.innerHTML =
    "<strong>Shards:</strong> " +
    shards +
    " · <strong>Cortex:</strong> " +
    cortex +
    ' · <a href="/wallet/">Wallet</a>';

  supabase.channel("play-wallet").on(
    "postgres_changes",
    { event: "*", schema: "public", table: "user_balances", filter: "user_id=eq." + session.user.id },
    async () => {
      const { data: r } = await supabase
        .from("user_balances")
        .select("shard_balance, cortex_credits")
        .eq("user_id", session.user.id)
        .maybeSingle();
      if (r && el("fel-play-wallet-status")) {
        el("fel-play-wallet-status").innerHTML =
          "<strong>Shards:</strong> " +
          (r.shard_balance ?? 0) +
          " · <strong>Cortex:</strong> " +
          (r.cortex_credits ?? 0) +
          ' · <a href="/wallet/">Wallet</a>';
      }
    }
  ).subscribe();
}

main().catch(function (e) {
  const s = el("fel-play-wallet-status");
  if (s) s.textContent = String(e && e.message ? e.message : e);
});
