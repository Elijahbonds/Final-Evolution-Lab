# Final Evolution Lab – Gameplay Improvements Plan

This doc aligns all game modes with the target feel (Wii Sports / Resort, NBA Street, NFL Street, FIFA Street, etc.) and tracks controller, mechanics, and visual goals.

---

## Input & Controller

- **All gameplay:** Controller **or** swipe (no target-passing football; kick return sudden death only).
- **PS2-style overlay:** D-pad (left), left stick (left), right stick (right), face buttons (△ □ ○ ✕) in **PlayStation positions** — triangle top, square left, circle right, X bottom. Implemented in `PS2GamepadOverlay`.
- **Avatar:** System-scan / IRL avatar used in Lab court; `RealityKitDunkView` takes `avatarConfig` (tint, heightScale) from `profile.effectiveAvatarConfig`.

---

## Game Modes & Mechanics

| Mode | Target feel | Input | Status / next steps |
|------|-------------|--------|----------------------|
| **Home Run Derby** | Wii Sports Baseball | Swipe / tap to swing | Pitcher, ball, catcher, mound, stadium in scene. `HomeRunDerbyManager` handles pitch + bat contact. Tune timing windows and swing feedback. |
| **Closest to Pin** | Wii Sports Golf | Swipe (power + direction) | `swipeGolf` scheme. Add power arc UI and green target. |
| **Penalty Shootout** | FIFA Street / Resort | Swipe to shoot | Field, net, ball, penalty spot, stadium. Ball flight path on swipe (not currently in app; only freestyle dunk is active). |
| **Kick Return** | Sudden death return | Swipe / stick to move, evade | Returner + special-teams defenders with **homing** toward returner. Fix: homing uses `scene.rootNode` for returner lookup. Smooth returner movement and tackle radius. |
| **Rally Ace (Volleyball & Tennis)** | Wii Sports / Resort | **Drag** to aim, **tap** to hit | Drag for aim, tap for shot. Ensure `rallyAce` / `dragTap` in `GameMode` and that scenes have ball + snap-to-player logic. |
| **Dunk Contest** | NBA Live 06 × NBA Street | Charge + face buttons (△□○✕) | PS2 overlay; improve timing and trick variety. Smooth gather → flight → impact animations. |
| **1v1 Basketball** | NBA 2K-style 1v1 | Charge + face | Same controller; ensure 2 avatars, hoop, ball. |
| **3v3 Basketball** | NBA Street | Charge + face | **6 models on court** (3 per team). Smoother shuffle/homing; optional 4v4 (8) later. |
| **Karate** | Matrix / Naruto Storm | Charge + face | Dojo scene; improve strike/hit reactions and movement. |
| **Gymnastics** | Mario & Sonic Olympics | **Rhythm tap** | Rhythm tap scheme; apparatus + tumbling animations. |
| **Brain Brawl** | Big Brain Academy × Coursebox AI | Tap / swipe | New mode (placeholder in registry); add quiz / puzzle UI and logic. |

---

## Scenes & Assets (SceneKit)

- **Baseball:** Pitcher (avatar), catcher (avatar), mound (cylinder), rubber, home plate, bases, stadium stands/lights/crowd, **ball** (spawned by `HomeRunDerbyManager`). ✓
- **Football:** Field, yard lines, end zones, returner, **ball** (kick arc), **11 defenders** with homing; stadium. Homing uses `scene.rootNode.childNode(returner)`.
- **Soccer:** Pitch, stripes, penalty spot, **goal + net**, kicker, goalkeeper, **soccer ball** at spot; stadium. Flight path: drive `soccerball` node (and optional trail) on swipe-shot.
- **3v3:** Court, 2 hoops, **6 avatars** (blue1–3, red1–3), ball; Venice walls/crowd. Animations: easeInEaseOut shuffle, homing defense.
- **Dunk Contest:** Court, dunker avatar, hoop; camera FOV per phase; impact particles.
- **Lab 3D court:** **Freestyle Dunk Practice** — already titled in LabView (“FREESTYLE DUNK PRACTICE” + “Venice Beach Court”); spin, slam, landing timing.

---

## Animations & Polish

- **Smoothing:** Prefer `easeInEaseOut` (or equivalent) for movement; avoid linear where it feels robotic. Dunk court uses RealityKit; other modes are not currently active.
- **Reference:** Use @elijahbonds (Instagram) for motion reference; implement in-app as keyframes or blend targets as assets allow.
- **Visual bar:** Aim for Asphalt-level clarity (lighting, materials, particles); keep 60fps on target devices. **Graphics presets** (Settings → Graphics): High / Standard (60fps) and Performance (30fps, reduced resolution/shadows/particles) for battery and older devices. See **INSPIRATIONS_COMPARISON.md** for comparison vs. NBA 2K, Storm x Matrix, Wii Sports/Resort, NBA Live 06/07.

---

## Movement & animation (emulator feel)

- **Player movement:** Velocity-based with **PS2MovementConfig** per mode (topSpeed, acceleration, deceleration). Frame-rate independent delta; stick input accelerates velocity, release applies smooth deceleration and coast-to-stop. Bounds clamp position and zero velocity at walls.
- **Run / idle:** Run animation only when velocity magnitude > threshold; idle when below. Transitions avoid flicker; run bob and leg/arm use **easeInEaseOut**.
- **Camera:** Follow loop uses delta time for consistent smoothing across frame rates.
- **Scene NPCs:** Karate punch/kick, football kick arc, 3v3 shuffle, goalkeeper sway use eased timing where applicable.

## Implementation Notes

- This repo’s iOS target is **Swift/SwiftUI + SceneKit**. Game modes and scenes live here.
- **Unreal (MyProject)** is a separate project (Combat / Platforming / SideScrolling). To “build in Unreal” for these sports, you’d port or recreate modes in Unreal and open in Unreal Editor; that’s a separate effort from this repo.
- **Character creation / IRL avatar:** Driven by system scan; `RealityKitDunkView` uses `profile.effectiveAvatarConfig` for dunker appearance (tint, scale).

---

## File References

- Modes & physics: `FinalEvolutionLab/Models/GameMode.swift`, `ArcadePhysics.swift`, `DunkContestEngine.swift`
- Lab court (RealityKit): `FinalEvolutionLab/Views/RealityKitDunkView.swift`
- Full-screen dunk: `FinalEvolutionLab/Views/LabView.swift` (`DunkFullScreenView`, `executeFreestyleScoring`)
- Controller overlay: `FinalEvolutionLab/Views/PS2GamepadOverlay.swift`
