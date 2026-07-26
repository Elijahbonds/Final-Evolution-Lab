#!/usr/bin/env bash
# fel_release_preflight.sh — static guardrails before UE/Xcode handoff or release tagging.
# Does not build; verifies docs + invariant markers exist so architecture/trust contracts cannot silently drift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0
fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}
pass() {
  echo "OK:   $*"
}

echo "== FEL release preflight (repo: $ROOT) =="
echo

# --- Architecture lock ---
if [[ ! -f "$ROOT/SHIPPING_ARCHITECTURE.md" ]]; then
  fail "missing SHIPPING_ARCHITECTURE.md (shipping architecture lock)"
else
  pass "SHIPPING_ARCHITECTURE.md present"
fi
if [[ -f "$ROOT/SHIPPING_ARCHITECTURE.md" ]] && ! grep -qi "Shipping architecture lock" "$ROOT/SHIPPING_ARCHITECTURE.md"; then
  fail "SHIPPING_ARCHITECTURE.md missing expected lock header"
fi

# --- Product delivery bar (vision intact; acceptance criteria per pillar) ---
if [[ ! -f "$ROOT/DELIVERY_BAR_FINAL_EVOLUTION.md" ]]; then
  fail "missing DELIVERY_BAR_FINAL_EVOLUTION.md"
else
  pass "DELIVERY_BAR_FINAL_EVOLUTION.md present"
fi
if [[ ! -f "$ROOT/infra/CURSOR_MEET_THE_BAR_PROMPT.md" ]]; then
  fail "missing infra/CURSOR_MEET_THE_BAR_PROMPT.md"
else
  pass "infra/CURSOR_MEET_THE_BAR_PROMPT.md present"
fi

# --- App Store posture (documented in canonical lock) ---
if [[ -f "$ROOT/SHIPPING_ARCHITECTURE.md" ]]; then
  if ! grep -Eqi 'StoreKit|In-App Purchase|IAP' "$ROOT/SHIPPING_ARCHITECTURE.md"; then
    fail "SHIPPING_ARCHITECTURE.md should mention StoreKit / IAP posture"
  else
    pass "App Store / IAP posture referenced in SHIPPING_ARCHITECTURE.md"
  fi
fi

# --- StoreKit gate (fail-closed verification path) ---
if [[ ! -f "$ROOT/backend/iap_verify.py" ]]; then
  fail "missing backend/iap_verify.py"
else
  pass "backend/iap_verify.py present"
fi
if [[ -f "$ROOT/backend/iap_verify.py" ]] && ! grep -Eqi 'fail.closed|fail-closed' "$ROOT/backend/iap_verify.py"; then
  fail "backend/iap_verify.py missing fail-closed fulfillment note"
fi
if [[ ! -f "$ROOT/backend/server.py" ]] || ! grep -q '/payments/iap/verify' "$ROOT/backend/server.py"; then
  fail "backend/server.py missing POST /payments/iap/verify route"
else
  pass "IAP verify route present in server.py"
fi

# --- Realtime trust ---
for f in infra/REALTIME_TRUST_CONTRACT.md; do
  if [[ ! -f "$ROOT/$f" ]]; then fail "missing $f"; else pass "$f"; fi
done
if [[ -f "$ROOT/backend/server.py" ]] && ! grep -q '_fel_vault_ws_require_auth' "$ROOT/backend/server.py"; then
  fail "backend/server.py missing vault WS auth gate helper"
else
  pass "Vault WS require-auth helper present"
fi

# --- Scan trust ---
if [[ ! -f "$ROOT/infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md" ]]; then
  fail "missing infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md"
else
  pass "infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md"
fi

# --- Gameplay trust ---
if [[ ! -f "$ROOT/infra/GAMEPLAY_RECEIPT_CONTRACT.md" ]]; then
  fail "missing infra/GAMEPLAY_RECEIPT_CONTRACT.md"
else
  pass "infra/GAMEPLAY_RECEIPT_CONTRACT.md"
fi

# --- Required infra contracts (phase cleanup set) ---
required_contracts=(
  infra/EDUCATION_INTEGRITY_CONTRACT.md
  infra/BIOFUEL_NUTRITION_SAFETY_CONTRACT.md
  infra/ECONOMY_AUTHORITY_CONTRACT.md
  infra/PRIVACY_MINOR_SAFETY_CONTRACT.md
)
for c in "${required_contracts[@]}"; do
  if [[ ! -f "$ROOT/$c" ]]; then
    fail "missing $c"
  else
    pass "$c"
  fi
done

# --- Supporting enforcement surfaces (quick existence checks) ---
if [[ ! -f "$ROOT/backend/privacy_minors.py" ]]; then
  fail "missing backend/privacy_minors.py (public discovery / minor policy)"
else
  pass "backend/privacy_minors.py"
fi
if [[ ! -f "$ROOT/backend/routers/biofuel.py" ]]; then
  fail "missing backend/routers/biofuel.py"
else
  pass "backend/routers/biofuel.py"
fi
if [[ ! -f "$ROOT/infra/SHIPPING.md" ]]; then
  fail "missing infra/SHIPPING.md"
else
  pass "infra/SHIPPING.md"
fi

echo
if [[ "$failures" -gt 0 ]]; then
  echo "== fel_release_preflight: FAILED ($failures issue(s)) ==" >&2
  exit 1
fi
echo "== fel_release_preflight: PASS =="
exit 0
