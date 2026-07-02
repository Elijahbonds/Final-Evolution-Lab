# NEXUS Sprint Hurdle Brainstorm

**Date:** 2026-06-19  
**Repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Authors:** `support_docs_drift` + Senior Advisor (PM ingest)  
**Purpose:** Bounded brainstorm handoffs for every **open** sprint hurdle. PM ingests **APPROVED** assists into `docs/NEXUS_AGENT_FLEET_STATUS.md` → **Recommended retasks**. **VETO** items must not spawn without scope change.

**Authority:** `docs/NEXUS_AGENT_ORCHESTRATION.md` (Idle agent brainstorm), `docs/NEXUS_VISION_ALIGNMENT.md`, `NEXUS_DELIVERY_MATRIX.md`

---

## Hurdle matrix (open)

| Hurdle | Drift / ref | Pri | Status | Owner specialty | User action? |
|--------|-------------|:---:|--------|-----------------|:------------:|
| **Firebase** | V-003 | P0 | **PARTIAL** — preview archive path live | `ios_ship` | Yes — real `GoogleService-Info.plist` |
| **ASC** | V-003 (upload leg) | P0 | **BLOCKED** — no app record | `ios_ship` | Yes — create ASC app for `com.finalevolutionlab.app` |
| **Device lock** | Delivery matrix #3 | P1 | **OPEN** — install OK; launch blocked | `ios_ship`, `assets` | Yes — unlock iPhone for `devicectl launch` |
| **LLM** | Generator + agent chat | P2 | **OPEN** — template/stub default | `backend`, `docs` | Optional — `NEXUS_AGENT_GEMINI_KEY` |
| **Metal** | V-013 | P2 | **OPEN** — SceneKit default on device | `renderer`, `ios_ship` | Yes — device + Instruments |
| **Mirror rork** | V-016 | P3 | **OPEN** — mirror lags canonical | `docs` | No — PM-ordered port only |

---

## Brainstorm handoff — Firebase (V-003)

- Specialty: `support_docs_drift` + Senior Advisor
- Observed gap: V-003 remains **OPEN** for production ship; `--preview-firebase` workaround ships signed IPA with honest offline banner but does not close drift. Dry-run or preview archive must not be labeled FIXED.
- Proposed assist:
  - **APPROVED:** Document dual-lane checklist in `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` (already present); queue `ios_ship` to run `./scripts/fetch-firebase-ios-plist.sh` after user drops plist; re-run `./scripts/archive-ios-testflight.sh --export` **without** `--preview-firebase`; capture archive path in delivery matrix.
  - **APPROVED:** Keep `FirebaseBootstrap.isPreviewMode` + `PREVIEW · FIREBASE OFFLINE` banner until real plist verified.
  - **APPROVED:** `support_build_verify` parallel PASS on `--dry-run` (real plist) when file lands.
- Pairs with: `ios_ship` (P0), `support_build_verify`
- Priority: **P0**
- Advisor check: **APPROVED**
- Evidence needed: Real `GoogleService-Info.plist` on disk (`BUNDLE_ID=com.finalevolutionlab.app`, no `REPLACE_ME`); `./scripts/archive-ios-testflight.sh --export` exit 0; Crashlytics upload succeeds or is intentionally skipped with doc note.

### VETO items (Firebase)

| VETO | Reason |
|------|--------|
| Mark V-003 **FIXED** from `--preview-firebase` or `--dry-run` only | Violates honest ship bar — no live Auth/Firestore/Crashlytics |
| Commit `GoogleService-Info.plist` to git | Secrets policy — file is gitignored |
| Ship TestFlight claiming “Firebase live” with placeholder plist | Vision honesty — preview banner required |

---

## Brainstorm handoff — ASC (App Store Connect)

- Specialty: `support_docs_drift` + Senior Advisor
- Observed gap: Signed App Store IPA exports (`--export`, `destination=export`) **PASS**; Transporter / Organizer upload **BLOCKED** — `missingApp(bundleId: com.finalevolutionlab.app)`. Export fix (upload→export) is in tree; ASC app record is separate user gate.
- Proposed assist:
  - **APPROVED:** User creates ASC app (steps in `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` § USER ACTION).
  - **APPROVED:** Until ASC exists, use `--export-adhoc` → Firebase App Distribution / registered-device sideload (no ASC record required).
  - **APPROVED:** After ASC create, `ios_ship` uploads `build/FEL-export/FinalEvolutionLab.ipa` via Transporter; optional `fastlane ios testflight` with API key.
  - **APPROVED:** `support_docs_drift` keeps delivery matrix row honest: export PASS ≠ TestFlight live.
