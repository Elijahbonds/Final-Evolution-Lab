# Final Evolution — App Store Admin & Tester Onboarding (1.0.0)

**Audience:** Internal release managers, DA COMPOUND operators, and TestFlight coordinators.  
**Strict references:** `STAFF_HANDBOOK.md` (Neuro-Mechanic / Forensic vs Demo), `SHIP_CRITERIA.md` (hybrid 1.0.0 checklist, bundle ID, marketing version).

---

## Alignment with ship criteria

From **`SHIP_CRITERIA.md`**:

- **Marketing version:** `1.0.0` (Xcode `MARKETING_VERSION`).
- **Bundle ID (frozen):** `com.finalevolution.FinalEvoAPP`.
- **Hybrid checkpoints:** `readiness_snapshot.json` handoff, notification wiring, provisioning strings for System Scan + motion — verify in each **Build 5** candidate before promoting testers.

---

## DA COMPOUND — internal TestFlight group (“Build 5”)

| Step | Action |
|------|--------|
| **1. Group** | In App Store Connect → **Users and Access** / **TestFlight** (or your org’s equivalent), maintain an internal group **DA COMPOUND** for staff and trusted athletes. |
| **2. Build 5** | Upload **build number 5** (or the current **1.0.0** RC) from CI / `package_gold_master.sh`; set **What to Test** to: *Neuro-Mechanic readiness, Arena Unreal handshake, System Scan forensic gate, optional Demo Mode for floor demos.* |
| **3. Invitees** | Add Apple IDs for testers; prefer **internal** first, then **external** after Beta App Review if required. |

---

## Redeem Code workflow (promo / cohort access)

Some cohorts receive an **offer code** or **promo redemption** (App Store–managed). Standard practice:

1. **Issue** — Ops generates codes per cohort (athlete batch, showcase event); store mapping in your internal sheet (code → athlete email, expiry).
2. **Redeem** — Athlete opens **App Store** → account menu → **Redeem Gift Card or Code** (or follows Apple’s current redeem URL for offers), enters code, installs **Final Evolution**.
3. **Verify** — Confirm install shows **1.0.0** and **Build 5+** in Settings / About; first launch runs splash → System Scan entry per `TESTER_INVITE_TEMPLATE.md`.

*Note: Exact “Redeem Code” UI varies by Apple region and program; keep one internal SOP PDF with screenshots updated per iOS major.*

---

## System Scan success rates (tracking)

**Goal:** Measure how often athletes complete a **valid forensic scan** vs abandon or hit the lighting gate.

| Metric | How to track |
|--------|----------------|
| **Invites sent** | Export from mail / TestFlight group size. |
| **Installs** | App Store Connect **TestFlight** → installs per build. |
| **Scan started / completed** | Until in-app analytics ships: **weekly survey** to DA COMPOUND testers (“Did you complete System Scan this week?”) + support tickets. |
| **Forensic failures** | Support tags: *Lighting pause*, *video load error*, *compromised data* (see `TESTER_INVITE_TEMPLATE.md` troubleshooting). |

**Definition of success (forensic):** User completes scan with **ambient luma in range** so `readiness_snapshot.json` is written (see **Forensic Mode** in `STAFF_HANDBOOK.md` — lighting ≥ effective **0.3** normalized where `felNeuroMechanicLightingOptimal` is true).

**Demo Mode** completions **do not** count toward forensic success rate — they are **showcase-only** (`felDemoModeShowcase`, Fast-Track cached rig).

---

## Athlete Welcome Email (draft)

**Subject:** Welcome to Final Evolution 1.0.0 — TestFlight + System Scan

Hi [Name],

Welcome to **Final Evolution** on **TestFlight**. You’re part of the **DA COMPOUND** early access group for our **1.0.0** hybrid app (Swift shell + Unreal Arena + RealityKit Lab).

**Install**

1. Install **TestFlight** from the App Store (if needed).  
2. Open your invite email from Apple and tap **View in TestFlight**, or redeem your code per the instructions we sent.  
3. Install **Final Evolution** — confirm version **1.0.0** / **Build 5** (or latest RC) in-app.

**System Scan & modes (read this)**

We use two different ways to run **System Scan** — please read the detailed step-by-step in **`TESTER_INVITE_TEMPLATE.md`** in our repo (same content we send with every cohort):

- **Forensic mode** — Real calibration for PRQ and Unreal twin alignment. Requires **bright, even lighting**. If the app says forensic scan is paused for light, move to a brighter space until the message clears.  
- **Demo mode** — For **showcases and quick floor demos** only: **Settings → Demo Mode**, then **Fast-Track** reuses your last cached rig so you don’t need a full scan every time. **Do not** use Demo-only runs when a coach needs signed-off metrics.

**Links**

- Tester instructions: **`TESTER_INVITE_TEMPLATE.md`**  
- Operations context: **`STAFF_HANDBOOK.md`** (Neuro-Mechanic, Pixel Streaming ops, latency HUD)

Reply to this thread if anything fails to install or if System Scan won’t complete in good light.

— Final Evolution / DA COMPOUND

---

## Related documents

| Document | Use |
|----------|-----|
| `STAFF_HANDBOOK.md` | Forensic vs Demo, Pixel Streaming, 16.6 ms HUD, multi-athlete |
| `SHIP_CRITERIA.md` | Gold Master matrix, bundle ID, hybrid checkpoints |
| `TESTER_INVITE_TEMPLATE.md` | Copy-paste TestFlight body for athletes |

*Final Evolution LLC — internal admin use only.*
