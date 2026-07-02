# Final Evolution Lab (NEXUS)

**Production retail ship is NEXUS only** — custom C++20 engine + Swift iOS athlete OS. See **`NEXUS_ONLY_PIVOT.md`** and **`SHIPPING_ARCHITECTURE.md`**.

This monorepo also contains web marketing sites, Supabase backend, and **archived** Unreal Engine 5.7 / Unity 6 reference trees (not used for App Store ship).

## iOS app (product UI)

Open **`FinalEvolutionLab.xcodeproj`**, select scheme **FinalEvolutionLab**, pick your iPhone or Simulator, and **Run** (⌘R).

Build NEXUS static libs first on macOS:

```bash
./scripts/build-nexus-ios.sh
```

**Normal launch shows:**

1. **First launch on a physical device** — full-screen onboarding (sport → age → goal). Tap through all three steps; **START EVOLUTION** opens the main shell.
2. **After onboarding (or on Simulator)** — five-tab menu: **Lab**, **Train**, **Arena**, **Status**, **Profile**.

Arena gameplay uses **NEXUS SceneKit preview** by default (`NEXUS_USE_METAL=1` for the partial Metal venue-mesh embed). UI surfaces not yet at production bar show **PREVIEW · NEXUS** badges.

Do **not** add `-ScreenshotHarness` under **Edit Scheme → Run → Arguments Passed On Launch** for everyday use. That dev-only flag skips the tab shell and opens the PR screenshot harness (Arena grid / raw gameplay chrome).

## NEXUS dev runtime (not the iOS app)

`build-full/nexus_runtime` is a **macOS Vulkan/SDL 3D arena preview** (orbit camera + cube field). It is **not** the shipping iPhone app. A blue or blank window there does not mean the iOS menu is broken.

For the product experience, run **FinalEvolutionLab** from Xcode on device or Simulator.

## AI (Google AI Studio — primary)

Game generator, agent chat, and NEXUS Studio use **Google AI Studio / Gemini REST**. **Firebase is not required** for builder or game generation.

1. Create an API key at https://aistudio.google.com/apikey  
2. Set `NEXUS_AI_STUDIO_API_KEY` in the Xcode scheme **or** store in Keychain via NEXUS Studio settings  
3. Without a key, the app falls back to **18-mode template MVP** (fully offline)

Full setup: **`docs/NEXUS_AI_STUDIO_SETUP.md`**

## Canonical commands

```bash
./scripts/nexus_build_gate.sh
./scripts/build-nexus-ios.sh
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 ./scripts/archive-ios-testflight.sh --dry-run
```

**Archive / export:** ensure **≥ 15 GB free disk** before `./scripts/archive-ios-testflight.sh --export*`. Firebase plist is **optional** for ad-hoc internal QA (`--preview-firebase --export-adhoc`); see `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`.

See `runtime/src/main.cpp` (stderr banner on launch), `NEXUS_RESUME.md`, and `infra/GAME_MODE_SCREENSHOT_RUNBOOK.md` for harness details.
