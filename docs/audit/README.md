# FEL Audit Documentation

Automated and manual readiness checks for the Final Evolution Lab product stack.

## Latest audit

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

# NEXUS headless unit tests (no GPU)
cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF
cmake --build build-headless && ctest --test-dir build-headless --output-on-failure

# Production preflight (Firebase, Data Connect, UE embed)
./scripts/verify_production_readiness.sh
```

## Layer status (2026-06-19)

| Layer | Status | Notes |
|-------|--------|-------|
| iOS shell (`FinalEvolutionLab/`) | Beta-ready | Tab bar, onboarding, 19 game modes |
| App gameplay (`app/gameplay/`) | Complete | `nexus_gameplay` + unit tests green |
| Gameplay docs (`docs/gameplay_logic/`) | Restored | Integration manual + protocol specs |
| NEXUS headless | Passing | `nexus_protocol_test`, `nexus_gameplay_test` |
| NEXUS runtime (Vulkan) | Failing | SIGSEGV on launch — see audit |
| UE / Pixel Streaming | Not in scope | Separate capture runbook required |

## Open gaps

1. **NEXUS GPU runtime** — debug Vulkan/MoltenVK init crash before windowed audit.
2. **SceneKit harness** — black viewports on some modes (dunk, penalty); timing/scene init.
3. **Mode 19 screenshot** — re-run export after `expectedModeCount` fix for `market_browse`.
4. **Live biometric bridge** — `fel.fitness.*` wired in C++; iOS→NEXUS transport not validated in audit pass.

## Related docs

- [Gameplay Integration Manual](../gameplay_logic/IntegrationManual.md)
- [Gameplay receipt contract](../../infra/GAMEPLAY_RECEIPT_CONTRACT.md)
