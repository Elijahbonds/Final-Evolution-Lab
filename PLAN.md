# Simplify Scene Area in GamePlayView

Replace the current `GameSceneHostView` call inside the scene area with the simplified version using only `neuralDrive` from the view model's profile metrics.

**What changes:**
- The 3D scene view will be initialized with just the neural drive value instead of passing game mode and action handler
- All overlay elements (combo counter, neural burst indicator, action feedback, dunk overlays, aim crosshair, gesture overlay, and PS2 gamepad) remain unchanged
- The scene host view's clip shape and layout stay the same

**Note:** This requires updating `GameSceneHostView` to work without `gameMode` and `onAction` parameters, or adding an initializer that accepts only `neuralDrive`. I'll adjust the host view accordingly so the build succeeds.