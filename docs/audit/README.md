# FEL Audit Documentation

Automated and manual readiness checks for the Final Evolution Lab product stack.

## Latest audit

**[GAME_COMPLETION_AUDIT.md](./GAME_COMPLETION_AUDIT.md)** — Mode matrix, asset status, GDD coverage, completion estimate, next 10 tasks.

**[READINESS_AUDIT_2026-06-19.md](./READINESS_AUDIT_2026-06-19.md)** — iOS screenshot harness, NEXUS headless tests, runtime GPU notes.

## Screenshot artifacts

| Path | Contents |
|------|----------|
| `screenshots/` | PNG captures from UITest harness and main app |
| `screenshots/manifest.json` | File inventory and capture metadata |

## Quick commands

```bash
# iOS mode screenshots (simulator)
./scripts/capture_game_mode_screenshots.sh

# Build + export + rename in one step
./scripts/export_audit_screenshots.sh

# NEXUS headless gameplay regression (no GPU)
CC=gcc CXX=g++ ./scripts/nexus_gameplay_regression.sh

# Registry consistency gates
python3 scripts/validate_mode_registry.py
python3 scripts/validate_ios_mode_registry.py

# Full renderer + production-mode gate (requires Vulkan + SDL3)
./scripts/nexus_build_gate.sh

# Production preflight (Firebase, Data Connect, NEXUS readiness)
./scripts/verify_production_readiness.sh
```

## Layer status (refreshed 2026-07-02)

| Layer | Status | Notes |
|-------|--------|-------|
| iOS shell (`FinalEvolutionLab/`) | Beta-ready | Tab bar, onboarding, 19 game modes; production Firebase/TestFlight actions still required |
| App gameplay (`app/gameplay/`) | Complete for headless production-mode contracts | `nexus_gameplay_regression.sh` exercises all 18 production runtime modes |
| Gameplay docs (`docs/gameplay_logic/`) | Restored | Integration manual + protocol specs |
| NEXUS headless | Passing | Full headless CTest matrix + gameplay regression gate |
| iOS NEXUS bridge | Linked | `NexusGameplayBridge`; simulator/device proof remains part of the iOS gate |
| NEXUS runtime (Vulkan) | Passing in validate-only gates; device visual proof partial | `nexus_build_gate.sh` is the canonical renderer gate; full Linux runs require Vulkan + SDL3 |
| UE / Pixel Streaming | Archived reference only | Not a NEXUS production ship dependency |

## Open gaps

1. **Production Firebase/TestFlight** — live `GoogleService-Info.plist`, ASC app record, production archive/export, and upload proof remain user/action dependent.
2. **Physical-device visual/performance proof** — Metal venue draw and 60 FPS mobile-mesh evidence still need iPhone + Instruments validation.
3. **Live receipt POST** — C++ receipt queue and Swift drain are wired; production authenticated 2xx proof remains open outside preview lane.
4. **Health/fitness bridge** — `fel.fitness.*` is wired in C++; live HealthKit/biometric transport needs device validation.
5. **Content depth** — all 18 production runtime modes are contract-tested; outcome-sport sim depth, character/prop mesh coverage, and premium visual polish remain product-quality gaps.

## Related docs

- [Gameplay Integration Manual](../gameplay_logic/IntegrationManual.md)
- [Gameplay receipt contract](../../infra/GAMEPLAY_RECEIPT_CONTRACT.md)
