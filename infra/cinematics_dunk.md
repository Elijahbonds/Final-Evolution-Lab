# Dunk Cinematic Spec — `basketball_dunk_3d`

Camera, audio, VFX, and haptic choreography for the signature dunk moment.
Consumes the server-side `av_cues` hints (`backend/lib/av_cues.py`) and the
logical cue names in `infra/audio_event_map.json` (nexus/audio-vfx-assets,
PR #120). No new binaries — audio/VFX assets are the maintainer-fetched
freesound/opengameart entries already listed in `infra/asset_sources.json`.

Validated by `scripts/demo_dunk_cinematic.py` (timing table parses, every
dunk phase covered).

---

## 1. Shot list (camera spline keyframes)

The cinematic is a single continuous camera spline with one hard cut at the
end. Keyframe positions are expressed in the same player-relative space the
chase camera already uses (`PremiumViewpointConfig.ChaseCamera` offsets).

| # | Shot              | Camera keyframe (player-relative)                          | FOV  | Timing driver |
|---|-------------------|------------------------------------------------------------|------|---------------|
| K0| Approach wide     | broadcast-style high wide: `(x*0.25, y+11.0, z+15.0)`      | 55°  | `phase == .approach` |
| K1| Launch low-angle  | low frontal: `(x+2.2, y+0.6, z+3.4)`, look-at `y+1.6`      | 38°  | `phase == .launch` |
| K2| Apex orbit 30°    | orbit radius 8.5 around dunker, sweep **30°**, height y+4.2| 44°  | airTime in [30%, 70%] of `maxAirTime` |
| K3| Rim impact slow-mo| close-up `(x+1.1, y+3.2, z+1.8)`, look-at rim (y+3.05)     | 22°  | **0.3× time scale for 400 ms** at rim contact |
| K4| Judge reveal cut  | hard cut to judges' table wide, static                     | 50°  | `phase == .scored` |

Orbit direction follows the dunker's rotation direction (`rotationAmount`
sign) so windmill/360 tricks read correctly.

---

## 2. Timing table (tied to `DunkPhase`)

Phases are the Swift dunk engine's state machine — `DunkPhase` in
`FinalEvolutionLab/Models/DunkContestEngine.swift:4-11`
(`idle / approach / launch / airborne / landing / scored`). Air time is
dynamic: `maxAirTime = 2.4 + jumpHeight * 1.0` (`confirmLaunch()`,
DunkContestEngine.swift:319), so airborne beats are expressed as fractions
of `maxAirTime`, matching the engine's own windows (`updateAirborne`,
DunkContestEngine.swift:330-352).

| Phase      | t (start)                | Duration                  | Shot | Beat |
|------------|--------------------------|---------------------------|------|------|
| `idle`     | —                        | until sprint held         | K0   | Camera pre-parked wide; crowd ambience bed |
| `approach` | 0.00 s                   | player-driven (sprint charge) | K0 | Wide tracking; dolly-in eased by `sprintCharge` |
| `launch`   | sprint release           | player-driven (timing bar)| K1   | Snap to low-angle; FOV kick 55°→38° |
| `airborne` | launch confirm (`airPhaseStart`) | `maxAirTime` (~2.4-3.4 s) | K2 | Orbit 30°; apex freeze mirrors engine `showApexFreeze` (airTime 40%→40%+0.3 s); engine slow-mo window 30%→70% |
| `landing`  | `airTime >= maxAirTime`  | 0.40 s                    | K3   | **Rim impact slow-mo: 0.3× for 400 ms**, then ramp back to 1.0× |
| `scored`   | landing confirm          | 2.5 s hold                | K4   | Hard cut to judge reveal; scores punch in one by one |

Engine seams the table keys off directly:
- `showApexFreeze` / `showSlowMo` flags — DunkContestEngine.swift:340-342
- `impactIntensity` + `rimDistortionAmount` — DunkContestEngine.swift:265-267
- `judgeScores` tuple populated at `scored` — DunkContestEngine.swift:152

---

## 3. Audio / VFX / haptic sync points

Logical cue names only (client resolves via `infra/audio_event_map.json`;
missing files skip silently). Server events already arrive with matching
`av_cues` hints from `backend/lib/av_cues.py`.

| Sync point              | Trigger                              | Audio cue     | VFX sprite       | Haptic |
|-------------------------|--------------------------------------|---------------|------------------|--------|
| Round start             | `match_start` event / round begin    | `buzzer`      | —                | —      |
| Approach footsteps      | `approach` phase tick (speed-scaled) | (ambient bed) | —                | —      |
| Launch                  | `launch` → `airborne` transition     | `crowd_hype`  | —                | light  |
| Apex freeze             | `showApexFreeze` rising edge         | (music duck −6 dB) | —           | —      |
| **Rim impact**          | `landing` start (= `dunk_result`)    | `rim_clank`   | `particle_burst` | heavy  |
| Clean finish tail       | 150 ms after rim impact, if clean    | `net_swish`   | —                | —      |
| Judge reveal            | `scored` phase / score event         | `score_sting` | `particle_soft`  | light  |

The rim-impact row is exactly the `dunk_result` entry in `AV_CUE_TABLE`
(`rim_clank` + `particle_burst` + `heavy`), and what
`POST /api/arena/dunk/score` returns in its `av_cues` field — so an
online-scored dunk and the local cinematic stay in sync from one table.

