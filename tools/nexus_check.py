#!/usr/bin/env python3
"""nexus_check.py — the static gate for NEXUS (the native Swift engine).

    python3 tools/nexus_check.py            # everything
    python3 tools/nexus_check.py --json     # machine-readable, for nexus_agent.mjs

WHY THIS EXISTS
Nexus is ~159 Swift files that NOTHING in this environment has ever
type-checked: the real build needs macOS + Xcode, and `green_check.sh` has
been honestly reporting it as SKIPPED ever since M68. A skip is the right
call — but "we cannot compile it" is not the same as "we can learn nothing
about it." Every check below runs on Linux, in under a second, and each one
was written because it caught a real defect in this repo on first run:

  · brace balance     → FootballGameView.swift was over-closed by one. That
                        file cannot compile, and nothing was reporting it.
  · SPM nesting       → a Package.swift sits inside the app's synchronized
                        root group, so Xcode compiles the package manifest
                        as app source.
  · imports vs links  → `import FirebaseDataConnect` in app-target files
                        with no such product linked to the app target.
  · registry ↔ disk   → the venue registry maps 20 modes to scene files;
                        18 of them do not exist.

None of these need a compiler. All of them break the build.

EXIT CODE: 0 when no ERRORs. Warnings never fail the gate.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

errors: list[dict] = []
warnings: list[dict] = []


def err(check: str, msg: str, where: str = "") -> None:
    errors.append({"check": check, "message": msg, "where": where})


def warn(check: str, msg: str, where: str = "") -> None:
    warnings.append({"check": check, "message": msg, "where": where})


# ── Swift brace balance ───────────────────────────────────────────────────
# A hand-written tokenizer, because the alternative — counting '{' and '}'
# with a regex — is wrong in ways that matter here. It must understand:
#   · // and /* */ comments
#   · "..." and """...""" strings, with escapes
#   · \(...) INTERPOLATION, which re-enters code and can contain braces AND
#     nested strings:  Text("& \(x >= 90 ? "GOAL" : "\(y)")")
#     That exact line is in FootballGameView.swift, and a tokenizer that
#     treats interpolation as opaque string content mis-tracks state from
#     there onward.
def swift_depth(src: str) -> int:
    i, n, depth, state = 0, len(src), 0, "code"
    interp: list[str] = []
    while i < n:
        c, c2, c3 = src[i], src[i:i + 2], src[i:i + 3]
        if state == "code":
            if c3 == '"""':
                state = "ml"; i += 3; continue
            if c2 == "//":
                while i < n and src[i] != "\n":
                    i += 1
                continue
            if c2 == "/*":
                state = "blk"; i += 2; continue
            if c == '"':
                state = "str"; i += 1; continue
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
            elif c == ")" and interp:
                interp.pop(); state = "str"
            i += 1; continue
        if state == "str":
            if c2 == "\\(":
                interp.append("p"); state = "code"; i += 2; continue
            if c == "\\":
                i += 2; continue
            if c == '"':
                state = "code"; i += 1; continue
            i += 1; continue
        if state == "ml":
            if c == "\\":
                i += 2; continue
            if c3 == '"""':
                state = "code"; i += 3; continue
            i += 1; continue
        if state == "blk":
            if c2 == "*/":
                state = "code"; i += 2; continue
            i += 1; continue
    return depth


def product_swift_files() -> list[str]:
    """Swift files that are actually PRODUCT code.

    Deliberately excludes `.claude/` — it holds abandoned agent worktrees
    with 1266 .swift files in them. Counting those is how `green_check.sh`
    came to describe Nexus as '1425 sources'; the real figure is ~159, and
    an inflated number in a report is a small lie that makes the honest
    parts harder to trust.
    """
    out: list[str] = []
    for pat in ("FinalEvolutionLab/**/*.swift", "FinalEvolutionLabTests/**/*.swift",
                "FinalEvolutionLabUITests/**/*.swift", "infra/**/*.swift"):
        out += glob.glob(os.path.join(ROOT, pat), recursive=True)
    return sorted(p for p in out if ".claude" not in p)


def rel(p: str) -> str:
    return os.path.relpath(p, ROOT)


def check_braces(files: list[str]) -> None:
    for f in files:
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                d = swift_depth(fh.read())
        except OSError as e:
            warn("braces", f"unreadable: {e}", rel(f)); continue
        if d != 0:
            err("braces",
                f"brace imbalance {d:+d} — this file cannot compile "
                f"({'extra closer(s)' if d < 0 else 'unclosed block(s)'})",
                rel(f))


# ── Xcode target composition ──────────────────────────────────────────────
SYNC_GROUP_RE = re.compile(
    r"isa = PBXFileSystemSynchronizedRootGroup;.*?path = ([A-Za-z0-9_./-]+);", re.S)


