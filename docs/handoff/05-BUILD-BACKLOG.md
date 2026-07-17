# 05 — BUILD BACKLOG (ordered)

Epic IDs are stable — reference them in every batch manifest. Acceptance criteria live
in the linked docs; this file sequences them.

## PHASE A — M13: make the existing modes feel right (active milestone)

| ID | Epic | Spec | Notes |
|----|------|------|-------|
| A1 | Global AnimationDriver — every input fires a clip ≤100 ms | m13-01 §A | P0. Unblocks everything. |
| A2 | Facing/orientation system (move-vector + engagement targets) | m13-01 §B | P0. Ship with A1. |
| A3 | Camera rig with framing/ground/occlusion constraints | m13-03 | P1. Reusable rig, then per-mode presets. |
| A4 | Board sports ground: lit/opaque surface, contact shadows, rider grounding, elevated cam | m13-05 | P1. Depends A3. |
| A5 | Street Football: skinned moving defenders, evade kit, ready gate, survivable ramp, field dressing | m13-06 | P1. Depends A1/A2. |
| A6 | Dunk Contest: ball-in-hand pipeline, watchable flight+slam, distinct style clips, skinned rival turns, environment fix | m13-04 | P2. Depends A1–A3. |
| A7 | Karate: engagement + strike kit, honest wave logic, HUD, de-occlusion | m13-07 | P2. Depends A1–A3. |
| A8 | QA pass on full checklist | m13-08 | Exit criteria for Phase A. |

## PHASE B — The Console Shell (the rescope centerpiece)

| ID | Epic | Spec | Notes |
|----|------|------|-------|
| B1 | **Input bus + ControllerOverlay component** (dual sticks, d-pad, ABXY, bumpers/analog triggers, SELECT/START; portrait DS layout + landscape Switch layout; verb-labeled buttons) | 03 §2.1–2.3, 2.5 | THE priority after A1/A2. Supersedes m13-02's overlay. |
| B2 | Per-mode control configs for all 22 modes | 03 §2.4, 06 §4 | Data files + integration in each mode. |
| B3 | Keyboard + **Gamepad API** adapters onto the bus; haptics adapter | 03 §2.3 | Overlay auto-hide on pad connect. |
| B4 | **Console frame/bezel**: HUD docked in bezel, HOME/pause sheet, camera toggle | 03 §1.3 | Applies to every `/play/*` and `/try`. |
| B5 | **Launch/eject ritual**: cartridge insert, boot splash, READY gate, 3-2-1; eject to rail | 03 §1.2 | Ready gates land here app-wide. |
| B6 | **Console home**: cartridge rail with stick/d-pad focus nav, card flip stats, venue skybox; shelf + dock re-skin | 03 §1.1 | Reuses existing hub data. |
| B7 | Guest `/try` gets full shell (thumbs-only funnel) | 03 §3 | Acquisition-critical. |

## PHASE C — Coaching & fitness depth

| ID | Epic | Notes |
|----|------|-------|
| C1 | Coach tab v1: PRQ breakdown, daily plan (mode playlist as "training card"), streak mechanics tied to season XP | Vision 01 pillar 2. |
| C2 | Gym cartridges: Iron Paradise + Beach Sprint as first-class shell modes with rhythm/hold controller configs | Reuse B1. |
| C3 | PRQ engine tuning: per-mode PRQ Δ weights server-side; visible "why it moved" receipt on result screen | Contracts 06 §2. |
| C4 | Story tab v1: The Nexus Initiative arc framing the library (Sanctum → venues → Glitch Boss) | Narrative wrapper. |

## PHASE D — Library breadth & polish (post-shell)

| ID | Epic | Notes |
|----|------|-------|
| D1 | Remaining mode deep passes (tennis, penalty, derby, sprint, big air, slalom, nexus) to A-phase feel bar | Same five root-cause checklists. |
| D2 | Rival/multiplayer texture: ghost replays for Signature Challenge; async CHALLENGE A FRIEND deep links | Builds on existing meta. |
| D3 | Cosmetic economy: avatar gear + controller shells in Luma Venice Shop | Shell skinnability from 03 §2.5. |
| D4 | Sound design pass: boot/insert/eject, UI focus ticks, per-venue beds, impact stingers | Feel multiplier. |
| D5 | Performance: 60 fps mid-range phones; texture/asset budget audit | Ship gate. |

## Sequencing rules
- A1+A2 land before or with the first B batch (the shell is pointless if inputs don't
  animate).
- B1 ships in ONE mode first (Dunk — it's the funnel), config-ready for the rest;
  B2 rolls the remaining modes in ≤3 follow-up batches.
- Nothing in C/D starts while any P0/P1 of Phase A is open.
- Every batch re-runs the m13-08 checklist on touched modes.
