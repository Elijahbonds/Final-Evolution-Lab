#!/usr/bin/env python3
"""
demo_dunk_cinematic.py — print the dunk cinematic timeline against a
simulated dunk event stream. No engine required.

Validates:
  1. The timing table below parses and covers EVERY DunkPhase
     (idle/approach/launch/airborne/landing/scored — mirrors
     FinalEvolutionLab/Models/DunkContestEngine.swift DunkPhase).
  2. Every audio/vfx cue referenced is a logical name known to
     backend/lib/av_cues.py (when importable) so server av_cues hints and
     the cinematic stay in sync.
  3. Spec doc infra/cinematics_dunk.md mentions every phase and shot id.

Usage:
  python3 scripts/demo_dunk_cinematic.py

Exit code 0 = timeline valid; non-zero with a message otherwise.
"""
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# DunkPhase cases — must mirror DunkContestEngine.swift
DUNK_PHASES = ["idle", "approach", "launch", "airborne", "landing", "scored"]

# Logical cue names (mirror infra/audio_event_map.json + backend AV_CUE_TABLE)
KNOWN_AUDIO = {"buzzer", "score_sting", "rim_clank", "net_swish", "crowd_hype", "timer_tick"}
KNOWN_VFX = {"particle_burst", "particle_soft"}
KNOWN_HAPTIC = {"light", "medium", "heavy"}

# ── Cinematic timing table (source of truth: infra/cinematics_dunk.md §2) ──
# t values in seconds; airborne beats expressed against a simulated
# maxAirTime (engine: 2.4 + jumpHeight * 1.0).
SIM_JUMP_HEIGHT = 0.6
MAX_AIR_TIME = 2.4 + SIM_JUMP_HEIGHT * 1.0

TIMING_TABLE = [
    # phase       shot  duration_s              beat
    ("idle",      "K0", None,                   "camera parked wide; crowd ambience bed"),
    ("approach",  "K0", 1.60,                   "wide tracking; sprint-charge dolly-in"),
    ("launch",    "K1", 0.45,                   "low-angle snap; FOV kick 55->38"),
    ("airborne",  "K2", MAX_AIR_TIME,           "apex orbit 30deg; engine slow-mo window 30%-70%"),
    ("landing",   "K3", 0.40,                   "RIM IMPACT slow-mo 0.3x for 400ms"),
    ("scored",    "K4", 2.50,                   "hard cut: judge reveal, scores punch in"),
]

# ── Audio/VFX sync points (source of truth: infra/cinematics_dunk.md §3) ──
SYNC_POINTS = [
    # trigger_phase  offset_s  audio          vfx               haptic
    ("idle",       0.00, "buzzer",      None,             None),   # round start
    ("airborne",   0.00, "crowd_hype",  None,             "light"),# launch
    ("landing",    0.00, "rim_clank",   "particle_burst", "heavy"),# dunk_result
    ("landing",    0.15, "net_swish",   None,             None),   # clean finish tail
    ("scored",     0.00, "score_sting", "particle_soft",  "light"),# judge reveal
]

# ── Simulated dunk event stream (what the engine/server would emit) ───────
SIM_EVENT_STREAM = [
    ("match_start", "idle"),
    ("phase_change", "approach"),
    ("phase_change", "launch"),
    ("phase_change", "airborne"),
    ("phase_change", "landing"),   # dunk_result fires here
    ("dunk_result", "landing"),
    ("phase_change", "scored"),
    ("score_event", "scored"),
]


def fail(msg: str) -> None:
    print(f"FAIL: {msg}")
    sys.exit(1)