def pbxproj_path() -> str | None:
    hits = glob.glob(os.path.join(ROOT, "*.xcodeproj", "project.pbxproj"))
    return hits[0] if hits else None


def check_xcode(files: list[str]) -> None:
    pbx = pbxproj_path()
    if not pbx:
        warn("xcode", "no .xcodeproj/project.pbxproj found — skipping target checks")
        return
    with open(pbx, encoding="utf-8", errors="replace") as fh:
        proj = fh.read()

    sync_paths = SYNC_GROUP_RE.findall(proj)
    has_exceptions = "PBXFileSystemSynchronizedBuildFileExceptionSet" in proj

    # Which products are actually linked to a target?
    linked = set(re.findall(r"productName = ([A-Za-z0-9_]+);", proj))

    # 1. An SPM package nested inside a synchronized root group is compiled
    #    TWICE: once as a package product, once as loose app sources. And its
    #    Package.swift — which imports PackageDescription, a module that only
    #    exists in the manifest environment — is compiled as app source.
    for manifest in glob.glob(os.path.join(ROOT, "**", "Package.swift"), recursive=True):
        if ".claude" in manifest:
            continue
        r = rel(manifest)
        inside = next((p for p in sync_paths if r.startswith(p + os.sep)), None)
        if inside and not has_exceptions:
            err("xcode",
                f"Package.swift sits inside the synchronized root group '{inside}', which has NO "
                "build-file exception set. Xcode compiles every .swift under that folder into the "
                "app target, so this manifest is compiled as app source (it imports "
                "PackageDescription, unavailable in an app target) and the package's Sources are "
                "compiled twice — once in the package module, once loose in the app. Add a "
                "PBXFileSystemSynchronizedBuildFileExceptionSet excluding this directory, or move "
                "the package outside the synchronized folder.",
                r)

    # 2. Modules imported by app-target code must be linked to a target.
    #    Swift does not transitively re-export a dependency's dependency, so
    #    depending on a local package that depends on X does NOT let app code
    #    `import X`.
    stdlib = {
        "Foundation", "SwiftUI", "UIKit", "Combine", "OSLog", "SceneKit", "SpriteKit",
        "QuartzCore", "CoreGraphics", "CoreMotion", "AVFoundation", "AVKit", "HealthKit",
        "PhotosUI", "XCTest", "Testing", "ObjectiveC", "MultipeerConnectivity", "Darwin",
        "Dispatch", "CoreLocation", "MapKit", "StoreKit", "WebKit", "Network", "Charts",
        "RealityKit", "ARKit", "Metal", "MetalKit", "Accelerate", "CryptoKit", "Security",
        "UserNotifications", "GameKit", "CoreData", "SwiftData", "Observation", "PackageDescription",
    }
    # local package products are legitimately linkable
    imports: dict[str, list[str]] = {}
    for f in files:
        # only files that are actually in a synchronized (compiled) folder
        r = rel(f)
        if not any(r.startswith(p + os.sep) for p in sync_paths):
            continue
        with open(f, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = re.match(r"^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)", line)
                if m:
                    imports.setdefault(m.group(1), []).append(r)

    for mod, users in sorted(imports.items()):
        if mod in stdlib or mod in linked:
            continue
        err("xcode",
            f"`import {mod}` appears in {len(users)} compiled file(s) but '{mod}' is not among the "
            f"products linked to any target ({', '.join(sorted(linked)) or 'none'}). Swift does not "
            "re-export a dependency's dependencies, so this will not resolve at build time. Either "
            "add the product to the app target, or drop the import if the symbols come from another "
            "module that is linked.",
            users[0] + (f" (+{len(users) - 1} more)" if len(users) > 1 else ""))

    # 3. Duplicate TOP-LEVEL type names inside the compiled set are a
    #    redeclaration error. `private` types are file-scoped and fine.
    decl_re = re.compile(
        r"^(?!.*\b(?:private|fileprivate)\b)"
        r"(?:public |internal |final |@\w+\s+)*(struct|class|enum|protocol|actor)\s+([A-Za-z_]\w*)")
    seen: dict[str, list[str]] = {}
    for f in files:
        r = rel(f)
        if not any(r.startswith(p + os.sep) for p in sync_paths):
            continue
        with open(f, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = decl_re.match(line)
                if m:
                    seen.setdefault(m.group(2), [])
                    if r not in seen[m.group(2)]:
                        seen[m.group(2)].append(r)
    for name, where in sorted(seen.items()):
        if len(where) > 1:
            err("xcode", f"type '{name}' declared at top level in {len(where)} compiled files — "
                         "redeclaration error", ", ".join(where))


# ── Nexus registries ──────────────────────────────────────────────────────
def check_nexus_registry() -> None:
    reg_p = os.path.join(ROOT, "NexusStarter/BasketballGame/Config/VenueRegistry.nexus.json")
    proj_p = os.path.join(ROOT, "NexusStarter/NexusProject.json")
    if not os.path.exists(reg_p):
        warn("nexus", "no VenueRegistry.nexus.json — skipping registry checks")
        return

    with open(reg_p, encoding="utf-8") as fh:
        reg = json.load(fh)
    scene_dir = os.path.join(ROOT, "NexusStarter/BasketballGame/Scenes")

    missing = []
    for v in reg.get("venues", []):
        s = v.get("scene")
        if not s:
            continue
        if not os.path.exists(os.path.join(scene_dir, s)):
            missing.append((v.get("modeId"), s))

    if missing:
        # WARN, not ERROR, and the distinction is the whole point: nothing in
        # the Swift code reads these descriptors today (see below), so a
        # missing file breaks nothing at runtime. It becomes an ERROR the
        # moment a loader exists — which is exactly when this message stops
        # being noise and starts being the bug report.
        warn("nexus",
             f"{len(missing)} of {len(reg.get('venues', []))} venues reference scene descriptors "
             f"that do not exist: {', '.join(m for m, _ in missing)}. Harmless while no loader "
             "reads them; a hard failure the day one does.",
             "NexusStarter/BasketballGame/Config/VenueRegistry.nexus.json")

    # Does anything actually LOAD these descriptors?
    swift_src = ""
    for f in product_swift_files():
        with open(f, encoding="utf-8", errors="replace") as fh:
            swift_src += fh.read()
    if not re.search(r"\.nexus\.json|NexusStarter", swift_src):
        warn("nexus",
             "no Swift code references NexusStarter or any .nexus.json descriptor, yet "
             "NexusProject.json states 'All scenes are JSON-defined NexusScene descriptors'. "
             "Scenes are actually built by NexusScene.default(for:) in code. The descriptors are "
             "orphaned data — either wire the loader or stop describing the architecture as "
             "data-driven.",
             "NexusStarter/NexusProject.json")

    # startScene must exist
    if os.path.exists(proj_p):
        with open(proj_p, encoding="utf-8") as fh:
            proj = json.load(fh)
        start = proj.get("startScene")
        ids = {v.get("modeId") for v in reg.get("venues", [])}
        if start and start not in ids:
            err("nexus", f"startScene '{start}' is not a modeId in the venue registry", "NexusProject.json")


def check_registry_sync() -> None:
    """Nexus venue registry vs the backend mode manager."""
    a = os.path.join(ROOT, "NexusStarter/BasketballGame/Config/VenueRegistry.nexus.json")
    b = os.path.join(ROOT, "backend/FEL_ModeManager.production.json")
    if not (os.path.exists(a) and os.path.exists(b)):
        return
    with open(a, encoding="utf-8") as fh:
        nx = {v["modeId"] for v in json.load(fh)["venues"]}
    with open(b, encoding="utf-8") as fh:
        modes = json.load(fh)["mode_manager"]["modes"]
    be = {m.get("mode_id") or m.get("id") for m in modes}
    if nx - be:
        err("registry-sync", f"modes in Nexus but not in the backend: {sorted(nx - be)}")
    if be - nx:
        err("registry-sync", f"modes in the backend but not in Nexus: {sorted(be - nx)}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    files = product_swift_files()
    check_braces(files)
    check_xcode(files)
    check_nexus_registry()
    check_registry_sync()

    if args.json:
        print(json.dumps({"swiftFiles": len(files), "errors": errors, "warnings": warnings}, indent=2))
        return 1 if errors else 0

    g, r, y, o = "\033[32m", "\033[31m", "\033[33m", "\033[0m"
    print(f"\n  NEXUS static gate — {len(files)} product Swift file(s)")
    print(f"  {'(.claude/ worktrees excluded — they are not product code)'}\n")
    for e in errors:
        print(f"  {r}ERROR{o} [{e['check']}] {e['message']}")
        if e["where"]:
            print(f"        \033[2m{e['where']}{o}")
    for w in warnings:
        print(f"  {y}WARN {o} [{w['check']}] {w['message']}")
        if w["where"]:
            print(f"        \033[2m{w['where']}{o}")
    print(f"\n  {r if errors else g}{len(errors)} error(s){o}   {y}{len(warnings)} warning(s){o}")
    if errors:
        print(f"\n  {r}NEXUS NOT GREEN{o} — these break the Xcode build.\n")
    else:
        print(f"\n  {g}No statically-detectable build breakers.{o} "
              "This is NOT a substitute for xcodebuild on macOS.\n")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
