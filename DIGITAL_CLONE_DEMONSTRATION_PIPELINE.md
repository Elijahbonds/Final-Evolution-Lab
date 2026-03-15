# Digital Clone Demonstration Pipeline

## README

This app now uses a **digital clone-first** workout demo flow:

1. **Generated clone animation** (primary)
2. **Local real clip** (only if specifically attached for an exercise)
3. **Request real clip** (final fallback per exercise)

External video URLs are retained as **reference metadata only**.  
They are used by ingestion and motion generation scaffolding, and are not presented as clickable workout demo links.

### Core components

- `Models/DigitalCloneDemo.swift`
  - `ExerciseDemoAsset`
  - `CloneProfile`
  - `MovementDatabase`
  - `LegacyExerciseReferenceCatalog`
- `Services/MovementIngestionService.swift`
  - Manifest ingestion
  - Pose extraction stub interface
  - Retargeting stub interface
- `Services/DemoEngine.swift`
  - Runtime demo selection (generated > local > request)
- `Views/ExerciseDemoView.swift`
  - UI badges and fallback behavior

---

## MIGRATION_NOTES

### Legacy behavior

- `DemoEngine` had a hardcoded `videoMap` with direct external URLs.
- Coach mode depended on loading those direct links.

### New behavior

- Legacy map is migrated into `MovementDatabase` as:
  - `.referenceOnly` asset entries (metadata)
  - `.generatedAnimation` entries produced by ingestion stubs
- Migration is triggered by `LabViewModel.seedDigitalClonePipelineIfNeeded()`.
- Migration target is controlled by:
  - `DigitalCloneDefaults.targetMigrationVersion`

### Data migration details

1. Load existing `MovementDatabase`.
2. If migration version is behind:
   - Build manifest from `LegacyExerciseReferenceCatalog`.
   - Create/refresh `referenceOnly` assets.
   - Generate synthetic `generatedAnimation` assets via stub extraction/retargeting.
3. Persist:
   - `CloneProfile`
   - `MovementDatabase`

### Backward compatibility

- Existing exercise IDs (`f1...e5`) remain valid and resolve in the new pipeline.
- Cloud snapshot decoding is backward-compatible:
  - `cloneProfile` is optional
  - `movementDatabase` falls back to empty default when missing

