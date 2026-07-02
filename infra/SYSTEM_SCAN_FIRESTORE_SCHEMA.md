# System Scan — Firestore schema (v1)

> **NEXUS-only ship:** Production retail builds route system-scan payloads to **`NexusGameplayBridge`** (`fel.fitness.update`) and optional WebSocket relay. **`UnrealManager`** / embedded UE framework paths are **archived legacy** — compiled only when `NEXUS_LEGACY` is defined (Debug opt-in; absent from Release `SWIFT_ACTIVE_COMPILATION_CONDITIONS`). See `SHIPPING_ARCHITECTURE.md`, `NEXUS_ONLY_PIVOT.md`.

Swift is the source of truth for **HealthKit-derived PRQ / readiness** and the **avatar performance vector** consumed by NEXUS gameplay and cross-device sync.

## Collections

All paths are under a Firebase Auth user (today: **anonymous** until you add Sign in with Apple / email).

```
users/{uid}/system_scans/{scanId}     # append-only history (one doc per HealthKit refresh)
users/{uid}/avatar_performance/current  # single doc, merge-updated “latest” for NEXUS + shell
```

## Document: `system_scans/*`

| Field | Type | Notes |
|--------|------|--------|
| `schemaVersion` | int | **1** — bump when semantics change |
| `source` | string | e.g. `healthkit` |
| `capturedAt` | timestamp | server/client time of snapshot |
| `vitals` | map | optional doubles (omit if unknown) |
| `vitals.heartRateBpm` | number? | |
| `vitals.restingHeartRateBpm` | number? | |
| `vitals.hrvSdnnMs` | number? | SDNN in ms |
| `vitals.activeKcal` | number? | day slice (matches app query window) |
| `vitals.weeklyHrvAverageMs` | number? | |
| `vitals.sleepHoursLastNight` | number? | Asleep hours from **sleepAnalysis** (recent window) |
| `readiness` | map | PRQ / neural readiness |
| `readiness.neuralReadinessScore` | number | 0…100 |
| `readiness.grade` | string | `ELITE` / `PRIMED` / `READY` / `RECOVERING` |
| `readiness.hrvTrend` | string | `IMPROVING` / `STABLE` / `DECLINING` |
| `readiness.recoveryEstimateHours` | number | |
| `avatar` | map | same shape as `avatar_performance/current` (denormalized) |

### Avatar mapping (Swift)

`AvatarPerformanceAttributes.calculateAttributes(vitals:readiness:sleepHoursForMapping:speedMultiplier:hangTimeBonus:isRecoveryMode:)` derives **0…1** axes from HealthKit + PRQ:

- **Neural focus:** HRV vs weekly baseline, absolute HRV level, sleep quality (hours vs ~7–8.5h band), PRQ, HRV trend.
- **Explosiveness:** Tier speed multiplier, HR reserve (HR − RHR), active energy, resting-HR reserve, recovery headroom.

Missing sleep uses a neutral **0.48** so other signals still dominate.

## Document: `avatar_performance/current`

Normalized **0…1** attributes plus raw multipliers for gameplay. Updated with **`merge: true`** so you can add engine-only keys later from NEXUS runtime.

| Field | Type | Notes |
|--------|------|--------|
| `schemaVersion` | int | **1** |
| `updatedAt` | timestamp | |
| `explosiveness` | number | 0…1 |
| `endurance` | number | 0…1 |
| `recovery` | number | 0…1 |
| `neuralFocus` | number | 0…1 |
| `biomechanicalEfficiency` | number | 0…1 |
| `prqScore` | number | 0…100 raw |
| `readinessGrade` | string | |
| `speedMultiplier` | number | from arcade buff |
| `hangTimeBonus` | number | |
| `isRecoveryMode` | bool | |

## NEXUS bridge (production path)

After each scan (before or alongside Firestore persist), **`SystemScanFirestoreSync.deliverScanToBridge`** runs on the main actor:

1. **`NexusGameplayBridge`** — short-lived session; `syncReadiness` + `fel.fitness.update` JSON with FRC/IAP scalars mapped from avatar attributes (`SystemScanFirestoreSync.swift`).
2. **`EmergentRealtimeClient`** — optional WebSocket text frame when `FEL_GAME_WS_URL` / `fel_emergent_game_ws_url` is set (see Runtime WebSocket below).
3. **`NotificationCenter`** — posts `.felSystemScanBridgeCompleted` for UI/social hooks.

Bridge dispatch is **best-effort** and does not block Firestore persistence; failed writes enqueue locally for retry.

## JSON wire format (WebSocket + legacy alias)

Swift encodes **`UnrealSystemScanPayload`** (see `SystemScanRecord.unrealBridgeJSON()`) with **epoch milliseconds** instead of Firestore `Timestamp`, for easy `FJsonObject` / JSON parsing on relay consumers.

Top-level keys: `schemaVersion`, `capturedAtEpochMs`, `vitals`, `readiness`, `avatar` (avatar uses `updatedAtEpochMs`).

### Runtime WebSocket

When `FEL_GAME_WS_URL` / `fel_emergent_game_ws_url` is set, Swift sends one text frame:

`{ "type": "fel_system_scan", "scan": <UnrealSystemScanPayload as JSON object> }`

Backend / agent runtime can branch on `type === "fel_system_scan"`.

### Archived — UE embedded framework (`NEXUS_LEGACY` only)

> **Not compiled in Release App Store builds.** Opt-in Debug builds with `NEXUS_LEGACY` may still call:

**`UnrealManager.deliverSystemScanJSON(_:)`** — logs the exact UTF-8 string and, if Unreal is loaded, calls Objective‑C:

`- (void)receiveSystemScanJSON:(NSString *)json;`

on the **`UnrealFramework`** principal instance. This path is **reference-only**; do not extend for retail ship.

### Debug: mock scan

**Debug** builds show **SIMULATE SCAN** on the Performance Dashboard; it writes `source: "debug_simulated"` and runs the same NEXUS bridge path as HealthKit.

## Security rules (starter)

Lock writes to the signed-in user:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

Enable **Anonymous** auth in Firebase Console for development; tighten for production if you migrate UIDs.

## Swift entry points

- `FirebaseBootstrap.configureIfNeeded()` — app launch  
- `SystemScanFirestoreSync.syncLatestFromHealthKit(_:)` — called after each successful HealthKit refresh (best-effort, errors swallowed in `HealthKitService` today)