- Pairs with: `ios_ship` (P0), user (ASC create)
- Priority: **P0** (upload leg of V-003)
- Advisor check: **APPROVED**
- Evidence needed: ASC app visible for `com.finalevolutionlab.app`; Transporter deliver success; build appears in TestFlight → Internal Testing.

### VETO items (ASC)

| VETO | Reason |
|------|--------|
| Claim TestFlight **complete** after export-only PASS | Upload requires ASC app record |
| AltStore / OTA sideload as **production** distribution | `infra/SHIPPING.md` — App Store Connect / TestFlight only for retail |
| Revert `ExportOptions.testflight.plist` to `destination=upload` as default | Breaks export without ASC; use export + Transporter |

---

## Brainstorm handoff — Device lock (runtime proof)

- Specialty: `support_docs_drift` + `assets` brainstorm
- Observed gap: Device bundle proof **PASS (partial)** — `devicectl install` SUCCESS; **28** `.nexusmesh.json` in `.app`; Venice/Luma sidecars present. **OPEN:** `devicectl launch` failed with `device locked`; Metal venue draw on physical iPhone untested (`NEXUS_USE_METAL=1`).
- Proposed assist:
  - **APPROVED:** User unlocks iPhone → `ios_ship` runs `./scripts/smoke-ios-device.sh` or documented `devicectl launch` with env `NEXUS_USE_METAL=1`.
  - **APPROVED:** Capture screenshot or syslog excerpt of Venice mesh draw (SceneKit or Metal) on device.
  - **APPROVED:** Document unlock prerequisite in `FinalEvolutionLab/IOS_RUNBOOK.md` (already notes `device locked`).
  - **APPROVED:** `assets` verifies `NEXUS_RESOURCE_ROOT` resolves manifest on device after launch.
- Pairs with: `ios_ship`, `assets`, `renderer`
- Priority: **P1**
- Advisor check: **APPROVED**
- Evidence needed: `devicectl launch` exit 0 on unlocked device; optional photo of dunk/venue viewport; delivery matrix #3 runtime row → PASS.

### VETO items (Device lock)

| VETO | Reason |
|------|--------|
| Mark delivery matrix #3 **FIXED** from install-only proof | Runtime mesh draw still open |
| Bypass passcode via automation | User must unlock — no credential harvesting |
| Claim 60 FPS from sim-only build | V-013 requires physical Instruments |

---

## Brainstorm handoff — LLM (agent + generator)

- Specialty: `support_docs_drift` + Senior Advisor
- Observed gap: `NEXUSAgentLLMClient` defaults to **localStub**; Gemini requires `NEXUS_AGENT_GEMINI_KEY` / `GEMINI_API_KEY`. `game_prompt_adapter.cpp` + `NexusGameGeneratorView` use **template MVP** (keyword → registry), not Seele-class synthesis. Docs (`NEXUS_GAME_GENERATOR.md`, `NEXUS_TEXT_TO_GENERATION.md`) already state honest PREVIEW tier.
- Proposed assist:
  - **APPROVED:** Keep `FELPreviewLabel` on `NexusAgentChatView` (`PREVIEW`, `PREVIEW · TOOL CHIPS`) and `NexusGameGeneratorView` (`PREVIEW · NEXUS GAME GENERATOR`).
  - **APPROVED:** `docs` ensures `NEXUS_AGENT_TOOLS.md` § LLM backends lists stub default + optional Gemini env keys.
  - **APPROVED:** Optional P2: user adds Gemini key to Xcode scheme → `support_build_verify` smoke `NEXUSAgentCoordinator` tool-chip path (no ship claim).
  - **APPROVED:** Creative terrain remains `fel.creative.*` + template parser until receipt POST + Metal gate progress (Sprint A/B in `FEL_NEXUS_Premium_Vision.md`).
- Pairs with: `docs`, `backend` (future receipt UX), `gameplay_tester` (creative command sims)
- Priority: **P2**
- Advisor check: **APPROVED** (assist/doc only); **VETO** on claiming full LLM ship
- Evidence needed: For any “Gemini live” claim: successful tool-call round-trip log with key set; for generator: `nexus_validate` on generated mode spec JSON.

### VETO items (LLM)

| VETO | Reason |
|------|--------|
| Market “Seele AI” / full asset synthesis ship with template parser only | Vision honesty — template MVP is PREVIEW |
| Remove local stub fallback | Offline dev + CI must work without API keys |
| Route creative terrain to UE/Unity generators | NEXUS-only mandate |

---

