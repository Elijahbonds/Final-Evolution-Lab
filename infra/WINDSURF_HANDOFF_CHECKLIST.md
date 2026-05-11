# Windsurf handoff checklist

Use this when handing the repo from CI / Cursor cleanup to **Windsurf** (or another desktop agent) for **local Unreal Engine + Xcode** work. Goal: same guardrails as Cursor Cloud, without assuming VM-only tooling.

## 1. Repo state

- [ ] On the integration branch described in **`infra/SHIPPING.md`** (prefer cherry-picks over unrelated merges).
- [ ] Phase patches (1–10) applied or equivalent changes merged.

## 2. Static preflight (required)

From repo root:

```bash
chmod +x scripts/fel_release_preflight.sh
./scripts/fel_release_preflight.sh
```

This verifies:

- **`SHIPPING_ARCHITECTURE.md`** (architecture lock + App Store / IAP posture).
- StoreKit **fail-closed** path markers (`backend/iap_verify.py`, IAP route in `server.py`).
- **Realtime** trust contract + sovereign WebSocket auth helper.
- **Scan**, **gameplay**, **education**, **BioFuel**, **economy**, **privacy/minor** contracts under **`infra/*CONTRACT*.md`**.
- **`backend/privacy_minors.py`** and **`backend/routers/biofuel.py`** presence.

Fix failures before shipping or before large UE/Xcode refactors.

## 3. Optional release manifest validation

If you maintain Firebase / Data Connect locally:

```bash
./scripts/validate_release_manifest.sh
```

## 4. Superapp desktop reference bundle

Refresh the folder Windsurf should open alongside the UE project:

```bash
./scripts/sync_superapp_desktop.sh
```

This copies **`superapp-reference/*.md`**, **`superapp-reference/desktop-bundle/*`**, and **`SHIPPING_ARCHITECTURE.md`** into **`~/Desktop/FEL-Superapp-Reference`** (override with **`DEST=`**).

Point Windsurf’s workspace or context at **`FEL-Superapp-Reference`** so architecture lock and pipe docs stay attached to local builds.

## 5. Read before changing wiring

- **`DELIVERY_BAR_FINAL_EVOLUTION.md`** — product acceptance standard per pillar (vision intact; bar rises until the app catches it).
- **`SHIPPING_ARCHITECTURE.md`** — shipping path, WKWebView overlay, commerce boundaries.
- **`infra/REALTIME_TRUST_CONTRACT.md`** — WebSocket identity and progression.
- **`infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md`** — scan / PRQ boundaries.
- **`infra/GAMEPLAY_RECEIPT_CONTRACT.md`** — session receipts and trust levels.

## 6. Local UE / Xcode expectations

- Unreal + iOS packaging scripts live under repo **`infra/`** and **`scripts/`** per **`infra/SHIPPING.md`** (not runnable in cloud-only agents).
- **`fel_ue5_ios_shipping_package.sh`** — build/archive/export flow when executing on macOS with Xcode + UE installed.

## 7. Done criteria

- [ ] `./scripts/fel_release_preflight.sh` exits **0**.
- [ ] **`sync_superapp_desktop.sh`** run so **`SHIPPING_ARCHITECTURE.md`** is on the Desktop reference bundle.
- [ ] Windsurf (or IDE) has **`SHIPPING_ARCHITECTURE.md`** in context for the session.

That completes the **“do not drift”** path: **preflight → sync reference bundle → local UE/Xcode**.
