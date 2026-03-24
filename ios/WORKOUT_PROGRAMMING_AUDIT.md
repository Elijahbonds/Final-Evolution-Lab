# Workout Programming Audit (Accuracy + Performance)

Date: 2026-03-08
Scope: `SystemScanView`, scan-to-audit pipeline, movement diagnosis, and workout path prescription.

## Audit Findings (before fixes)

1. **System scan did not read clip data as a stress test**
   - Scan output was generated via random ranges and goal heuristics.
   - No extraction of duration/fps/effort proxies from uploaded clip.

2. **No formal movement screens implemented**
   - No FMS, SFMA, FCS, or FRC scoring models.
   - No structured risk bands per screen.

3. **No diagnostic layer**
   - Dysfunctions were implied only through simple PRQ/vertical checks.
   - No severity/confidence or source-screen attribution.

4. **No prescriptive workout path from scan data**
   - `recommendedTrack` was only a display string.
   - Training path/equipment were not auto-aligned to scan outcomes.

5. **Biomechanics audit underused available scan context**
   - Audit relied on a lightweight formula and ignored screen-level data.

## Implemented Remediation

### 1) Stress-test capture from uploaded clip
- Added `SystemScanAnalysisEngine` to read:
  - clip duration
  - frame rate
  - estimated rep count
  - burst rate
  - fatigue index
  - asymmetry index
  - landing stability
  - effort index

### 2) Movement screen framework
- Added `MovementScreening.swift` models:
  - `MovementScreenKind` (FMS/SFMA/FCS/FRC)
  - `MovementScreenResult`, `MovementScreenItem`
  - `MovementDysfunction`
  - `WorkoutPrescription`
  - `MovementScreeningReport`

### 3) Diagnostic engine
- Implemented dysfunction inference with:
  - severity + confidence
  - source screens
  - clinical summary
  - corrective focus blocks

### 4) Data-driven path prescription
- Prescription now maps to:
  - `TrainingTrack` (Foundations / Flight / Elite)
  - `EquipmentType` focus
  - rationale + priority blocks
- `LabViewModel.applyScanResult` now auto-applies prescribed path to `TrainingProgress`.

### 5) Scan/UI integration
- `SystemScanView` now:
  - runs analysis engine for each scan
  - shows screen totals/risk, dysfunction flags, and prescribed path
- `LabView` scan panel now surfaces screen summaries and path line.

### 6) Biomechanics integration
- `BiomechanicsAudit.fromScanResult` updated to consume movement-screen signal and dysfunction penalties.

### 7) Backward compatibility
- `SystemScanResult` now includes optional `movementScreening` with `decodeIfPresent`.
- Existing stored scans decode safely.

## Performance/Robustness Notes

- Analysis is lightweight and non-blocking in UI flow.
- Uses bounded heuristics and normalized values to avoid unstable outputs.
- AVAsset reads are constrained to metadata-level extraction (duration/fps), minimizing runtime overhead.

## Validation Checklist

- [x] Scan reads clip-derived stress inputs.
- [x] FMS/SFMA/FCS/FRC scores generated.
- [x] Dysfunctions diagnosed with severity + corrective focus.
- [x] Workout path prescribed from scan outcomes.
- [x] Prescribed path updates active training progression.
- [x] UI exposes screen + diagnosis + path details.
- [x] Backward-compatible decoding preserved.
