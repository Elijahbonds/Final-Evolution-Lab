# Add Neural Drive and "Hold X" overlays to court ZStack

**Changes**

Inside the `ZStack` in `courtSection` (around line 360–412 of LabView.swift), add two new overlay elements on the `UnityContainerView` block:

1. **Top-left overlay** — "NEURAL DRIVE" label with the current percentage from `viewModel.profile.metrics.neuralDrive`, styled in a small monospaced font matching the existing UI theme.
2. **Bottom-center overlay** — "HOLD X TO GATHER" prompt text, styled similarly, displayed below the existing scoring overlay area.

Both will use the app's existing `Theme` colors and monospaced styling to stay visually consistent.