#!/usr/bin/env python3
"""Emit AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md at repo root. Run from anywhere."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md"


def read_rel(p: str) -> str:
    return (ROOT / p).read_text(encoding="utf-8")


def block(path: str, lang: str, body: str) -> str:
    return f"File: `{path}`\n\n```{lang}\n{body.rstrip()}\n```\n\n"


def lines_range(path: str, start: int, end: int) -> str:
    """1-based inclusive line range."""
    lines = read_rel(path).splitlines(keepends=True)
    chunk = "".join(lines[start - 1 : end])
    return f"// excerpt: {path} lines {start}-{end} (total {len(lines)} lines)\n{chunk}"


def append_gold_master_sovereign_overlay(parts: list[str]) -> None:
    """TASK + PRODUCTION_CONFIG + web/Wix deploy + React path notice (prepend to bundle)."""
    prod = read_rel("PRODUCTION_CONFIG.md")
    parts.append(
        f"""# Gold Master Sovereign Bundle — AI Studio context dump

## TASK: FIX ERRORS & FINALIZE DEPLOYMENT

**Instructions for AI Studio**

1. **a)** If a separate **React** app exists (e.g. Wix/React), fix **syntax/type errors** there — this repo may not contain those files. In **this** repo, the native shell is **Swift** + **Unreal** + static **`web/`**; do not invent `App.tsx` unless pasted below.
2. **b)** **Medical disclaimer:** implement as **mandatory first-run gate** in **SwiftUI** (`ContentView` / onboarding) or **Wix**; there is **no** `App.tsx` in `final-evolution-lab`.
3. **c)** **Wix → Supabase:** complete **`post_felRelayWixOrder`** → **`wix-order-completed`** Edge Function; header **`X-FEL-Wix-Secret`**; body includes **`wix_order_id`**, **`supabase_user_id`**, **`shard_delta`**, optional **`athlete_id`**.

---

## PRODUCTION_CONFIG.md

{prod}

---

## Requested React paths — NOT IN THIS REPO

The following were requested for bundling but **do not exist** in `final-evolution-lab`:

- `App.tsx`
- `gameModes.ts`
- `GameModeRouter.tsx`

**Substitutes in-repo:** `web/config/vva-game-modes.ts` (VVA module registry), Swift `ContentView` + `AppTab` (`TabView`) for navigation.

---

## Web deployment + PWA + Wix relay

"""
    )
    for p, lang in [
        ("netlify.toml", "toml"),
        ("web/_headers", "http"),
        ("web/play/manifest.webmanifest", "json"),
        ("web/play/_headers", "http"),
        ("web/config/vva-game-modes.ts", "typescript"),
        ("wix/velo/backend/http-functions.js", "javascript"),
        ("supabase/functions/wix-order-completed/index.ts", "typescript"),
    ]:
        parts.append(block(p, lang, read_rel(p)))

    parts.append(
        """---

# Final Evolution Lab — AI Studio architecture bundle

