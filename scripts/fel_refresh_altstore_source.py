#!/usr/bin/env python3
"""
Generate AltStore / SideStore compatible Source JSON (apps.json).
Spec: https://faq.altstore.io/distribute-your-apps/make-a-source
Same JSON works in SideStore's "Sources" UI.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def parse_ue_ini(path: Path) -> dict[str, str]:
    """Last wins for duplicate keys (typical UE ini). Ignores comments and section headers."""
    out: dict[str, str] = {}
    text = path.read_text(encoding="utf-8", errors="ignore")
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or line.startswith("[") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"')
    return out


def plist_val(app_bundle: Path, key: str) -> str | None:
    buddy = "/usr/libexec/PlistBuddy"
    plist = app_bundle / "Info.plist"
    if not plist.is_file():
        return None
    try:
        out = subprocess.check_output([buddy, "-c", f"Print {key}", str(plist)], text=True)
        return out.strip()
    except subprocess.CalledProcessError:
        return None


def ipa_size_bytes(proj: Path) -> int | None:
    ios = proj / "Binaries" / "IOS"
    if not ios.is_dir():
        return None
    for name in ("FinalEvolutionLab.ipa",):
        p = ios / name
        if p.is_file():
            return p.stat().st_size
    return None


def build_payload(
    proj_dir: Path,
    download_url: str,
    icon_url: str,
    source_name: str,
    source_identifier: str,
) -> dict:
    game_ini = proj_dir / "Config" / "DefaultGame.ini"
    engine_ini = proj_dir / "Config" / "DefaultEngine.ini"

    game = parse_ue_ini(game_ini) if game_ini.is_file() else {}
    engine = parse_ue_ini(engine_ini) if engine_ini.is_file() else {}

    version = game.get("ProjectVersion", "1.0.0")
    bundle_id = engine.get("BundleIdentifier", "com.finalevolutionlab.finaldev")

    app_bundle = None
    ios_bin = proj_dir / "Binaries" / "IOS"
    if ios_bin.is_dir():
        for child in sorted(ios_bin.iterdir()):
            if child.is_dir() and child.suffix == ".app":
                app_bundle = child
                break

    short_ver = plist_val(app_bundle, "CFBundleShortVersionString") if app_bundle else None
    build_ver = plist_val(app_bundle, "CFBundleVersion") if app_bundle else None
    plist_bundle = plist_val(app_bundle, "CFBundleIdentifier") if app_bundle else None

    display_version = short_ver or version
    if plist_bundle:
        bundle_id = plist_bundle

    size = ipa_size_bytes(proj_dir)
    if size is None:
        size = int(os.environ.get("FEL_FALLBACK_IPA_BYTES", "350000000"))

    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    ver_obj: dict = {
        "version": display_version,
        "date": date_str,
        "localizedDescription": (
            "Sovereign Shipping build — Scene It / Arena Party, Fuel Concierge (PRQ-aware), "
            "Draft Class phygital flow, Sovereign Hub telemetry."
        ),
        "downloadURL": download_url,
        "size": size,
        "minOSVersion": "17.0",
    }
    if build_ver:
        ver_obj["buildVersion"] = build_ver

    description = (
        "Final Evolution Lab — native athlete OS: Venice & venue arenas, Brain Brawl (NeuroArena), "
        "Arena Party board, Scene It clips, nutrition concierge with DoorDash-style deep links, "
        "Draft Class Creator Pass + QR vault. Requires sideload tooling (AltStore / SideStore) "
        "and a valid install signature."
    )

    payload = {
        "name": source_name,
        "identifier": source_identifier,
        "subtitle": "Private League — Final Evolution Lab",
        "localizedDescription": (
            "Host-side source for the Sovereign Lab. One IPA: all modules ship together "
            "(Brain Brawl, Draft Class, Fuel, Scene It). Update this source after each cook."
        ),
        "tintColor": "4A90D9",
        "categories": [],
        "userInfo": {},
        "apps": [
            {
                "name": "Final Evolution Lab",
                "bundleIdentifier": bundle_id,
                "developerName": "Final Evolution Lab",
                "subtitle": "Sovereign OS — Arena · Fuel · Draft Class",
                "localizedDescription": description,
                "iconURL": icon_url,
                "tintColor": "4A90D9",
                "versions": [ver_obj],
            }
        ],
        "news": [
            {
                "title": "Brain Brawl",
                "identifier": "fel-news-brain-brawl",
                "caption": "STEM / NeuroArena lane — bundled in the main app.",
                "date": date_str,
                "tintColor": "4A90D9",
            },
            {
                "title": "Draft Class",
                "identifier": "fel-news-draft-class",
                "caption": "Creator Pass, QR activation, Sovereign Vault — same IPA.",
                "date": date_str,
                "tintColor": "4A90D9",
            },
        ],
    }
    return payload


def main() -> int:
    p = argparse.ArgumentParser(description="Write AltStore/SideStore apps.json")
    p.add_argument("project_dir", type=Path, help="Path to UE project (FinalEvolutionLab57)")
    p.add_argument(
        "--download-url",
        default=os.environ.get(
            "FEL_ALTSTORE_IPA_URL", "https://finalevolutionlab.com/app/FinalEvolutionLab.ipa"
        ),
    )
    p.add_argument(
        "--icon-url",
        default=os.environ.get(
            "FEL_ALTSTORE_ICON_URL", "https://finalevolutionlab.com/icons/fel-1024.png"
        ),
    )
    p.add_argument(
        "--source-name",
        default="Final Evolution Lab (Sovereign Source)",
    )
    p.add_argument(
        "--source-id",
        default="com.finalevolutionlab.altstore.source",
    )
    p.add_argument("--stdout", action="store_true", help="Print JSON only (no writes)")
    args = p.parse_args()

    proj = args.project_dir.resolve()
    payload = build_payload(
        proj,
        download_url=args.download_url,
        icon_url=args.icon_url,
        source_name=args.source_name,
        source_identifier=args.source_id,
    )
    text = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"

    if args.stdout:
        sys.stdout.write(text)
        return 0

    out_paths = [
        proj / "apps.json",
        proj / "Binaries" / "IOS" / "apps.json",
        proj / "Binaries" / "IOS" / "Deploy" / "apps.json",
    ]
    script_dir = Path(__file__).resolve().parent.parent
    out_paths.append(script_dir / "apps.json")

    for op in out_paths:
        op.parent.mkdir(parents=True, exist_ok=True)
        op.write_text(text, encoding="utf-8")
        print(f"wrote {op}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
