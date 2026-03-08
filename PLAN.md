# Fix build error: Replace missing arcade calls with existing performAction

**Problem**
The general-mode PS2 button handler (lines 3433–3442) calls `viewModel.arcade.Shoot()`, `.Dunk()`, `.Sprint()`, `.Style()` — but these don't exist. `LabViewModel` has no `arcade` property with those methods.

**Fix**
Replace those four calls with the existing `performAction(_:)` method that already handles shooting, scoring, combos, critical hits, and feedback for all game modes:

- **Triangle** → `performAction("Shoot")`
- **Square** → `performAction("Dunk")`
- **Circle** → `performAction("Sprint")`
- **Cross** → `performAction("Style")`

This is a single 4-line change in `GamePlayView.swift`. No new files or models needed.