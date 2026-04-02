#!/usr/bin/env python3
"""
Add Creator Tool
================
CLI tool to add new creators to the Final Evolution Lab creator card system.

Usage:
    python3 Tools/add_creator.py --file path/to/creator.json
    python3 Tools/add_creator.py --interactive
    python3 Tools/add_creator.py --validate path/to/creator.json
    python3 Tools/add_creator.py --list
"""

import os
import sys
import json
import argparse
import shutil
from pathlib import Path
from datetime import date

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CREATOR_PROFILES_PATH = PROJECT_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Data" / "CreatorProfiles.json"
TEMPLATE_PATH = PROJECT_ROOT / "Tools" / "creator_template.json"

REQUIRED_FIELDS = [
    "id", "display_name", "tagline", "bio", "location",
    "primary_sport", "position", "tier", "card_style"
]

VALID_TIERS = ["Featured", "Verified", "Community", "ComingSoon"]
VALID_STYLES = ["Standard", "Premium", "Legendary", "Holographic"]
VALID_SPORTS = ["Basketball", "Soccer", "Boxing", "Tennis", "Mixed"]
VALID_HIGHLIGHT_TYPES = ["gameplay", "dunk", "training", "magic_reveal", "3d_model"]
VALID_DIFFICULTIES = ["Easy", "Medium", "Hard", "Legendary"]


def load_profiles():
    """Load existing creator profiles."""
    if CREATOR_PROFILES_PATH.exists():
        return json.loads(CREATOR_PROFILES_PATH.read_text())
    return {"version": "2.0.0", "creators": [], "coming_soon": [], "featured_order": [], "schema_version": "2.0"}


def save_profiles(data):
    """Save creator profiles with backup."""
    # Create backup
    if CREATOR_PROFILES_PATH.exists():
        backup = CREATOR_PROFILES_PATH.with_suffix(".json.bak")
        shutil.copy2(CREATOR_PROFILES_PATH, backup)
        print(f"  Backup created: {backup.name}")

    data["last_updated"] = str(date.today())
    CREATOR_PROFILES_PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False))
    print(f"  Saved: {CREATOR_PROFILES_PATH}")


def validate_creator(creator_data):
    """Validate a creator profile data structure."""
    errors = []
    warnings = []

    # Check required fields
    for field in REQUIRED_FIELDS:
        if field not in creator_data or not creator_data[field]:
            errors.append(f"Missing required field: {field}")

    # Validate ID format
    cid = creator_data.get("id", "")
    if cid and not cid.replace("_", "").isalnum():
        errors.append(f"Invalid ID format: '{cid}' (use lowercase_with_underscores)")

    # Validate tier
    tier = creator_data.get("tier", "")
    if tier and tier not in VALID_TIERS:
        errors.append(f"Invalid tier: '{tier}' (valid: {VALID_TIERS})")

    # Validate card style
    style = creator_data.get("card_style", "")
    if style and style not in VALID_STYLES:
        errors.append(f"Invalid card_style: '{style}' (valid: {VALID_STYLES})")

    # Validate highlights
    for i, h in enumerate(creator_data.get("highlights", [])):
        if not h.get("id"):
            errors.append(f"Highlight {i}: missing 'id'")
        ht = h.get("type", "")
        if ht and ht not in VALID_HIGHLIGHT_TYPES:
            warnings.append(f"Highlight {i}: unknown type '{ht}'")

    # Validate signature moves
    for i, m in enumerate(creator_data.get("signature_moves", [])):
        if not m.get("id"):
            errors.append(f"Signature move {i}: missing 'id'")
        d = m.get("difficulty", 0)
        if not (1 <= d <= 5):
            warnings.append(f"Signature move {i}: difficulty should be 1-5, got {d}")

    # Validate challenges
    for i, c in enumerate(creator_data.get("challenges", [])):
        if not c.get("id"):
            errors.append(f"Challenge {i}: missing 'id'")
        diff = c.get("difficulty", "")
        if diff and diff not in VALID_DIFFICULTIES:
            warnings.append(f"Challenge {i}: unknown difficulty '{diff}'")

    # Check bio length
    bio = creator_data.get("bio", "")
    if len(bio) < 50:
        warnings.append(f"Bio is very short ({len(bio)} chars). Recommend 100+ chars.")
    if len(bio) > 1000:
        warnings.append(f"Bio is very long ({len(bio)} chars). Recommend under 500 chars.")

    return errors, warnings