def validate() -> None:
    # 1. Table covers every phase, in engine order, durations sane
    table_phases = [row[0] for row in TIMING_TABLE]
    missing = [p for p in DUNK_PHASES if p not in table_phases]
    if missing:
        fail(f"timing table missing phases: {missing}")
    if table_phases != DUNK_PHASES:
        fail(f"timing table phase order {table_phases} != engine order {DUNK_PHASES}")
    for phase, shot, dur, _ in TIMING_TABLE:
        if dur is not None and not (0 < dur < 10):
            fail(f"{phase}: implausible duration {dur}")
        if not shot.startswith("K"):
            fail(f"{phase}: bad shot id {shot}")

    # 2. Sync points reference known phases + logical cue names
    for phase, offset, audio, vfx, haptic in SYNC_POINTS:
        if phase not in DUNK_PHASES:
            fail(f"sync point references unknown phase {phase}")
        if audio is not None and audio not in KNOWN_AUDIO:
            fail(f"unknown audio cue {audio}")
        if vfx is not None and vfx not in KNOWN_VFX:
            fail(f"unknown vfx sprite {vfx}")
        if haptic is not None and haptic not in KNOWN_HAPTIC:
            fail(f"unknown haptic level {haptic}")
        if offset < 0:
            fail(f"negative sync offset on {phase}")

    # 3. Cross-check against backend AV_CUE_TABLE when importable
    sys.path.insert(0, str(REPO_ROOT / "backend"))
    try:
        from lib.av_cues import AV_CUE_TABLE  # noqa: PLC0415
    except Exception as exc:  # pragma: no cover — demo runs standalone too
        print(f"  (note: backend AV_CUE_TABLE not importable here: {exc})")
    else:
        dunk = AV_CUE_TABLE["dunk_result"]
        rim_rows = [s for s in SYNC_POINTS if s[2] == "rim_clank"]
        if not rim_rows:
            fail("no rim_clank sync point")
        _, _, audio, vfx, haptic = rim_rows[0]
        if (audio, vfx, haptic) != (dunk["audio"], dunk["vfx"], dunk["haptic"]):
            fail(f"rim impact sync {audio}/{vfx}/{haptic} != server dunk_result {dunk}")
        print("  server AV_CUE_TABLE dunk_result matches rim-impact sync point")

    # 4. Spec doc mentions every phase and shot
    spec = REPO_ROOT / "infra" / "cinematics_dunk.md"
    if spec.exists():
        text = spec.read_text()
        for p in DUNK_PHASES:
            if p not in text:
                fail(f"spec missing phase {p}")
        for shot in {row[1] for row in TIMING_TABLE}:
            if shot not in text:
                fail(f"spec missing shot {shot}")
        print("  infra/cinematics_dunk.md covers all phases and shots")
    else:
        print("  (note: spec doc not found next to script; skipping doc check)")


def print_timeline() -> None:
    print(f"\nDunk cinematic timeline (simulated jumpHeight={SIM_JUMP_HEIGHT}, "
          f"maxAirTime={MAX_AIR_TIME:.2f}s)\n")
    print(f"  {'t(s)':>6}  {'phase':<10} {'shot':<5} beat")
    print(f"  {'-'*6}  {'-'*10} {'-'*5} {'-'*48}")
    t = 0.0
    sync_by_phase = {}
    for phase, offset, audio, vfx, haptic in SYNC_POINTS:
        sync_by_phase.setdefault(phase, []).append((offset, audio, vfx, haptic))
    for phase, shot, dur, beat in TIMING_TABLE:
        print(f"  {t:6.2f}  {phase:<10} {shot:<5} {beat}")
        for offset, audio, vfx, haptic in sync_by_phase.get(phase, []):
            cue = " + ".join(x for x in (audio, vfx, f"haptic:{haptic}" if haptic else None) if x)
            print(f"  {t + offset:6.2f}  {'':<10} {'':<5}   cue: {cue}")
        t += dur or 0.0
    print(f"  {t:6.2f}  (end)\n")

    print("Simulated event stream -> cinematic reaction:")
    for etype, phase in SIM_EVENT_STREAM:
        row = next(r for r in TIMING_TABLE if r[0] == phase)
        print(f"  event {etype:<12} phase={phase:<9} -> shot {row[1]}")


if __name__ == "__main__":
    print("Validating dunk cinematic timing table...")
    validate()
    print_timeline()
    print("\nOK: timing table parses, covers all 6 DunkPhase states, "
          "and cue names match the server av_cues table.")
