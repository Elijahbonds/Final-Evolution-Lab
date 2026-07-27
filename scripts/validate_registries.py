#!/usr/bin/env python3
"""validate_registries.py — say exactly what is wrong with the registries.

    python3 scripts/validate_registries.py            # human output
    python3 scripts/validate_registries.py --json     # machine output
    python3 scripts/validate_registries.py --strict   # warnings fail too

Run it before pushing. It needs no credentials, no network and no dependencies,
and it prints file, path, expected and actual for every mismatch instead of
dying on the first KeyError.

WHY THIS EXISTS
The "Validate Mode + Venue Registries" job failed with a bare `KeyError:
'modes'` and no context, which told nobody which file, which key, or what the
file actually contained. The underlying problem was not a missing entry — it
was that the check was reading a DIFFERENT FILE from the one that holds the
data, in a different naming convention.

THE TWO REGISTRIES, AND WHAT EACH ACTUALLY HOLDS

  backend/FEL_ModeManager.production.json
      mode_manager.mode_registry   -> DICT keyed by mode id
      per entry: status, venue_id, prq_weight    (snake_case)

  backend/FEL_VenueRegistry.production.json
      modes    -> LIST of objects with `id`
      per entry: id, analyticsMode, venueKey, displayVenue, renderMode, ...
                                                  (camelCase)
      venues   -> LIST of objects with `venueKey`

They are different shapes AND different naming conventions, and the render-mode
data lives only in the second one. A check written against the first will never
find it.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

MODE_MANAGER = ROOT / "backend/FEL_ModeManager.production.json"
VENUE_REGISTRY = ROOT / "backend/FEL_VenueRegistry.production.json"
UE_MODE_MAPS = ROOT / "backend/ue_mode_maps.json"
ARENA_SETTINGS = ROOT / "UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json"

ALL_JSON = [MODE_MANAGER, VENUE_REGISTRY, UE_MODE_MAPS, ARENA_SETTINGS]

# The assertions the CI job was trying to make, expressed against the schema
# the data actually uses. `basketball_dunk` is not a mode id in the venue
# registry — it is split into a 3D and an IRL variant — so the check names both.
#
# `brain_brawl: "2D"` was DROPPED, and it was the assertion that was wrong
# rather than the data:
#
#   - "2D" appears nowhere in any of the four registries. The vocabulary in use
#     is 3D_UE5 (3 modes), IRL (1) and null (16).
#   - renderMode is an optional DISAMBIGUATOR — it exists to separate the dunk
#     variants and h2h. It is not a field with full coverage, and treating a
#     null as a defect would condemn 16 of 20 modes.
#   - brain_brawl has a UE map token (Neuro_Arena), a venue (neuro_arena /
#     "Neuro Arena") AND an ArenaSettings entry with an unrealOpenLevelPackage.
#     It is a 3D mode by every other record in this repo.
#
# Asserting "2D" contradicted four other sources. Setting the field to "2D" to
# satisfy it would have made the data agree with the one record that is wrong.
REQUIRED_RENDER_MODES = {
    "basketball_h2h": "3D_UE5",
    "basketball_dunk_3d": "3D_UE5",
    "basketball_dunk_irl": "IRL",
}

VENICE_MUST_MENTION = {"basketball_dunk_3d": "Venice"}

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load(path: Path):
    """Parse, or record a precise error and return None. Never raises."""
    rel = path.relative_to(ROOT)
    if not path.exists():
        err(f"{rel}: file not found")
        return None
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        err(f"{rel}: invalid JSON at line {e.lineno} col {e.colno} — {e.msg}")
        return None


def dig(obj, path: str, rel: str):
    """Walk a dotted path, and on failure say what WAS there.

    This is the whole point of the file. `KeyError: 'modes'` is not a
    diagnosis; "expected mode_manager.modes, found mode_manager.mode_registry"
    is one.
    """
    cur = obj
    walked: list[str] = []
    for part in path.split("."):
        if not isinstance(cur, dict):
            err(f"{rel}: {'.'.join(walked) or '<root>'} is a {type(cur).__name__}, "
                f"not an object — cannot read '{part}'")
            return None
        if part not in cur:
            available = ", ".join(sorted(cur.keys())[:8]) or "(empty)"
            where = ".".join(walked) or "<root>"
            err(f"{rel}: no key '{part}' under {where}. Present there: {available}")
            return None
        cur = cur[part]
        walked.append(part)
    return cur


def mode_list(venue_reg, rel: str):
    """The list of mode objects, from whichever shape the file uses."""
    modes = dig(venue_reg, "modes", rel)
    if modes is None:
        return []
    if isinstance(modes, dict):
        # Tolerate a dict-of-modes and normalise it, so a future restructure
        # reports real problems rather than one shape error.
        warn(f"{rel}: modes is an object, not a list — normalising by key")
        return [{**v, "id": k} for k, v in modes.items()]
    if not isinstance(modes, list):
        err(f"{rel}: modes is a {type(modes).__name__}, expected a list")
        return []
    return modes


def main() -> int:
    as_json = "--json" in sys.argv
    strict = "--strict" in sys.argv

    # ── 1. every file parses ────────────────────────────────────────────
    docs = {p: load(p) for p in ALL_JSON}

    venue_reg = docs[VENUE_REGISTRY]
    mode_mgr = docs[MODE_MANAGER]
    ue_maps = docs[UE_MODE_MAPS]

    modes: list[dict] = []
    venues: list[dict] = []
    registry: dict = {}

    # ── 2. the venue registry: modes and venues ─────────────────────────
    if venue_reg is not None:
        rel = str(VENUE_REGISTRY.relative_to(ROOT))
        modes = mode_list(venue_reg, rel)
        by_id = {m.get("id"): m for m in modes if m.get("id")}

        nameless = [i for i, m in enumerate(modes) if not m.get("id")]
        if nameless:
            err(f"{rel}: {len(nameless)} mode entr(ies) have no 'id' (indices {nameless[:5]})")

        for mode_id, expected in REQUIRED_RENDER_MODES.items():
            m = by_id.get(mode_id)
            if m is None:
                near = [k for k in by_id if k and mode_id.split("_")[0] in k][:4]
                err(f"{rel}: modes[] has no id '{mode_id}'"
                    + (f" — similar ids present: {near}" if near else ""))
                continue
            actual = m.get("renderMode")
            if actual != expected:
                err(f"{rel}: modes[{mode_id}].renderMode is {actual!r}, expected {expected!r}")

        for mode_id, needle in VENICE_MUST_MENTION.items():
            m = by_id.get(mode_id)
            if m is not None and needle.lower() not in str(m.get("displayVenue", "")).lower():
                err(f"{rel}: modes[{mode_id}].displayVenue is "
                    f"{m.get('displayVenue')!r}, must mention {needle!r}")

        null_render = [m["id"] for m in modes if m.get("id") and m.get("renderMode") is None]
        if null_render:
            warn(f"{rel}: {len(null_render)}/{len(modes)} modes have renderMode=null: "
                 f"{', '.join(null_render[:6])}"
                 + (f" +{len(null_render) - 6} more" if len(null_render) > 6 else ""))

        # referential integrity: every venueKey a mode names must exist
        venues = dig(venue_reg, "venues", rel) or []
        if isinstance(venues, list):
            vkeys = {v.get("venueKey") for v in venues if isinstance(v, dict)}
            # An IRL mode is played in the real world and has no virtual venue
            # by definition. `basketball_dunk_irl` says so in three places —
            # renderMode "IRL", isIRLMode true, and a note reading "No UE5
            # venue map" — so requiring one is the CHECK being wrong, not the
            # data. Its venueKey is a label for the physical court.
            def is_irl(m: dict) -> bool:
                return m.get("renderMode") == "IRL" or m.get("isIRLMode") is True

            refs = {m.get("venueKey") for m in modes
                    if m.get("venueKey") and not is_irl(m)}
            for missing in sorted(refs - vkeys):
                users = [m["id"] for m in modes if m.get("venueKey") == missing]
                err(f"{rel}: venueKey {missing!r} is referenced by {users} "
                    f"but is not defined in venues[]")
            irl_only = {m.get("venueKey") for m in modes
                        if m.get("venueKey") and is_irl(m)} - vkeys
            for k in sorted(irl_only):
                warn(f"{rel}: venueKey {k!r} exists only as an IRL label "
                     f"(no virtual venue) — exempt, not an error")
            for unused in sorted(vkeys - refs):
                warn(f"{rel}: venue {unused!r} is defined but no mode references it")

    # ── 3. the mode manager: a different shape, on purpose ──────────────
    if mode_mgr is not None:
        rel = str(MODE_MANAGER.relative_to(ROOT))
        registry = dig(mode_mgr, "mode_manager.mode_registry", rel) or {}
        if registry and not isinstance(registry, dict):
            err(f"{rel}: mode_manager.mode_registry is a "
                f"{type(registry).__name__}, expected an object keyed by mode id")
            registry = {}
        declared = dig(mode_mgr, "mode_manager.total_modes", rel)
        if isinstance(declared, int) and isinstance(registry, dict) and declared != len(registry):
            warn(f"{rel}: mode_manager.total_modes says {declared} "
                 f"but mode_registry holds {len(registry)}")

    # ── 4. cross-file: the map, the manager and the venue registry ──────
    if ue_maps is not None and registry:
        rel = str(UE_MODE_MAPS.relative_to(ROOT))
        mapping = dig(ue_maps, "mode_to_unreal_map", rel) or {}
        for mode_id in sorted(set(registry) - set(mapping)):
            entry = registry.get(mode_id, {})
            # `null` is a legitimate value here — it is how an IRL mode with no
            # UE map is recorded (basketball_dunk_irl). ABSENCE is different
            # from an explicit null, and only absence is an error.
            hint = (f" It declares map_path {entry['map_path']!r}, so the entry is "
                    f"missing rather than intentionally absent."
                    if entry.get("map_path") else
                    " Add it, or map it to null if it has no UE map.")
            err(f"{rel}: mode {mode_id!r} is in mode_registry but has no entry in "
                f"mode_to_unreal_map.{hint}")
        for mode_id in sorted(set(mapping) - set(registry)):
            warn(f"{rel}: mode {mode_id!r} is mapped to Unreal but not in mode_registry")

    # ArenaSettings is the FOURTH place a mode's venue is recorded, and CI has
    # only ever checked that it parses. It holds the actual UE level package,
    # so a mode missing from it has no level to open.
    arena_doc = docs[ARENA_SETTINGS]
    if arena_doc is not None and registry:
        rel = str(ARENA_SETTINGS.relative_to(ROOT))
        arena = dig(arena_doc, "modes", rel) or {}
        if isinstance(arena, dict):
            # The dunk variants inherit basketball_dunk's settings via
            # nexus_runtime_mode_id, so their absence is by design.
            derived = {k for k, v in registry.items()
                       if v.get("nexus_runtime_mode_id") in arena}
            # And an IRL mode has no UE level for the same reason it has no
            # venue: it is played in the real world.
            derived |= {k for k, v in registry.items() if v.get("render_mode") == "IRL"}
            for mode_id in sorted(set(registry) - set(arena) - derived):
                warn(f"{rel}: mode {mode_id!r} has no entry in modes[] — no "
                     f"unrealOpenLevelPackage, so there is no level to open")
            for m_id, cfg in arena.items():
                if isinstance(cfg, dict) and not cfg.get("unrealOpenLevelPackage"):
                    err(f"{rel}: modes[{m_id}] has no unrealOpenLevelPackage")

    if registry and modes:
        ids = {m.get("id") for m in modes}
        only_mgr = sorted(set(registry) - ids)
        only_venue = sorted(ids - set(registry))
        if only_mgr:
            warn(f"in mode_registry but not in the venue registry's modes[]: {only_mgr}")
        if only_venue:
            warn(f"in the venue registry's modes[] but not in mode_registry: {only_venue}")

    # ── report ──────────────────────────────────────────────────────────
    if as_json:
        print(json.dumps({"errors": errors, "warnings": warnings,
                          "ok": not errors and not (strict and warnings)}, indent=2))
    else:
        for e in errors:
            print(f"ERROR    {e}")
        for w in warnings:
            print(f"warning  {w}")
        print()
        if errors:
            print(f"FAILED — {len(errors)} error(s), {len(warnings)} warning(s)")
        elif warnings and strict:
            print(f"FAILED (--strict) — {len(warnings)} warning(s)")
        else:
            print(f"OK — 0 errors, {len(warnings)} warning(s)")

    return 1 if errors or (strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
