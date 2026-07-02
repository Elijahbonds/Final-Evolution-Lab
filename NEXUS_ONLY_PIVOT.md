# NEXUS-only production pivot

**Decision date:** 2026-06-19  
**Status:** Authoritative — supersedes prior UE 5.7 retail-ship claims in older docs.

## Decision

**Production retail ship is NEXUS only:**

- **Engine:** Custom C++20 NEXUS engine (`engine/`, `app/gameplay/`, `runtime/`)
- **Client:** Swift iOS app (`FinalEvolutionLab/`) with static-lib embed via `scripts/build-nexus-ios.sh`
- **Distribution:** App Store Connect / TestFlight — see `infra/SHIPPING.md`

Unreal Engine 5.7 and Unity 6 are **no longer used for shipping**. Their code and docs remain in-repo as **archived/legacy reference** — do not delete, do not extend for retail.

## Canonical repo

| Role | Path |
|------|------|
| **Primary (NEXUS ship)** | `~/Final-Evolution-Lab` (this repo) |
| **Legacy FEL/UE reference** | `~/Documents/rork-final-evolution-lab` |

## What is deprecated (not deleted)

| Path / artifact | Former role | Status |
|-----------------|-------------|--------|
| `UnrealIntegration/`, `UnrealStarter/` | UE 5.7 gameplay host | Archived |
| `fel_ue5_ios_shipping_package.sh` | UE iOS cook/archive | Archived |
| `Unity6-FinalEvolution-Lab/` | Unity prototype | Archived |
| `~/Documents/rork-final-evolution-lab` | Prior monorepo + UE integration | Legacy reference mirror |

## Honest preview labeling

NEXUS is the ship target, but not every pillar is production-grade yet. Until gaps in **`NEXUS_DELIVERY_MATRIX.md`** close, label UI and marketing copy **preview/beta** where applicable:

- No signed `FEL.xcarchive` / TestFlight IPA on disk (Phase 8)
- Metal renderer is stub; iOS dunk still SceneKit preview path
- Session receipt live Firebase POST open (DoD #4)
- GPU shadow/bloom resolve passes deferred

See **`DELIVERY_BAR_FINAL_EVOLUTION.md`** for per-pillar acceptance criteria.

## Canonical build/run commands

```bash
cd ~/Final-Evolution-Lab

# Preflight — headless + full renderer gate
./scripts/nexus_build_gate.sh

# iOS static libs for Xcode embed
./scripts/build-nexus-ios.sh

# Archive preflight (dry-run)
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 ./scripts/archive-ios-testflight.sh --dry-run

# Real TestFlight archive + export (needs GoogleService-Info.plist + signing)
./scripts/archive-ios-testflight.sh
./scripts/archive-ios-testflight.sh --export

# Runtime smoke
./scripts/bench_nexus_runtime.sh
./scripts/smoke_v1.sh --skip-build
./scripts/smoke_gameplay_session.sh --skip-build
```

Full handoff: **`NEXUS_RESUME.md`**. Architecture lock: **`SHIPPING_ARCHITECTURE.md`**.

## Doc map (updated for pivot)

| Doc | Purpose |
|-----|---------|
| `SHIPPING_ARCHITECTURE.md` | Engineering lock — NEXUS canonical |
| `infra/SHIPPING.md` | iOS release steps |
| `DELIVERY_BAR_FINAL_EVOLUTION.md` | Product acceptance per pillar |
| `NEXUS_RESUME.md` | Build matrix + pass status |
| `NEXUS_DELIVERY_MATRIX.md` | Phase/gap audit with honest labeling |