---

## 4. SceneKit implementation sketch

Two viable integration paths; both hang off seams that already exist.

### Option A (preferred): extend the ScenicCameraAngle override mechanism

The scene host already has an event-driven cinematic override system in
`FinalEvolutionLab/Views/GameSceneHostView.swift`:

- `ScenicCameraAngle` enum (`chase / broadcast / actionCloseUp /
  cinematicPan`) — GameSceneHostView.swift:5-24; `basketballDunkContest3D`
  already defaults to `.actionCloseUp`.
- `triggerTemporaryCameraCut(to:duration:)` — GameSceneHostView.swift:598
  — installs `temporaryCameraAngleOverride` with an auto-expiring Task;
  gameplay notifications already drive it (`.felGameplayWaveCompleted` →
  `.cinematicPan` for 3.5 s at line 530, `.felGameplayOpponentScored` →
  `.broadcast` + shake at lines 534-548).
- Per-frame cinematic offsets `cinematicZoomOffset / cinematicHeightOffset /
  cinematicAngleOffset` blended with `cinematicTransitionProgress` easing —
  declared GameSceneHostView.swift:173-177, applied to the desired camera
  position at lines 712-719.
- Base framing comes from `PremiumViewpointConfig.chaseCamera(for:)`
  (`FinalEvolutionLab/Utilities/PremiumViewpointConfig.swift:57-60`,
  cluster/mode delta merge at 328-336), consumed by
  `defaultCameraConfig(for:)` at GameSceneHostView.swift:565.
- The existing angles already implement the needed shot grammar:
  `.broadcast` = K0 wide (`y+11, z+15`, FOV 55, lines 728-742),
  `.actionCloseUp` = K1/K3 close (0.32× offsets, FOV 22, lines 744-758),
  `.cinematicPan` = K2 orbit (radius 8.5, `orbitAngle += delta * 0.22`,
  lines 760-777).

Implementation: add a `DunkCinematicDirector` that observes `DunkPhase`
transitions and calls `triggerTemporaryCameraCut`:

```swift
func phaseChanged(_ phase: DunkPhase, state: DunkContestState) {
    switch phase {
    case .approach:  triggerTemporaryCameraCut(to: .broadcast, duration: 10)   // K0
    case .launch:    triggerTemporaryCameraCut(to: .actionCloseUp, duration: 1.0) // K1
    case .airborne:  triggerTemporaryCameraCut(to: .cinematicPan,             // K2
                         duration: state.maxAirTime)
                     // 30° sweep: run orbit at 0.5236 rad over the airborne window
    case .landing:   triggerTemporaryCameraCut(to: .actionCloseUp, duration: 0.4) // K3
                     scene.rootNode.runAction(.sequence([                     // slow-mo
                         .customAction(duration: 0) { _,_ in scnView.sceneTime = 0 },
                         .run { _ in scene.physicsWorld.speed = 0.3 },        // 0.3×
                         .wait(duration: 0.4 * 0.3),
                         .run { _ in scene.physicsWorld.speed = 1.0 },
                     ]))
    case .scored:    triggerTemporaryCameraCut(to: .broadcast, duration: 2.5) // K4
    default: break
    }
}
```

The mid-air character swap seam pairs with this: the scene host swaps the
dunker for the retargeted mocap dunk clip while airborne via
`setDunkClipActive(_:)` driven by the `isMidAir` flag in `updateUIView`
(GameSceneHostView.swift:125/185 on the PR #111 3D-venue branch;
`Coordinator.isMidAir` + `dunkClipNode` fields). K2/K3 frame that clip node
(`"dunkerClip"`), not the hidden gameplay avatar.

### Option B: explicit SCNAction camera spline

For a fully authored path, run a one-shot `SCNAction` sequence on a
dedicated `cinematicCamera` node and swap `scnView.pointOfView` for the
duration:

```swift
let spline: [SCNAction] = [
    .move(to: k0, duration: 0.0),                       // parked wide
    .move(to: k1, duration: approachDur).eased(.easeIn),// dolly-in on approach
    .move(to: k2Arc, duration: maxAirTime * 0.4),       // rise to apex orbit
    .rotateBy(x: 0, y: .pi/6, z: 0, duration: maxAirTime * 0.3), // 30° orbit
    .move(to: k3, duration: 0.25),                      // dive to rim
]
cinematicCamera.runAction(.sequence(spline))
scnView.pointOfView = cinematicCamera        // restore on .scored (K4 cut)
```

Slow-mo uses the same `physicsWorld.speed = 0.3` + 400 ms wall-clock ramp;
`SCNTransaction` with `animationDuration = 0.12` smooths the FOV kicks.
Option B is only warranted if the 30° apex orbit needs exact framing that
the `.cinematicPan` constant-rate orbit cannot deliver.

### Cue playback

On each sync point, resolve the logical name from the event's `av_cues`
(or `AV_CUE_TABLE` fallback for offline play) through the audio event map,
then `SCNAudioSource` → `SCNAudioPlayer` on the rim/dunker node for
positional audio; `SCNParticleSystem` for `particle_burst`/`particle_soft`;
`UIImpactFeedbackGenerator(style:)` for `light/medium/heavy`. Unknown or
missing cues are skipped silently (map fallback policy).
