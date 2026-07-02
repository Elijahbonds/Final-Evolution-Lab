# FEL App — Premium Quality Rubric

> Owner: iOS bridge agent · Spec: `FEL_NEXUS_Cursor_Spec_v1.pdf` §2, §7, §9.1  
> Coordinator score (2026-06-19): **61 / 100**

## Scoring model (100 pts)

| Dimension | Weight | Score | Evidence |
|-----------|--------|-------|----------|
| **Launch → play flow** | 15 | 11 | Arena → mode → `GamePlayView`; P0/P1 featured; onboarding skip on sim |
| **P0 Dunk Contest UX** | 20 | 14 | Touch → NEXUS bridge closed (DoD #3); SceneKit venue still preview |
| **P1 Karate Endless UX** | 15 | 11 | C++ combat wired; HUD poll for wave/HP; polish pending |
| **HUD coherence** | 15 | 10 | Swift overlay is SoT for P0/P1; legacy SceneKit sim + biomechanics HUD can overlap |
| **Receipt premium flow** | 15 | 6 | Disk queue + `SessionReceiptUploadService`; no success animation; live POST partial |
| **Visual brand unity** | 10 | 7 | `Theme.swift` consistent; `GameSceneFactory` duplicates UIColor literals |
| **Ship readiness** | 10 | 2 | TestFlight not archived; Metal venue embed deferred |

**Total: 61 / 100**

## World-class bar (90+)

- **Scan-to-play:** MRI / exercise scan → PRQ gate → arena entry in ≤3 taps with branded transition.
- Session end shows **verified receipt celebration** (animation + PRQ delta) before returning to Arena.
- Single HUD layer: NEXUS poll drives score/combo; dev stats never paint over SwiftUI chrome.
- Venice arenas feel identical between engine Metal viewport and marketing renders (palette + lighting).

## Verification commands

```bash
cd FinalEvolutionLab && xcodebuild -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
./scripts/smoke_v1.sh --skip-build
# Manual: dunk touch loop, session end, ls ~/.fel/pending_receipts/
```

## Open gaps (priority)

1. Replace SceneKit P0 venue with Metal embed + mobile mesh profile.
2. Receipt upload success UX (`GameplaySessionReceiptCoordinator` → celebratory overlay).
3. Consolidate HUD: disable duplicate score sources for NEXUS-linked modes.
4. Centralize palette — import engine clear color from shared token doc.
5. TestFlight archive + device QA (DoD #9).
