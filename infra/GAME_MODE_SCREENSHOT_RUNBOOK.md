# Game mode & Arena screenshot runbook

You cannot capture Simulator PNGs from a headless cloud agent. Use **Simulator or device + Xcode** locally.

## Automated (recommended)

1. Open `FinalEvolutionLab.xcodeproj` in Xcode.
2. **Product → Scheme → FinalEvolutionLab** (app target tests include `FinalEvolutionLabUITests`).
3. Pick a simulator (e.g. iPhone 16).
4. Either:
   - Run **`GameModeScreenshotUITests`** from the Test navigator, or  
   - From repo root:  
     `chmod +x scripts/capture_game_mode_screenshots.sh && ./scripts/capture_game_mode_screenshots.sh`

### What gets captured

| Attachment prefix | Meaning |
|-------------------|---------|
| `00_main_app_arena_modes_grid` | Normal app: **Arena** tab → **Modes** segment (same grid as shipping UX). |
| `01_arena_mode_grid_all_modes` | **Screenshot harness**, Arena grid section (`-ScreenshotHarness`). |
| `02_gameplay_NN` | Harness **Gameplay** section — one frame per entry in `GameModeRegistry.all` (includes preview modes). |

Harness skips the multiplayer lobby + countdown so each mode shows gameplay chrome immediately (**START MATCH** + scene area).

### Harness launch argument

The app checks **`-ScreenshotHarness`** (see `FinalEvolutionLabApp` → `GameModeScreenshotHarnessView`). UI tests pass this automatically.

### Updating the mode count

`GameModeScreenshotUITests` uses `expectedModeCount = 19`. When you add/remove modes in `GameModeRegistry.all`, update that constant or the test will fail early or capture the wrong number of frames.

## Manual spot checks

- **Screenshot harness**: Run app with scheme argument `-ScreenshotHarness` (Edit Scheme → Run → Arguments Passed On Launch).
- Use **Gameplay** / **Next mode** to walk every mode without navigating from Lab.

## Unreal / cooked builds

These screenshots reflect the **Swift gameplay shell** (`GamePlayView`). Unreal-only visuals require separate capture from the UE host or device recording.