**Purpose:** Paste into [Google AI Studio](https://aistudio.google.com/) (or similar) for **forensic architecture review**.  
**Repo:** `final-evolution-lab` · **iOS:** `Source/` · **Unreal templates:** `UnrealStarter/BasketballGame/` · **UE target:** 5.7 / MyProjec.

---
"""
    )


def main() -> None:
    parts: list[str] = []

    append_gold_master_sovereign_overlay(parts)

    parts.append(
        """
---

## Claims vs code (read first)

- **Implemented (iOS):** SwiftUI Lab + Arena flows; **RealityKit** dunk court; `DunkContestState` phases and scoring; **PRQ** / `PerformanceMetrics` in app logic; **system scan** UI with **simulated** analysis → `SystemScanResult` (not a full on-device CV pipeline in this bundle).
- **Implemented (Unreal templates):** JSON **readiness snapshot** → `FFELReadinessSnapshot`; **`ApplyReadiness`** on character (**`JumpZVelocity`**, **`MaxWalkSpeed`**) and ball (**mass scale**); hoop **trigger scoring**; **session export** JSON; **Python** editor scripts for **floor / PlayerStart / hoop volumes** and optional **Luma/prop spawn** (paths in script).
- **Curriculum vs metrics:** **Bonds Bounce** in Swift is **`BlueprintLibrary`** (content + phases + URLs), **not** a second numeric schema; alignment with Unreal is **narrative / product**, not a shared “BondsBounce” calculation type with `FELReadinessTypes`.
- **Neuro-Mechanic (Swift + Unreal templates):** `PRQManager` exports **`readiness_snapshot.json`** with `verticalEstimateInches`, `hangTimeScale`, `kineticLeakageMultiplier` (joint PRIMED vs MODERATE/LEAKING from `BiomechanicsAudit`). Unreal **`FELReadinessIO`** parses those keys; **`FELKineticLeakage`** scales jump/sprint in **`AFELBasketballCharacter::ApplyReadiness`**; **`AFELBasketballGameMode`** mirrors neuro floats for Blueprint. See **`NEURO_MECHANIC_BRIDGE.md`**.
- **Roadmap / not demonstrated in pasted C++:** **Neural Drive fatigue** over time (no stamina decay, no load-based damping beyond leakage multipliers); **braking / deceleration** curves from PRQ; **shot variance** as gameplay; **live iOS → Editor** bridge (snapshot remains file-based for QA unless you add IPC).
- **Roadmap / not in Python scripts:** **Golden hour** lighting, **post-process** “juice,” or Niagara/VFX — scripts **spawn/layout** actors only unless you extend them.
- **Large Swift files** in this bundle are **excerpts**; do not infer missing UI or helpers as “implemented” without opening the repo.

---

## System instruction (paste into AI Studio “System instructions”)

You are the **Neuro-Mechanic Lead Architect** for **Final Evolution Lab**. You are reviewing a **split codebase**:

- **iOS (`Source/`):** SwiftUI for **Arena** (UI-only rounds) and **Lab**; **RealityKit** for the **dunk** scene. Performance narrative uses **PRQ**, **readiness / scan** flows, and optional **Gemini** services — not Unreal UMG.
- **Unreal 5.7 (`MyProjec` / templates under `UnrealStarter/BasketballGame/`):** C++ gameplay slice — movement, ball, hoop triggers, HUD, **readiness snapshot → tuning**, **session export JSON**. Editor automation via **Python** in `UnrealStarter/EditorPython/`.
- **Neural Drive fatigue** is **not** in the pasted C++: do not assume decay-under-load or stamina APIs. Recommend **concrete** extensions (e.g. **Stamina** component, **Curve** assets, or time-scaled multipliers applied **after** `ApplyReadiness`) only as **design proposals**, not as existing code.

**Product concepts**

- **Bonds Bounce Blueprint:** vertical-jump **training architecture** (phases, progression, copy in `BlueprintLibrary`); align any jump/dunk **phase naming** (e.g. load, launch, flight, landing) with this story when commenting on code. Note: audit doc flags a **naming mismatch** vs spec (Load/Launch vs Foundations/Flight/Elite).
- **Forensic goals:** trace how **scan / metrics** flow into **in-game feel** (Swift dunk engine + Unreal `ApplyReadiness`-style tuning), identify gaps between **docs and implementation**, and propose **UE 5.7**-realistic next steps (C++, Blueprint hooks, Python batch tools) **without inventing APIs** not shown below.

When unsure, **quote file paths** and state assumptions explicitly.

---

## Consolidated sources

The following sections use the format:

`File: path/to/file`

```{language}
…
```

"""
    )

    # --- Markdown (full or summarized) ---
    parts.append("### Architecture & flows (Markdown)\n\n")
    parts.append(block("PROJECT_FLOWS.md", "markdown", read_rel("PROJECT_FLOWS.md")))
    parts.append(block("NEURO_MECHANIC_BRIDGE.md", "markdown", read_rel("NEURO_MECHANIC_BRIDGE.md")))
    parts.append(block("app-synopsis.md", "markdown", read_rel("app-synopsis.md")))
    parts.append(block("UnrealStarter/VISION_ALIGNMENT.md", "markdown", read_rel("UnrealStarter/VISION_ALIGNMENT.md")))

    audit = read_rel("AUDIT_BIOMECHANICAL_ECOSYSTEM.md")
    parts.append(
        block(
            "AUDIT_BIOMECHANICAL_ECOSYSTEM.md (§3 Bonds Bounce + surrounding Digital Vault)",
            "markdown",
            "\n".join(audit.splitlines()[0:120]) + "\n\n… [truncated after §3.2 header — full file in repo] …\n",
        )
    )

    pkg = read_rel("UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md")
    parts.append(
        block(
            "UnrealStarter/BasketballGame/PACKAGE_AND_TEST.md (§1–6, §9–11)",
            "markdown",
            "\n".join(pkg.splitlines()[0:149])
            + "\n\n… [§7–8 iOS/notarization omitted — see repo] …\n\n"
            + "\n".join(pkg.splitlines()[149:177]),
        )
    )

    # --- Swift: full smaller files ---
    swift_full = [
        "Source/Models/DunkContestEngine.swift",
        "Source/Views/RealityKitDunkView.swift",
        "Source/ViewModels/LabViewModel.swift",
        "Source/Services/PRQScoreManager.swift",
        "Source/Models/UserProfile.swift",
        "Source/Services/GeminiService.swift",
        "Source/Services/ExerciseNarrationService.swift",
        "Source/Models/BlueprintLibrary.swift",
        "Source/Models/BiomechanicsEducation.swift",
        "Source/Utilities/PRQScoring.swift",
        "Source/Models/GameMode.swift",
        "Source/PRQManager.swift",
        "Source/Services/FELSupabaseWalletSync.swift",
        "Source/Services/VenueManager.swift",
    ]
    parts.append("### Swift — full files (logic ≤ ~532 lines)\n\n")
    for p in swift_full:
        parts.append(block(p, "swift", read_rel(p)))

    # --- Swift: large views (excerpts) ---
    parts.append("### Swift — large views (excerpts per bundle spec)\n\n")

    parts.append(
        block(
            "Source/LabView.swift (excerpt A: properties, dunk cover, scan sheet)",
            "swift",
            lines_range("Source/LabView.swift", 1, 163),
        )
    )
    parts.append(
        block(
            "Source/LabView.swift (excerpt B: freestyle engine + handlers)",
            "swift",
            lines_range("Source/LabView.swift", 856, 1036),
        )
    )
    parts.append(
        block(
            "Source/LabView.swift (excerpt C: DunkFlowView + DunkFullScreenView)",
            "swift",
            lines_range("Source/LabView.swift", 1798, 2067),
        )
    )
    parts.append(
        "_Omitted from `LabView.swift`: header/metrics/court UI sections (~lines 164–855, 1037–1797, 2068–end) — layout and non-dunk Lab chrome._\n\n"
    )

    # SystemScanView: two ranges
    sys_lines = read_rel("Source/Views/SystemScanView.swift").splitlines()
    sys_a = "\n".join(sys_lines[0:180])
    sys_b = "\n".join(sys_lines[494:595])
    parts.append(
        block(
            "Source/Views/SystemScanView.swift (excerpt part 1)",
            "swift",
            sys_a + "\n\n// … pickingPhase / analyzingPhase / resultsPhase UI omitted …\n",
        )
    )
    parts.append(
        block(
            "Source/Views/SystemScanView.swift (excerpt part 2: startAnalysis + generateScanResult)",
            "swift",
            sys_b,
        )
    )
    parts.append(
        "_Omitted from `SystemScanView.swift`: `pickingPhase`, `analyzingPhase`, `resultsPhase` view builders (large SwiftUI layout)._\n\n"
    )

    parts.append(
        block(
            "Source/Views/ArenaView.swift (excerpt: ArenaView shell + ArenaGameFlowView + GenericArenaPlayView header + PRQ commit)",
            "swift",
            lines_range("Source/Views/ArenaView.swift", 1, 70)
            + "\n// … venueSection / modeRow / ArenaDunkInterstitialView …\n"
            + lines_range("Source/Views/ArenaView.swift", 295, 560)
            + "\n// … GenericArenaPlayView body (canvas, multipeer, sport branches) …\n"
            + lines_range("Source/Views/ArenaView.swift", 1125, 1168),
        )
    )
    parts.append(
        "_Omitted from `ArenaView.swift`: remainder of `GenericArenaPlayView` (scoreRound, finishGame, sport-specific branches), environment copy extensions._\n\n"
    )

    parts.append(
        block(
            "Source/Views/GameScreensView.swift (excerpt: GetReadyScreen + ResultScreen core)",
            "swift",
            lines_range("Source/Views/GameScreensView.swift", 1, 180)
            + "\n// … PreGameMovementSnackView, RoundTransitionScreen omitted …\n"
            + lines_range("Source/Views/GameScreensView.swift", 297, 523),
        )
    )
    parts.append(
        "_Omitted from `GameScreensView.swift`: `ResultScreen` private sections (`rewardsEarnedSection`, `prqBreakdownSection`), other views._\n\n"
    )

    # --- Unreal ---
    parts.append("### Unreal C++ / JSON (MyProjec templates)\n\n")
    unreal_files = [
        "UnrealStarter/BasketballGame/FELReadinessTypes.h",
        "UnrealStarter/BasketballGame/FELArenaDifficultyScaling.h",
        "UnrealStarter/BasketballGame/FELReadinessIO.h",
        "UnrealStarter/BasketballGame/FELReadinessIO.cpp",
        "UnrealStarter/BasketballGame/FELKineticLeakage.h",
        "UnrealStarter/BasketballGame/FELKineticLeakage.cpp",
        "UnrealStarter/BasketballGame/FELSessionExport.h",
        "UnrealStarter/BasketballGame/FELSessionExport.cpp",
        "UnrealStarter/BasketballGame/UFELAssetRegistrySubsystem.h",
        "UnrealStarter/BasketballGame/UFELAssetRegistrySubsystem.cpp",
        "UnrealStarter/BasketballGame/example_readiness_snapshot.json",
        "UnrealStarter/BasketballGame/FELBasketballCharacter.h",
        "UnrealStarter/BasketballGame/FELBasketballCharacter.cpp",
        "UnrealStarter/BasketballGame/FELBasketballGameMode.h",
        "UnrealStarter/BasketballGame/FELBasketballGameMode.cpp",
        "UnrealStarter/BasketballGame/FELHoopScoreVolume.h",
        "UnrealStarter/BasketballGame/FELHoopScoreVolume.cpp",
        "UnrealStarter/BasketballGame/FELArenaBridge.h",
        "UnrealStarter/BasketballGame/FELArenaBridge.cpp",
    ]
    for p in unreal_files:
        ext = Path(p).suffix
        lang = "cpp" if ext in (".h", ".cpp") else "json"
        parts.append(block(p, lang, read_rel(p)))

    parts.append(
        "### Unreal — UFELInputManager (Push 1,2 haptics) + Biometric overlays header\n\n"
    )
    for p in [
        "UnrealStarter/BasketballGame/UFELInputManager.h",
        "UnrealStarter/BasketballGame/UFELInputManager.cpp",
        "UnrealStarter/BasketballGame/UFELBiometricOverlays.h",
    ]:
        parts.append(block(p, "cpp", read_rel(p)))

    ball_cpp = read_rel("UnrealStarter/BasketballGame/FELBasketballActor.cpp")
    if "ApplyReadiness" in ball_cpp:
        idx = ball_cpp.index("void AFELBasketballActor::ApplyReadiness")
        snippet = ball_cpp[idx : ball_cpp.index("}", idx) + 1]
        parts.append(
            block(
                "UnrealStarter/BasketballGame/FELBasketballActor.cpp (excerpt: ApplyReadiness only)",
                "cpp",
                snippet,
            )
        )

    # --- Python ---
    parts.append("### Unreal Editor Python\n\n")
    for p, lang in [
        ("UnrealStarter/EditorPython/README.md", "markdown"),
        ("UnrealStarter/EditorPython/fel_setup_level.py", "python"),
        ("UnrealStarter/EditorPython/fel_quick_playtest_level.py", "python"),
    ]:
        parts.append(block(p, lang, read_rel(p)))

    parts.append(
        "\n---\n\n*End of **Gold Master Sovereign Bundle**. Regenerate with:* `python3 scripts/generate_ai_studio_bundle.py`\n"
    )

    OUT.write_text("".join(parts), encoding="utf-8")
    kb = OUT.stat().st_size // 1024
    print(f"Wrote {OUT} ({kb} KB)")
    print("Copy the file contents into AI Studio, or: cat AI_STUDIO_FEL_ARCHITECTURE_BUNDLE.md | pbcopy")


if __name__ == "__main__":
    main()