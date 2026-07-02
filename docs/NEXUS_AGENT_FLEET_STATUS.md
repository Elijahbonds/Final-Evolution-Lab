# NEXUS Agent Fleet Status

> **Orchestration:** [`docs/NEXUS_AGENT_ORCHESTRATION.md`](./NEXUS_AGENT_ORCHESTRATION.md) · **Roles:** [`Config/nexus_agent_roles.json`](../Config/nexus_agent_roles.json)  
> **Canonical repo:** `/Users/elijahbonds/Final-Evolution-Lab` · **PM maintains this file after each subagent completion**

**Last updated:** 2026-06-19 (PM refresh — **DGE sprint** open: distribution + gameplay + engine)  
**Session:** parent coordinator · PM + Senior Advisor active · **Final sprint CLOSED (partial)** · **DGE sprint OPEN**

---

## PM snapshot (top 5 blockers — ship-complete game + engine)

| # | Pri | Blocker | Drift / matrix | Owner | Unblocks |
|---|:---:|---------|----------------|-------|----------|
| 1 | **P0** | Real `GoogleService-Info.plist` (not placeholder) | V-003 **OPEN** (production leg) | `ios_ship` | User: Firebase console download → `FinalEvolutionLab/GoogleService-Info.plist` |
| 2 | **P0** | ASC app record + Transporter upload for `com.finalevolutionlab.app` | V-003 upload leg, DoD #9 | **User** → `ios_ship` | Create app in ASC; upload `build/FEL-export/FinalEvolutionLab.ipa` |
| 3 | **P1** | Device runtime proof — unlock iPhone → `devicectl launch` → Venice mesh draw on physical device | V-013, Delivery #3 runtime | `ios_ship` + `renderer` + `assets` | User unlock; `NEXUS_USE_METAL=1` dunk session |
| 4 | **P2** | Production session receipt POST (2xx on device with real plist) | V-012 **PARTIAL** | `backend` | Blocker #1; verify queue drain + economy ingest |
| 5 | **P2** | Instruments 60 FPS @ mobile mesh profile on physical iPhone | V-013, DoD #2 | `renderer` | Blocker #3 + Time Profiler session |

**Closed (final sprint — do not retask):** 18/18 production modes (`c8d0c619`); build gate 7/7+8/8+18/18 (`99dabc11`); V-004/V-005 registry (`4ef42861`); V-006/V-007/V-008 legacy + preview labels (`f4dd540c`); V-011 UX bar competitive row (`9fd31de3`); venue bundle install partial (`78a4333f`, `97a0f78b`); Firebase SDK + preview IPA export (`--preview-firebase --export` PASS); backend queue/drain partial (V-012 preview lane); Metal sim partial (V-013 compile + sim launch); NEXUS Studio v0.3 (`195444b1`); generator LLM template MVP; sim FR gate tranche PASS (`support_gate_handoff.json` 21:52Z); hurdle brainstorm matrix (`docs/NEXUS_SPRINT_HURDLE_BRAINSTORM.md`).

**Spec v1 DoD:** **5/9 met · 3 partial · 1 open** — open items map to blockers #1–2 (DoD #9), #3 (DoD #1), #4 (DoD #4), #5 (DoD #2).

---

## DGE sprint — 10-agent assignments (distribution + gameplay + engine)

**Sprint ID:** `sprint-dge-2026-06-19`  
**Tracks:** **Distribution** (plist · ASC · IPA · receipt POST · matrix DoD) · **Gameplay** (18/18 modes · regression unison · registry guard) · **Engine** (build gate · Metal · bundle runtime · drift audit)

PM owns coordination; **9 implementation specialties** below. **P0 distribution** serializes on `ios_ship` (plist → ASC). **Gameplay + engine** run parallel where no file conflicts. Agents blocked on user Firebase/ASC run **idle brainstorm** assists (see table below) — Advisor **APPROVED** items only; no auto-spawn.

