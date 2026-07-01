# UE 5.7 external basketball project — integration checklist

Use this when merging **this repo’s** Unreal snippets and tooling into your **live** Unreal Engine 5.7 game project (physical path outside iCloud/Desktop if you hit Xcode/codesign path bugs on macOS).

---

## Repo automation (Emergent)

- From repo root, with `PROJECT_DIR` pointing at your UE game folder:
  - `PROJECT_DIR="/path/to/your/project" ./prepare_fel_bridge.sh`
  - Optional: `./prepare_fel_bridge.sh --copy-sources`
- Runtime URL override (matches iOS `Config.resolvedEmergentGameWebSocketURL()`):
  - `FEL_GAME_WS_URL=wss://your-host/ws/game/room-id`
- Merge `UnrealIntegration/Config/DefaultGame.FEL_Bridge.snippet.ini` into your **DefaultGame.ini** `[FELBridge]` section.

---

## Module and plugins

- Copy `UnrealIntegration/Source/FinalEvolutionLab/*.h|*.cpp` into your game’s `Source/FinalEvolutionLab/` (or use `--copy-sources`).
- **FinalEvolutionLab.Build.cs**: add `WebSockets`, `Json` to `PrivateDependencyModuleNames`.
- Editor → Plugins → enable **WebSockets**.
- Blueprint/C++: `UFELBridgeSubsystem` — `SetGameWebSocketUrl`, `SendMatchScoreToWebSocket`, optional focus keepalive (see `COPY_INTO_GAME_MODULE.txt`).

---

## Pixel Streaming 2

- Merge `DefaultEngine.pixelstreaming2.snippet.ini` (see `COPY_INTO_GAME_MODULE.txt` for path) into **Config/DefaultEngine.ini**.
- Optional: `UFELFocusKeepaliveTickComponent` → Pixel Streaming 2 streamer “ApplicationEvent” focus keepalive if you use iframe focus bridging.

---

## Animation (basketball)

- **IK / foot placement**: validate control rig / IK targets for your skeletal mesh after retargeting.
- **Motion Warping**: confirm warp targets for jump shots / dunks align with court anchor actors; test root motion vs in-place blends.
- **Montages**: verify notify windows for ball release and landing match gameplay feel tests.

---

## Cook / ship targets (from this repo)

- **Win64 cook** (needs Windows SDK/target where applicable): `./fel_ue5_win64_cook_only.sh`
- **Linux E3DS package**: `./fel_ue5_eagle3d_linux_package.sh` → `artifacts/Linux/FEL_UE5_E3DS_Linux_Package.zip`
- **iOS shipping package** (host-side script): `./fel_ue5_ios_shipping_package.sh` — confirm Xcode scheme, signing team, provisioning profile, and **non‑iCloud** project copy if codesign fails on long/cloud paths.

---

## iOS companion app (Swift)

- Emergent WebSocket URL: environment variable `FEL_GAME_WS_URL`, or UserDefaults key `fel_emergent_game_ws_url` (see `Config.swift`).
- **Inbound JSON** handled in `EmergentRealtimeClient.applyEmergentPayload` — align backend messages with documented `type` / `prq` / `delta` fields.

---

## Content and data

- Copy or load `FEL_VenueRegistry.production.json` per `COPY_INTO_GAME_MODULE.txt`.
- Reconcile **marketing mode count** vs `GameModeRegistry` in the Swift app if you expose mode lists in UI.

---

## Verification

- UE: packaged build connects to Emergent WS; outbound match scores appear on backend; inbound logs or Blueprint handlers receive frames.
- iOS: set `fel_emergent_game_ws_url` in UserDefaults (or scheme env) and confirm PRQ tier updates after backend pushes `prq_update`.

---

## Next steps (suggested)

- Define a single **JSON schema** document for Emergent (types, versioning, room ids) shared by UE bridge, iOS client, and backend.
- Add **reconnect/backoff** policy on iOS to mirror UE `bAutoReconnect` behavior.
- Expand **Swift tests** with seeded RNG wrappers for `DynamicDifficulty.opponentPoints` if you need probabilistic assertions.
