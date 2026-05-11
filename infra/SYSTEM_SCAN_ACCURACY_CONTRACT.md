# System scan / PRQ accuracy contract

This document is the **rulebook** for what a System Scan may claim in product, support, and App Store copy. It complements `SystemScanResult.source`, `confidence01`, and `SystemScanResult.supportsBiomechanicalPrescription` in code.

## Scan classes

| Class | `SystemScanSource` | Meaning |
|--------|-------------------|--------|
| **Demo / synthetic** | `demoSynthetic` | Goal-band or UI sampling only. **No** pose, mesh, or instrument measurement. |
| **Measured** | `measured` | Data from a pipeline that can justify performance or geometry claims (pose, lab instrument, approved AR flow), with a **confidence** score in `0…1`. |
| **HealthKit** | *(not a scan source)* | Readiness / recovery proxies via `HealthKitService` — **not** a substitute for measured scan geometry. |

## What may affect ranked PRQ and competitive state

Only scans where **`commitsCompetitiveMetrics`** is true:

- `source == .measured`
- `confidence01 >= SystemScanResult.minimumConfidenceForCompetitiveCommit` (currently **0.72**)

Demo scans **must not** overwrite competitive PRQ, SQL peak PRQ (`TrainingLabSocialBridge.syncPeakPRQFromScanResult`), or leaderboard refresh tied to committed scans.

## Body IQ, kinetic leakage, and arcade joint modifiers

**`supportsBiomechanicalPrescription`** uses the **same predicate** as `commitsCompetitiveMetrics` today: measured + sufficient confidence.

- **Demo / low-confidence scans** must **not** populate athlete-specific **kinetic leakage zones** or joint prescriptions derived from scan math.
- **`BiomechanicsAudit.fromScanResult`** returns **preview-safe** placeholders (moderate joints, **empty** leakage list) unless `supportsBiomechanicalPrescription` is true.
- Applying a non-committing scan **clears** `LabViewModel.biomechanicsAudit` so a prior measured audit cannot linger beside a demo session.

## Social, certificates, and marketing language

- **Community feed / athlete-specific framing** (see Body IQ education lab) requires **`supportsBiomechanicalPrescription`** (or equivalent `commitsCompetitiveMetrics` check).
- **Certificates and progression integrity** must use **server-verified** attempt records where applicable; demo scan PRQ must never satisfy prerequisites that imply measured competence.

## UI copy

- Non-committing scans should present **“Preview PRQ”**, not language implying verified lab or competitive measurement.
- Demo pipeline screens should continue to state that vertical / flight / PRQ samples are **illustrative** unless `commitsCompetitiveMetrics` is true.

## Engineering checklist when adding a new scan pipeline

1. Set `source` and `confidence01` correctly on `SystemScanResult`.
2. Never set `source == .measured` until the pipeline truly performs the claimed measurement.
3. Gate any new **ranked**, **social**, or **certificate** behavior on **`commitsCompetitiveMetrics`** or **`supportsBiomechanicalPrescription`** as appropriate.