| Agent | Specialty | Sprint `task_id` | Track | Assignment | Pri | Drift / matrix | Status |
|-------|-----------|------------------|-------|------------|:---:|----------------|--------|
| PM | `project_manager` | `sprint-pm-dge` | — | Fleet status, retask queue, Advisor veto, ingest handoffs | — | all | **in flight** |
| 1 | `ios_ship` | `sprint-dge-dist-ios` | **Distribution** | Production plist → `--export` (no preview) → ASC upload; device launch QA | P0 | V-003, ASC | **blocked** (user plist + ASC) |
| 2 | `gameplay_tester` | `sprint-dge-gameplay-unison` | **Gameplay** | Regression unison loop; `gameplay_handoff.json`; 18/18 mode depth; generative gap doc | P1 | staging, LLM gen | **in flight** |
| 3 | `debugging` | `sprint-dge-engine-gate` | **Engine** | Gate watchdog; `nexus_build_gate.sh` + flake notes (`nexus_renderer_test` parallel) | P1 | CI hygiene | **queued** |
| 4 | `registry` | `sprint-dge-registry-guard` | **Gameplay** | Post-promotion skew guard; `kProductionModeIds` vs validate script | P2 | V-004/V-005 guard | **queued** |
| 5 | `renderer` | `sprint-dge-engine-metal` | **Engine** | Metal sim visual proof; device dunk + Instruments after unlock | P1 | V-013, DoD #1–2 | **blocked** (device lock) |
| 6 | `assets` | `sprint-dge-engine-bundle` | **Engine** | Device bundle runtime proof; `NEXUS_RESOURCE_ROOT` after launch | P1 | Delivery #3 | **blocked** (device lock) |
| 7 | `backend` | `sprint-dge-dist-receipt` | **Distribution** | Queue + drain wired; production POST 2xx with real plist | P2 | V-012 | **blocked** (user plist) |
| 8 | `vision_guardian` | `sprint-dge-vision-audit` | **Engine** | Legacy grep + drift delta; V-003 guard (no FIXED without prod export) | P1 | V-003 guard, V-006/V-007 | **queued** |
| 9 | `docs` | `sprint-dge-dist-matrix` | **Distribution** | Delivery matrix DoD sync (5/9 honest); FAD clipboard cross-ref | P2 | matrix DoD | **queued** |
| — | `error_editor` | `sprint-error-oncall` | **Engine** | On-call — narrow compile fixes | P3 | — | **on-call** |

**Support (spawn on request, not counted in 10):** `support_build_verify` — gate/bundle PASS/FAIL; `support_docs_drift` — fleet row ingest after each handoff.

**Distribution workaround (Advisor APPROVED while ASC blocked):** `--export-adhoc` → Firebase App Distribution (`docs/NEXUS_FIREBASE_APP_DISTRIBUTION_CLIPBOARD.md`) — not retail TestFlight; honest PREVIEW labeling required.

---

## In flight (DGE sprint)

