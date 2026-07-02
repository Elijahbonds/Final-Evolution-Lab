# 02 — Fitness Data Schema

**Spec:** Phase 2 Biometric Integration  
**Implementation:** `app/gameplay/include/nexus/gameplay/fitness_data.h`, `fitness_data.cpp`, `gameplay_application.cpp`

Thread-safe fitness metrics bridge biometric inputs (FRC joint mobility, IAP breath) into gameplay physics (throw-catch power multiplier).

## Data structures

### FRCMetrics (Functional Range Conditioning)

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `mobilityScore` | `float` | 0.0–1.0 | Joint mobility score |
| `activeRangeScore` | `float` | 0.0–1.0 | Active range of motion score |
| `controlScore` | `float` | 0.0–1.0 | Movement control quality |

### IAPMetrics (Integrated Athletic Performance — breath)

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `engagementScore` | `float` | 0.0–1.0 | Breath engagement |
| `confidence` | `float` | 0.0–1.0 | Breath detection confidence |
| `breathPhase` | `int8` | −1, 0, 1 | −1 exhale · 0 neutral · 1 inhale |

### FitnessSnapshot

Atomic read copy containing `frc`, `iap`, and monotonic `revision` (incremented on every update).

## Thread safety

`ThreadSafeFitnessData` guards all writes and reads with a mutex:

- `update(frc, iap)` — full snapshot, single revision bump.
- `update_frc(metrics)` — partial FRC; preserves IAP.
- `update_iap(metrics)` — partial IAP; preserves FRC.
- `snapshot()` — consistent copy for consumers.
- `read_view()` — `FitnessReadView` for physics modules (throw-catch).

## Agent commands

All commands accept optional params; omitted fields retain the current snapshot value.

### `fel.fitness.update` (alias: `fitness.update`)

Updates both FRC and IAP in one revision.

| Param | Type | Clamped to |
|-------|------|------------|
| `frc_mobility` | number | 0.0–1.0 |
| `frc_active_range` | number | 0.0–1.0 |
| `frc_control` | number | 0.0–1.0 |
| `iap_engagement` | number | 0.0–1.0 |
| `iap_confidence` | number | 0.0–1.0 |
| `breath_phase` | integer | −1–1 |

**Response (ok):** `{ "fitness_revision": <uint64> }`

### `fel.fitness.update_frc` (alias: `fitness.update_frc`)

Updates FRC fields only.

### `fel.fitness.update_iap` (alias: `fitness.update_iap`)

Updates IAP fields only.

### Validation errors

- Non-numeric float params → `"fitness parameter must be numeric"`.
- Non-integer `breath_phase` → `"fitness integer parameter has invalid type"`.
- Unknown command → `"Unsupported fitness command"`.

## Session state query

`fel.query.get_session_state` returns:

```json
{
  "fitness": {
    "revision": 1,
    "frc": {
      "mobility_score": 0.75,
      "active_range_score": 0.5,
      "control_score": 0.25
    },
    "iap": {
      "engagement_score": 0.8,
      "confidence": 0.9,
      "breath_phase": 1
    }
  },
  "throw_catch": { "phase": 0, "power_multiplier": 1.35, "throws_triggered": 0 },
  "agent": { "processed_messages": 0, "latest_errors": 0 },
  "updates_completed": 1
}
```

## Downstream consumers

`ThrowCatchPhysicsController` reads `FitnessReadView` each update:

- **FRC aggregate:** mean of mobility, active range, control (clamped 0–1).
- **IAP aggregate:** `engagementScore × confidence` (clamped 0–1).
- **Power multiplier:** `1.0 + frc×0.35 + iap×0.25` → scales throw impulse on `kThrow` phase.

## Example command sequence

```json
{"type":"command","id":"1","payload":{"command":"fel.fitness.update_frc","params":{"frc_mobility":1.0}}}
{"type":"command","id":"2","payload":{"command":"fel.fitness.update_iap","params":{"iap_confidence":0.2,"breath_phase":-1}}}
{"type":"query","id":"3","payload":{"query":"fel.query.get_session_state"}}
```
