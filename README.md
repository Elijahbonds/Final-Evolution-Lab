# Final Evolution Lab

Sports-tech monorepo: iOS app, web marketing sites, Supabase backend, Unreal Engine 5.7 game, and NEXUS engine experiments.

## iOS app (product UI)

Open **`FinalEvolutionLab.xcodeproj`**, select scheme **FinalEvolutionLab**, pick your iPhone or Simulator, and **Run** (⌘R).

**Normal launch shows:**

1. **First launch on a physical device** — full-screen onboarding (sport → age → goal). Tap through all three steps; **START EVOLUTION** opens the main shell.
2. **After onboarding (or on Simulator)** — five-tab menu: **Lab**, **Train**, **Arena**, **Status**, **Profile**.

Do **not** add `-ScreenshotHarness` under **Edit Scheme → Run → Arguments Passed On Launch** for everyday use. That dev-only flag skips the tab shell and opens the PR screenshot harness (Arena grid / raw gameplay chrome).

## NEXUS dev runtime (not the iOS app)

`build-full/nexus_runtime` is a **macOS Vulkan/SDL 3D arena preview** (orbit camera + cube field). It is **not** the shipping iPhone app. A blue or blank window there does not mean the iOS menu is broken.

For the product experience, run **FinalEvolutionLab** from Xcode on device or Simulator.

See also `runtime/src/main.cpp` (stderr banner on launch) and `infra/GAME_MODE_SCREENSHOT_RUNBOOK.md` for screenshot harness details.