| Agent ID | Specialty | Task | `task_id` | Started (UTC) | Latest |
|----------|-----------|------|-----------|---------------|--------|
| — | `project_manager` | DGE sprint fleet + retask queue | `sprint-pm-dge` | 2026-06-19 | **in flight** |
| — | `gameplay_tester` | Regression unison + `gameplay_handoff.json` refresh | `sprint-dge-gameplay-unison` | 2026-06-19 | **in flight** — sim FR **PASS** (`gameplay_handoff.json` 21:52Z); UI FR doc refresh open |
| — | `ios_ship` | Production plist → `--export` → ASC Transporter | `sprint-dge-dist-ios` | 2026-06-19 | **blocked** — preview IPA + Firebase SDK **done**; user plist + ASC |
| — | `renderer` | Device Metal dunk + Instruments 60 FPS | `sprint-dge-engine-metal` | 2026-06-19 | **blocked** — sim Metal partial **done**; device locked |
| — | `assets` | Runtime bundle proof on device after launch | `sprint-dge-engine-bundle` | 2026-06-19 | **blocked** — install + 28 meshes **done**; runtime draw open |
| — | `backend` | Production receipt POST 2xx on device | `sprint-dge-dist-receipt` | 2026-06-19 | **blocked** — queue/drain partial **done**; live POST needs plist |
| — | `vision_guardian` | Legacy + doc regression audit | `sprint-dge-vision-audit` | 2026-06-19 | **queued** |
| — | `docs` | Delivery matrix DoD 5/9 sync + FAD cross-ref | `sprint-dge-dist-matrix` | 2026-06-19 | **queued** |
| — | `debugging` | Gate watchdog + parallel flake mitigation note | `sprint-dge-engine-gate` | 2026-06-19 | **queued** |
| — | `registry` | Registry skew guard post 18/18 promotion | `sprint-dge-registry-guard` | 2026-06-19 | **queued** |
| `3e4b35de` | `error_editor` | Narrow compile / symbol fixes | `sprint-error-oncall` | — | **on-call** |

*Stale UE offload tasks (`10090164`, `a86d35ed`) — **Advisor veto:** not NEXUS ship; cancelled.*

---

## Completed (last 10)

| — | `backend` | Designed and implemented Creator Royalty Ledger & Shard Economy Integrator; added pendingRoyaltyShards, ClaimRoyalties mutation, and executeMarketplacePurchaseWithRoyalty | 2026-06-27 |
| — | `mocap_serializer` | Designed and implemented `NexusAnimationAsset.swift` and integrated with `UserProfile.swift` | 2026-06-27 |

| Agent ID | Specialty | Summary | Done (UTC) |
|----------|-----------|---------|------------|
| — | `support_docs_drift` | `[support-docs-fr]` Sim FR coord ingest — gate **PASS** rows in fleet + delivery matrix | 2026-06-19 |
| — | `support_build_verify` | `[support]` Sim FR gate **PASS** 7/7+8/8+18/18 (`support_gate_handoff.json` 21:52Z) | 2026-06-19 |
| — | `quality_check` | `[quality-fr-unison]` Independent gate confirm composite **8.0** | 2026-06-19 |
| `c8d0c619` | `gameplay_tester` | **18/18** production modes @ mobile; 0/0 staging (all promoted) | 2026-06-19 |
| `99dabc11` | `debugging` | Quality gate **PASS** 7/7+8/8+**18/18** modes; snowboarding gate **CLOSED** | 2026-06-19 |
| `78a4333f` | `assets` | Device bundle **PASS (partial)** — 28 meshes + `devicectl install` SUCCESS | 2026-06-19 |
| — | `ios_ship` | Firebase SDK + preview archive/export **PASS** (`--preview-firebase --export`) | 2026-06-19 |
| — | `backend` | V-012 **PARTIAL** — C++ queue + Swift drain wired | 2026-06-19 |
| — | `renderer` | V-013 **PARTIAL** — `NexusMetalBridge` compile; sim Metal launch OK | 2026-06-19 |
| — | `support_docs_drift` | Sprint hurdle brainstorm → `docs/NEXUS_SPRINT_HURDLE_BRAINSTORM.md` | 2026-06-19 |

---

## Blocked (needs user)