## Brainstorm handoff — Metal (V-013)

- Specialty: `renderer` + `support_docs_drift`
- Observed gap: Phase 8 **PARTIAL** — `NexusMetalBridge` + manifest load compile; SceneKit default in `GameSceneHostView`; `NEXUS_USE_METAL=1` env path exists but no Instruments 60 FPS proof on device. Bloom/shadow passes stubbed with honest PREVIEW labels in architecture docs.
- Proposed assist:
  - **APPROVED:** Sim compile verification: `xcodebuild` + link `NexusMetalBridge.mm` (already PASS per delivery matrix).
  - **APPROVED:** Device session checklist: unlock phone → launch with `NEXUS_USE_METAL=1` → Instruments GPU frame time on Venice dunk.
  - **APPROVED:** `renderer` documents PBR/post deferral; do not claim parity with Vulkan desktop.
  - **APPROVED:** `support_build_verify` re-run `./scripts/build-nexus-ios.sh` after Metal bridge edits.
- Pairs with: `renderer`, `ios_ship`, device-lock hurdle (unlock prerequisite)
- Priority: **P2**
- Advisor check: **APPROVED**
- Evidence needed: Instruments trace showing frame time on physical iPhone; screenshot of Metal viewport (not SceneKit-only) for P0 dunk mode.

### VETO items (Metal)

| VETO | Reason |
|------|--------|
| Mark V-013 **FIXED** from sim compile only | Device + FPS proof required |
| Retire SceneKit before Metal device draw proven | SceneKit is approved fallback preview path |
| UE 5.7 renderer as production Metal substitute | NEXUS-only — UE archived |

---

## Brainstorm handoff — Mirror rork repo (V-016)

- Specialty: `support_docs_drift` + Senior Advisor
- Observed gap: Canonical repo (`~/Final-Evolution-Lab`) holds NEXUS-only pivot, orchestration, fleet status, vision alignment. Mirror (`~/Documents/rork-final-evolution-lab`) is legacy reference + web/backend Cloud Agent VM — may still show UE-first `AGENTS.md` / stale Swift until explicit port.
- Proposed assist:
  - **APPROVED:** P3 doc-only port batch when PM orders: `NEXUS_ONLY_PIVOT.md`, `SHIPPING_ARCHITECTURE.md` header, `AGENTS.md` NEXUS-first block, `docs/NEXUS_AGENT_ORCHESTRATION.md`, `docs/NEXUS_VISION_ALIGNMENT.md` summary — **no** engine/Swift logic copy without `ios_ship` review.
  - **APPROVED:** Mirror `README.md` banner: “Reference mirror — ship from `~/Final-Evolution-Lab`.”
  - **APPROVED:** Track lag in V-016 row; close when grep shows NEXUS-first entry points in mirror.
- Pairs with: `docs`, `project_manager`
- Priority: **P3**
- Advisor check: **APPROVED** (doc port plan only)
- Evidence needed: `diff` or grep proof that mirror `AGENTS.md`/`README.md` match canonical NEXUS-first intro; no claim that mirror is production ship root.

### VETO items (Mirror V-016)

| VETO | Reason |
|------|--------|
| Edit mirror **only** for ship fixes without canonical port | V-016 — canonical path required |
| Treat mirror as TestFlight / archive source | Production builds only from `/Users/elijahbonds/Final-Evolution-Lab` |
| Bulk-copy canonical `FinalEvolutionLab/` Swift into mirror without review | Risk of divergent bridges; doc sync first |

---

## Senior Advisor summary

| Hurdle | Workaround (APPROVED) | Close condition |
|--------|----------------------|-----------------|
| Firebase | `--preview-firebase` internal IPA + offline banner | Real plist + production archive |
| ASC | `--export-adhoc` until ASC app exists | Transporter upload success |
| Device lock | Install proof done; user unlocks for launch | `devicectl launch` + venue draw evidence |
| LLM | Stub + template MVP + honest PREVIEW labels | Optional Gemini key smoke; no fake Seele claims |
| Metal | SceneKit default; `NEXUS_USE_METAL=1` for device test | Instruments 60 FPS on iPhone |
| Mirror V-016 | Doc-only port on PM order | Mirror entry points NEXUS-first |

**Global VETO (all hurdles):** UE/Unity production ship · TestFlight complete from dry-run · drift FIXED without cited evidence · mirror-only ship edits.

---

*PM: ingest APPROVED rows into `docs/NEXUS_AGENT_FLEET_STATUS.md` § Idle / brainstorming → **Recommended retasks**. Re-run this doc when any hurdle closes or new OPEN drift appears.*