def add_creator_from_file(filepath):
    """Add a creator from a JSON file."""
    filepath = Path(filepath)
    if not filepath.exists():
        print(f"[ERROR] File not found: {filepath}")
        return False

    try:
        creator_data = json.loads(filepath.read_text())
    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON: {e}")
        return False

    # Remove template comments
    creator_data = {k: v for k, v in creator_data.items() if not k.startswith("_")}

    # Validate
    errors, warnings = validate_creator(creator_data)
    if errors:
        print(f"\n[ERRORS] Cannot add creator:")
        for e in errors:
            print(f"  ❌ {e}")
        return False

    if warnings:
        print(f"\n[WARNINGS]:")
        for w in warnings:
            print(f"  ⚠️  {w}")

    # Load existing profiles
    profiles = load_profiles()

    # Check for duplicate
    existing_ids = [c["id"] for c in profiles.get("creators", [])]
    if creator_data["id"] in existing_ids:
        print(f"\n[ERROR] Creator '{creator_data['id']}' already exists!")
        response = input("  Replace existing? (y/N): ").strip().lower()
        if response != "y":
            return False
        profiles["creators"] = [c for c in profiles["creators"] if c["id"] != creator_data["id"]]

    # Set defaults
    if not creator_data.get("date_added") or creator_data["date_added"] == "YYYY-MM-DD":
        creator_data["date_added"] = str(date.today())

    if not creator_data.get("profile_image"):
        cid = creator_data["id"]
        creator_data["profile_image"] = f"/Game/FEL/CreatorAssets/Profiles/{cid}_profile"
        creator_data["banner_image"] = f"/Game/FEL/CreatorAssets/Banners/{cid}_banner"
        creator_data["card_background"] = f"/Game/FEL/CreatorAssets/Backgrounds/{cid}_bg"

    # Add to profiles
    profiles["creators"].append(creator_data)

    # Update featured order if featured
    if creator_data.get("is_featured"):
        if creator_data["id"] not in profiles.get("featured_order", []):
            profiles.setdefault("featured_order", []).append(creator_data["id"])

    # Save
    save_profiles(profiles)

    print(f"\n✅ Creator '{creator_data['display_name']}' added successfully!")
    print(f"  ID: {creator_data['id']}")
    print(f"  Tier: {creator_data.get('tier', 'Community')}")
    print(f"  Highlights: {len(creator_data.get('highlights', []))}")
    print(f"  Signature Moves: {len(creator_data.get('signature_moves', []))}")
    print(f"  Challenges: {len(creator_data.get('challenges', []))}")

    # Create asset directories
    assets_dir = PROJECT_ROOT / "GeneratedAssets" / "CreatorModels" / creator_data["id"]
    assets_dir.mkdir(parents=True, exist_ok=True)
    print(f"  Asset directory: {assets_dir}")

    return True


def interactive_add():
    """Interactive creator addition."""
    print("\n=== Add New Creator (Interactive) ===")
    print("Fill in the following fields (press Enter for defaults):\n")

    creator = {}
    creator["id"] = input("  Creator ID (lowercase_with_underscores): ").strip()
    creator["display_name"] = input("  Display Name: ").strip()
    creator["tagline"] = input("  Tagline (short catchphrase): ").strip()
    creator["bio"] = input("  Bio (full description): ").strip()
    creator["location"] = input("  Location (e.g., Venice Beach, CA): ").strip()
    creator["primary_sport"] = input(f"  Sport ({'/'.join(VALID_SPORTS)}) [Basketball]: ").strip() or "Basketball"
    creator["position"] = input("  Position: ").strip()
    creator["height"] = input("  Height (e.g., 6'2\"): ").strip()
    creator["weight"] = input("  Weight (e.g., 180 lbs): ").strip()
    creator["tier"] = input(f"  Tier ({'/'.join(VALID_TIERS)}) [Community]: ").strip() or "Community"
    creator["card_style"] = input(f"  Card Style ({'/'.join(VALID_STYLES)}) [Standard]: ").strip() or "Standard"
    creator["is_featured"] = input("  Featured? (y/N): ").strip().lower() == "y"
    creator["is_playable"] = input("  Playable? (y/N): ").strip().lower() == "y"
    creator["has_3d_model"] = False
    creator["player_model"] = ""
    creator["sort_order"] = 99
    creator["date_added"] = str(date.today())
    creator["highlights"] = []
    creator["signature_moves"] = []
    creator["stats"] = []
    creator["social_links"] = []
    creator["challenges"] = []

    # Social link
    handle = input("  Instagram handle (optional, e.g., @username): ").strip()
    if handle:
        creator["social_links"].append({
            "platform": "instagram",
            "handle": handle,
            "url": f"https://instagram.com/{handle.lstrip('@')}",
            "followers": 0
        })

    # Save to temp file and add
    temp_path = PROJECT_ROOT / "Tools" / f"_temp_{creator['id']}.json"
    temp_path.write_text(json.dumps(creator, indent=2))
    result = add_creator_from_file(temp_path)
    temp_path.unlink(missing_ok=True)
    return result


def list_creators():
    """List all creators in the database."""
    profiles = load_profiles()
    creators = profiles.get("creators", [])
    coming_soon = profiles.get("coming_soon", [])

    print(f"\n=== Creator Database ({len(creators)} creators) ===")
    print(f"{'ID':<20} {'Name':<25} {'Tier':<12} {'Sport':<12} {'Featured':<10} {'3D Model':<10}")
    print("-" * 90)

    for c in creators:
        print(f"{c['id']:<20} {c['display_name']:<25} {c.get('tier', '?'):<12} "
              f"{c.get('primary_sport', '?'):<12} {'Yes' if c.get('is_featured') else 'No':<10} "
              f"{'Yes' if c.get('has_3d_model') else 'No':<10}")

    if coming_soon:
        print(f"\nComing Soon: {len(coming_soon)} placeholder(s)")

    print(f"\nFeatured Order: {profiles.get('featured_order', [])}")


def main():
    parser = argparse.ArgumentParser(description="Add Creator to Final Evolution Lab")
    parser.add_argument("--file", type=str, help="JSON file with creator data")
    parser.add_argument("--validate", type=str, help="Validate a creator JSON file")
    parser.add_argument("--interactive", action="store_true", help="Interactive mode")
    parser.add_argument("--list", action="store_true", help="List all creators")
    args = parser.parse_args()

    if args.list:
        list_creators()
    elif args.validate:
        filepath = Path(args.validate)
        data = json.loads(filepath.read_text())
        data = {k: v for k, v in data.items() if not k.startswith("_")}
        errors, warnings = validate_creator(data)
        if errors:
            print("ERRORS:")
            for e in errors:
                print(f"  ❌ {e}")
        if warnings:
            print("WARNINGS:")
            for w in warnings:
                print(f"  ⚠️  {w}")
        if not errors:
            print("✅ Validation passed!")
    elif args.interactive:
        interactive_add()
    elif args.file:
        add_creator_from_file(args.file)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