| Item | Why blocked | Unblocks | Owner `task_id` |
|------|-------------|----------|-----------------|
| **P0 production Firebase (V-003)** | Preview path live; real plist not in tree | Download plist → `./scripts/archive-ios-testflight.sh --export` (no preview) | `sprint-dge-dist-ios` |
| **P0 ASC app record** | Transporter `missingApp` — no ASC record for bundle ID | Create app in App Store Connect | User → `sprint-dge-dist-ios` |
| **P1 device runtime (V-013 / Delivery #3)** | `devicectl install` OK; `devicectl launch` failed (`device locked`) | Unlock iPhone; `NEXUS_USE_METAL=1` dunk session | `sprint-dge-engine-metal`, `sprint-dge-engine-bundle` |
| **P2 production receipt (V-012)** | Preview lane queue-only; live POST untested with real auth | Real plist + Anonymous Auth enabled | `sprint-dge-dist-receipt` |

### V-003 user steps (Firebase console)

1. Open [Firebase Console — final-evolution-lab](https://console.firebase.google.com/project/final-evolution-lab/overview).
2. **Project settings** → **General** → iOS app **`com.finalevolutionlab.app`** (add if missing).
3. Download **`GoogleService-Info.plist`** → **`/Users/elijahbonds/Final-Evolution-Lab/FinalEvolutionLab/GoogleService-Info.plist`** (gitignored).
4. Verify: `BUNDLE_ID` = `com.finalevolutionlab.app`, `PROJECT_ID` = `final-evolution-lab`.
5. Enable **Authentication → Anonymous** and **Firestore**.
6. Reply when done → `ios_ship` runs `sprint-dge-dist-ios`.

### ASC app user steps

1. [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** New App.
2. Bundle ID: **`com.finalevolutionlab.app`**; SKU/name per `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`.
3. Upload IPA via Transporter after production export (or `--export-adhoc` for Firebase App Distribution while ASC pending).

---

## Idle / brainstorming (blocked on user Firebase / ASC)

> While P0 **distribution** legs wait on user plist + ASC, idle agents run **15-min brainstorm_assist** — ingest **APPROVED** assists only; PM queues retasks; never auto-spawn from draft brainstorms.

| Agent | Specialty | Brainstorm topic (when Firebase/ASC blocked) | Advisor | Status |
|-------|-----------|-----------------------------------------------|---------|--------|
| 1 | `ios_ship` | Pre-stage `./scripts/fetch-firebase-ios-plist.sh` verify script; run `build-nexus-ios.sh` + sim xcodebuild so plist drop is one-command export | **APPROVED** | **idle assist** — spawn `support_build_verify` |
| 2 | `gameplay_tester` | Document generative test gaps (`nexus_generative_test`); flag modes with shallow sim depth vs UX bar | **APPROVED** | **in flight** (`sprint-dge-gameplay-unison`) |
| 3 | `debugging` | Document `nexus_renderer_test` parallel flake (`import pbr channels` 0.02s); recommend sequential gate after validate | **APPROVED** | **queued** (`sprint-dge-engine-gate`) |
| 4 | `registry` | Grep `kProductionModeIds` vs `nexus_validate_production_modes.sh` after 18/18 promotion; list any alias drift | **APPROVED** | **queued** |
| 5 | `renderer` | Sim Metal visual proof — screenshot template for Dunk auto-Metal; draft Instruments 60 FPS capture checklist for device session | **APPROVED** | **idle assist** (device blocked) |
| 6 | `assets` | `NEXUS_RESOURCE_ROOT` device checklist — manifest resolution steps for post-unlock `devicectl launch` | **APPROVED** | **idle assist** (device blocked) |
| 7 | `backend` | Trace preview-lane queue drain without POST; document `NexusBackendClient.postSessionReceipt` contract for prod plist handoff | **APPROVED** | **idle assist** (plist blocked) |
| 8 | `vision_guardian` | Grep Release-path `UnrealManager`/`UnityManager`; audit docs for V-003 **FIXED** overclaims from preview export | **APPROVED** | **queued** |
| 9 | `docs` | Sync delivery matrix DoD row to honest **5/9**; cross-ref `NEXUS_FIREBASE_APP_DISTRIBUTION_CLIPBOARD.md` for ad-hoc workaround | **APPROVED** | **queued** |
| — | `error_editor` | Audit bridge headers touched in Metal/Firebase sprint for on-call symbol risk | **APPROVED** | **on-call** |
| — | `support_build_verify` | `[support]` Production `--dry-run` when plist lands; parallel gate evidence for gameplay unison | **APPROVED** | **spawn on plist drop** |
| — | `support_docs_drift` | Ingest DGE sprint handoffs → fleet rows; honest V-003 labels | **APPROVED** | **spawn on handoff flood** |

**Prior sprint brainstorm (ingested):** [`docs/NEXUS_SPRINT_HURDLE_BRAINSTORM.md`](./NEXUS_SPRINT_HURDLE_BRAINSTORM.md) — Firebase · ASC · device · LLM · Metal · mirror.

---

## Recommended retasks (DGE sprint queue)

Ranked by PM after Advisor pass:

1. **[P0] `ios_ship` `sprint-dge-dist-ios`** — On user plist drop: `./scripts/fetch-firebase-ios-plist.sh` verify → `./scripts/archive-ios-testflight.sh --export` (no preview) → ASC Transporter prep.
2. **[P1] `gameplay_tester` `sprint-dge-gameplay-unison`** — Refresh `gameplay_handoff.json` + `docs/NEXUS_SIMULATOR_PRODUCT_TEST.md`; pair with `quality_check` unison loop.
3. **[P1] `ios_ship` + `renderer` + `assets`** — User unlocks iPhone → `devicectl launch` `NEXUS_USE_METAL=1` → Venice mesh screenshot (`sprint-dge-engine-metal`, `sprint-dge-engine-bundle`).
4. **[P1] `vision_guardian` `sprint-dge-vision-audit`** — Legacy grep + drift delta; do **not** mark V-003 FIXED without production export evidence.
5. **[P1] `debugging` `sprint-dge-engine-gate`** — Gate watchdog; attach parallel flake note from `support_gate_handoff.json`.
6. **[P2] `backend` `sprint-dge-dist-receipt`** — Device POST 2xx proof with real plist; verify pending queue drain.
7. **[P2] `renderer` `sprint-dge-engine-metal`** — Instruments 60 FPS capture on physical iPhone after unlock.
8. **[P2] `docs` `sprint-dge-dist-matrix`** — Delivery matrix DoD **5/9** honest sync; FAD clipboard cross-ref.
9. **[P2] `registry` `sprint-dge-registry-guard`** — Post-promotion registry skew guard.
10. **[P3] `docs` `sprint-docs-v016-mirror`** — Mirror rork doc port on PM order only (V-016).

**User actions (parallel):** Firebase plist (V-003); ASC app create; unlock iPhone for Metal + bundle runtime QA.

---

## Support agents (`[support]` tag)

| Convention | Rule |
|------------|------|
| **Task column** | Prefix **`[support]`** |
| **Ownership** | Primary `task_id` row stays owner |
| **Spawn when** | Primary needs PASS/FAIL evidence without scope steal |

| Specialty | Task | `task_id` | Assists |
|-----------|------|-----------|---------|
| `support_build_verify` | `[support]` Production archive dry-run when plist lands | `support-verify-v003-prod` | `sprint-dge-dist-ios` |
| `support_build_verify` | `[support]` DGE gate re-run after gameplay edit | `support-verify-dge-gate` | `sprint-dge-engine-gate` |
| `support_docs_drift` | `[support]` Ingest DGE handoffs → fleet rows | `support-fleet-dge-ingest` | `sprint-pm-dge` |
| `support_build_verify` | `[support]` Sim FR gate + validate 18/18 | `support-gate-fr` | `sim-fr-lead` |
| `quality_check` | `[quality-fr-unison]` Independent gate confirm | `quality-fr-unison` | `sprint-dge-gameplay-unison` |

---

## Maintenance notes

- **PM** updates this file on every subagent completion using handoff format in `NEXUS_AGENT_ORCHESTRATION.md`.
- **Final sprint closed (partial):** preview ship lane evidenced; production/TestFlight legs remain user-gated.
- **DGE sprint open:** parallel gameplay + engine work while distribution blocked on user Firebase/ASC.
- **Completed** section: rolling window of **10** entries.
- Coordinator replies must end with **`## Agents working`**.
