# NexusEngine Migration — UE5 → Native Swift

## What changed

The embedded Unreal Engine 5 runtime has been replaced by **NexusEngine**, a fully native Swift game engine.

### Before (UE5)
- `NexusBridge.swift` dynamically loaded `UnrealFramework.framework` via ObjC `NSObject.perform()`
- `NexusBootSequence.primeAvatar()` encoded a `SystemScanRecord` and forwarded it to the UE host via `receiveSystemScanJSON:`
- `NexusEngine.deliverScanToUnreal()` bridged PRQ data into Unreal physics
- Game scenes were defined as Unreal Level Blueprints (`.umap`)
- Assets referenced via Meshy.ai asset IDs and Unreal package paths

### After (NexusEngine)
- `NexusRenderer` (Swift, `@Observable @MainActor`) owns all scene state and player physics
- `NexusBridge.swift` is a thin data relay: it takes the same incoming data and routes it to `NexusRenderer` methods
- `NexusBootSequence.primeAvatar()` delivers scan data via `NexusBridge.deliverSystemScanJSON()` → `NexusRenderer.applyPRQ()`
- Game scenes are defined as `NexusScene` values (Swift ECS) serialized to `.nexus.json` files in `NexusStarter/`
- All rendering is done via SwiftUI `Canvas` in `NexusSceneView` (60 Hz via `TimelineView(.animation)`)
- `NexusLoop` provides a `CADisplayLink`-based game loop for physics integration steps
- `NexusEditorView` is an in-app scene editor (entity list + Canvas viewport + component inspector)

## File mapping

| Old (UE5) | New (NexusEngine) |
|---|---|
| `NexusBridge.swift` — ObjC framework loader | `NexusBridge.swift` — native data relay |
| `NexusBootSequence.primeAvatar()` → UE selector | `NexusBootSequence.primeAvatar()` → `NexusRenderer` |
| `NexusEngine.deliverScanToUnreal()` | `NexusEngine.syncPRQToRenderer()` |
| `NexusEngine.BootState.bootingAvatar` | `NexusEngine.BootState.bootingRenderer` |
| `NexusError.nexusNotReady` — Unreal message | `NexusError.nexusNotReady` — renderer message |
| `UnrealStarter/BasketballGame/` | `NexusStarter/BasketballGame/` |
| `UnrealIntegration/Source/` — C++ subsystems | Native Swift equivalents in `NexusRenderer` |
| `FEL_VenueRegistry.production.json` | `VenueRegistry.nexus.json` |
| Unreal Blueprint class names (`nexusEngineClass`) | `NexusScene.default(for:prq:)` factory |

## Bridge handshake

| Version | Runtime |
|---|---|
| `FEL-SOVEREIGN-BRIDGE-v1` | Rork (deprecated) |
| `FEL-SOVEREIGN-BRIDGE-v2` | UnrealEngine5 (deprecated) |
| `FEL-SOVEREIGN-BRIDGE-v3` | NexusEngine Swift native (current) |

## PRQ → physics mapping

PRQ (0–100) is fed into `NexusPhysicsConfig.applyPRQ()`:

| PRQ | Speed mult | Jump bonus | Reaction window |
|---|---|---|---|
| 0   | 1.00× | 0.0 | 0.50s |
| 50  | 1.28× | 1.1 | 0.38s |
| 100 | 1.55× | 2.2 | 0.25s |

## NexusScene ECS components

| Component | Purpose |
|---|---|
| `.skeleton(category:amplitude:)` | Procedural Canvas skeleton animation |
| `.physics(mass:restitution:)` | Rigid body physics body |
| `.surface(friction:)` | Collision surface (floor, wall) |
| `.sprite(systemImage:hexColor:)` | SF Symbol sprite |
| `.trigger(radius:eventName:)` | Score/event zone |
| `.camera(zoom:fov:)` | Viewport camera |
| `.light(intensity:hexColor:)` | Scene light source |
