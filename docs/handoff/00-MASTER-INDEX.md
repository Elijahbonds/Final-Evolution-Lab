# FINAL EVOLUTION — MASTER INDEX (Agent Handoff Package)

**Package version:** 1.0 · July 2026
**Read order for any new agent:** 00 → 01 → 02 → 03 → 04 (Kimi) or 07 (pipeline) → 05 → 06
**Canonical product:** the Abacus-hosted web app (`finalevolution.abacusai.app`, custom
domain later). Everything else in this repo is source material, reference, or legacy.

---

## 1. The documentation suite (docs/handoff/)

| Doc | Purpose |
|-----|---------|
| `00-MASTER-INDEX.md` | This file. Repo map + what's canonical vs. legacy. |
| `01-PRODUCT-VISION.md` | Rescoped vision: digital coaching/fitness + avatar game library with a console-emulator feel. |
| `02-CURRENT-STATE.md` | Exactly where the live Abacus build is today (from hands-on playtest). |
| `03-CONSOLE-SHELL-SPEC.md` | The emulator shell: console home UI + universal controller (dual sticks/triggers/d-pad + touch). |
| `04-KIMI-BRIEF.md` | Working instructions for Kimi: role, deliverable format, conventions. |
| `05-BUILD-BACKLOG.md` | Ordered epics with acceptance criteria, from M13 P0s to the coaching layer. |
| `06-DATA-CONTRACTS.md` | Schemas: player economy (PRQ/XP/LC/shards), mode config, input events, session results. |
| `07-AGENT-PIPELINE.md` | The multi-agent workflow: Abacus ↔ Kimi ↔ Claude handoff protocol. |

**Companion batch:** `docs/abacus-batches/m13/` (9 docs) — the current fix milestone for
the live build, written as drag-and-drop tickets. Doc 05 sequences them.

## 2. Repository map — what lives where

### ACTIVE — feeds the canonical web product
| Path | What it is | Use |
|------|-----------|-----|
| `docs/handoff/` | This package | Source of truth for vision, specs, workflow |
| `docs/abacus-batches/m13/` | Live-build fix tickets | Current milestone for Abacus/Kimi |
| `backend/` | FastAPI service: `server.py`, routers (games, matches, biofuel, sovereign, education_tracks, pass_image, system_scan), `FEL_ModeManager.production.json`, `FEL_VenueRegistry.production.json` | Game/venue registry + PRQ/economy logic reference; the JSON registries are the authoritative mode/venue catalog |
| `NEXUS_TEAM/` | `PROJECT_PLAN.md`, `WORK_BREAKDOWN.md`, `STANDARDS.md`, `AGENT_ROSTER.md`, `NEXUS_ASSET_MANIFEST.md`, `STATUS.md` | Team/process standards + asset manifest |
| `memory/PRD.md` | Product requirements doc | Historical intent; superseded where it conflicts with 01 |
| `design_guidelines.json` | Visual design tokens/guidelines | Style reference for shell UI |

### REFERENCE — mine for logic, art direction, and specs (do not extend)
| Path | What it is | Why it matters |
|------|-----------|----------------|
| `FinalEvolutionLab/` (+ `.xcodeproj`, `Tests`, `UITests`) | Native iOS SwiftUI app: 20+ game-mode views (`Views/`), engines/models (`Models/`, e.g. `DunkContestEngine`, `ArcadePhysics`, `CreatorCard`), services (NexusEngine, UnityManager), SceneKit Venice scene (`CourtSceneView`) | The richest source of gameplay logic: dunk phases/trick slots, karate combat, 3v3 plays, momentum/clutch systems. Port MECHANICS from here into web modes. |
| `frontend/` | CRA React app (craco + tailwind): `NexusConsole.js`, `GameView.js`, `FELOSDashboard.js`, `BioFuel.js`, etc. | Earlier web console prototype; UI ideas only. NOT the live Abacus codebase. |
| `UnityProjectTemplate/` | Unity C# bridge scripts + iOS plugin stub | Legacy engine path |
| `UnrealIntegration/`, `UnrealStarter/`, `NexusStarter/` | UE5 basketball starter + integration configs | Legacy engine path |
| `superapp-reference/` | Product one-pager, distribution, integration notes | Background |
| `infra/` | Firebase distribution, UE5 configs, audits (`claude_nexus_gameplay_audit.json`) | Ops/deploy reference for iOS path |
| `dataconnect/`, `firebase.json`, `firestore.rules`, `database.rules.json` | Firebase config | iOS/backend infra |
| `SEELE_AI_EXECUTION_PACKAGE.md`, `PLAN.md`, `AGENTS.md`, `auth_testing.md`, `test_result.md`, `backend_test.py`, `tests/` | Prior agent packages + test artifacts | Historical |
| `fel_ue5_*.sh`, `prepare_fel_*.sh`, `fastlane/`, `Gemfile*` | Build/packaging scripts (UE5/iOS) | Legacy pipelines |

### RULES OF THE ROAD
- **Never commit secrets.** `GoogleService-Info.plist` is gitignored; `MONGO_URL`,
  `DB_NAME`, `EMERGENT_LLM_KEY`, `PAYPAL_*`, Firebase service-account values must never
  appear in code, docs, or outputs. Backend tests run offline with `MOCK_DB=1`.
- **IP constraint (Who Scene It):** no real movie clips, posters, or celebrity likeness;
  content stays swappable via its content module. Original assets only.
- The live Abacus app's source is NOT in this repo. Agents ship changes to it as
  document batches (see 07), which Abacus's builder applies.

## 3. External surfaces
| Surface | Where | Status |
|---------|-------|--------|
| **Web app (canonical)** | finalevolution.abacusai.app / nexusllm.abacusai.app (same build); custom domain planned | Live: 22 modes, hub, season pass. See 02. |
| iOS app | This repo (`FinalEvolutionLab/`) | Reference/companion; not the current focus |
| Backend API | `backend/` (FastAPI) | Registry + economy source of truth |
| GitHub | `Elijahbonds/Final-Evolution-Lab`, work branch `claude/nexus-engine-setup-2qgkik` | All batches & docs pushed here |
