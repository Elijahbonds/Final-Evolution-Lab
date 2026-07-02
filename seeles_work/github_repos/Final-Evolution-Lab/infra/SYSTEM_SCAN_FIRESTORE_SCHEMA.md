# System Scan — Firestore schema (v1)

Swift is the source of truth for **HealthKit-derived PRQ / readiness** and the **avatar performance vector** that Unreal should mirror for game modes and avatar visuals.

## Collections

All paths are under a Firebase Auth user (today: **anonymous** until you add Sign in with Apple / email).

```
users/{uid}/system_scans/{scanId}     # append-only history (one doc per HealthKit refresh)
users/{uid}/avatar_performance/current  # single doc, merge-updated “latest” for UE + shell
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

Normalized **0…1** attributes plus raw multipliers for gameplay. Updated with **`merge: true`** so you can add UE-only keys later from the engine.

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

## Unreal JSON bridge

Swift encodes **`UnrealSystemScanPayload`** (see `SystemScanRecord.unrealBridgeJSON()`) with **epoch milliseconds** instead of Firestore `Timestamp`, for easy `FJsonObject` parsing.

Top-level keys: `schemaVersion`, `capturedAtEpochMs`, `vitals`, `readiness`, `avatar` (avatar uses `updatedAtEpochMs`).

### Native embedded framework

After each successful Firestore write, **`UnrealManager.deliverSystemScanJSON(_:)`** logs the exact UTF-8 string and, if Unreal is loaded, calls Objective‑C:

`- (void)receiveSystemScanJSON:(NSString *)json;`

on the **`UnrealFramework`** principal instance.

### Emergent WebSocket

When `FEL_GAME_WS_URL` / `fel_emergent_game_ws_url` is set, Swift sends one text frame:

`{ "type": "fel_system_scan", "scan": <UnrealSystemScanPayload as JSON object> }`

UE / backend can branch on `type === "fel_system_scan"`.

### Debug: mock scan

**Debug** builds show **SIMULATE SCAN** on the Performance Dashboard; it writes `source: "debug_simulated"` and runs the same bridge path as HealthKit.

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
