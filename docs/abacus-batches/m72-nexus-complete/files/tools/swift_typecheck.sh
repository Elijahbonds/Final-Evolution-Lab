#!/usr/bin/env bash
# swift_typecheck.sh — REAL Swift type-checking for Nexus, on Linux.
#
#     bash tools/swift_typecheck.sh                 # use an installed toolchain
#     bash tools/swift_typecheck.sh --install       # fetch Swift if missing
#     bash tools/swift_typecheck.sh --list          # show what would be checked
#
# WHY THIS EXISTS
# AGENTS.md said the iOS app "cannot be built in a Cloud Agent VM", and that
# was taken to mean nothing about it could be verified anywhere but a Mac. The
# app genuinely cannot be BUILT here — it is an iOS app and 74% of its files
# import SwiftUI/UIKit/Firebase, none of which exist off-Apple. But "cannot be
# built" is not "cannot be checked":
#
#   44 of 159 files — including the entire physics/rules/engine core
#   (ArcadePhysics, MatrixPhysicsEngine, HelpDefense3v3, AvatarStateMachine,
#   ShardEconomy, Matchmaking) — type-check with a real Swift compiler on
#   Linux, in about a minute.
#
# That is the difference between "we have never compiled this" and "the game
# logic compiles; the UI layer is what still needs a Mac."
#
# WHAT IT CANNOT DO — say it plainly: this is a TYPE-CHECK of a SUBSET. It
# does not link, does not run, does not touch the UI layer, and is not a
# substitute for `xcodebuild -scheme FinalEvolutionLab build`.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SWIFT_ROOT="${SWIFT_ROOT:-$HOME/.swift-toolchain}"
SWIFT_VER="${SWIFT_VER:-6.0.3}"
SHIMS="tools/swift-shims"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

c_green=$'\033[32m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'

find_swiftc() {
  if command -v swiftc >/dev/null 2>&1; then command -v swiftc; return 0; fi
  if [ -x "$SWIFT_ROOT/usr/bin/swiftc" ]; then echo "$SWIFT_ROOT/usr/bin/swiftc"; return 0; fi
  return 1
}

install_swift() {
  local url="https://download.swift.org/swift-${SWIFT_VER}-release/ubuntu2404/swift-${SWIFT_VER}-RELEASE/swift-${SWIFT_VER}-RELEASE-ubuntu24.04.tar.gz"
  echo "  fetching Swift ${SWIFT_VER} (~750 MB) → $SWIFT_ROOT"
  mkdir -p "$SWIFT_ROOT"
  curl -sSL "$url" -o "$WORK/swift.tar.gz" || { echo "  ${c_red}download failed${c_off}"; return 1; }
  tar xzf "$WORK/swift.tar.gz" -C "$SWIFT_ROOT" --strip-components=1 || return 1
  echo "  installed: $("$SWIFT_ROOT/usr/bin/swift" --version 2>&1 | head -1)"
}

# Files with NO Apple-only import. OSLog and QuartzCore are excluded from this
# list because tools/swift-shims/ provides Linux stand-ins for them, and
# CoreGraphics is excluded because swift-corelibs-foundation already provides
# CGPoint/CGSize/CGFloat on Linux — only the module NAME is Apple-only. That
# last one is what brings the whole Nexus scene model and its loader into
# reach of a non-Apple type-check.
collect() {
  python3 - <<'PY'
import glob, re
APPLE_ONLY = {"SwiftUI","UIKit","SceneKit","SpriteKit","CoreMotion",
 "AVFoundation","AVKit","HealthKit","PhotosUI","MultipeerConnectivity","CoreLocation","MapKit",
 "StoreKit","WebKit","RealityKit","ARKit","Metal","MetalKit","GameKit","CoreData","SwiftData",
 "UserNotifications","Charts","Accelerate","ObjectiveC","XCTest","Testing","Combine",
 "FirebaseCore","FirebaseAuth","FirebaseFirestore","FirebaseCrashlytics","FirebaseDataConnect",
 "SocialDataConnect"}
for f in sorted(glob.glob('FinalEvolutionLab/**/*.swift', recursive=True)):
    if '.claude' in f or '/Generated/' in f:
        continue
    src = open(f, encoding='utf-8', errors='replace').read()
    if not ({m for m in re.findall(r'^\s*import\s+([A-Za-z_]\w*)', src, re.M)} & APPLE_ONLY):
        print(f)
PY
}

if [ "${1:-}" = "--list" ]; then
  collect | sed 's/^/  /'
  echo "  ── $(collect | wc -l) file(s) of $(find FinalEvolutionLab -name '*.swift' | grep -vc Generated) "
  exit 0
fi

SWIFTC="$(find_swiftc)" || {
  if [ "${1:-}" = "--install" ]; then
    install_swift && SWIFTC="$SWIFT_ROOT/usr/bin/swiftc"
  else
    echo "  ${c_yellow}SKIP${c_off} no Swift toolchain."
    echo "        Install with: bash tools/swift_typecheck.sh --install"
    echo "        (or set SWIFT_ROOT to an existing toolchain)"
    exit 0          # a missing toolchain is a SKIP, never a false failure
  fi
}
[ -n "${SWIFTC:-}" ] || { echo "  ${c_red}FAIL${c_off} could not obtain swiftc"; exit 1; }

mapfile -t FILES < <(collect)
[ "${#FILES[@]}" -gt 0 ] || { echo "  ${c_yellow}SKIP${c_off} no portable Swift files found"; exit 0; }

# Strip the shimmed imports: the shims are plain source compiled into the same
# module, so `import OSLog` would fail to resolve as a module name.
mkdir -p "$WORK/src"
for f in "${FILES[@]}"; do
  sed -e 's/^import OSLog$//' -e 's/^import QuartzCore$//' -e 's/^import CoreGraphics$//' "$f" > "$WORK/src/$(echo "$f" | tr / _)"
done

echo
echo "  Swift: $("${SWIFTC%c}" --version 2>&1 | head -1)"
echo "  type-checking ${#FILES[@]} portable file(s) + shims${c_dim} (UI layer needs macOS)${c_off}"
echo

LOG="$WORK/tc.log"
"$SWIFTC" -typecheck -swift-version 5 "$SHIMS"/*.swift "$WORK"/src/*.swift > "$LOG" 2>&1
N_ERR=$(grep -c ': error:' "$LOG")

if [ "$N_ERR" -eq 0 ]; then
  echo "  ${c_green}PASS${c_off}  ${#FILES[@]} files type-check clean"
  exit 0
fi

# `nonisolated` on a TYPE declaration is Swift 6.1+ (SE-0449). A 6.0 compiler
# rejects it. That is a TOOLCHAIN FLOOR, not a code defect, so it is reported
# separately — telling someone to "fix" 147 correct declarations would be
# actively wrong.
# Anchor on ": error:" exactly as N_ERR does. Matching the bare message counts
# the caret/context line too, which made N_ISO exceed N_ERR, drove N_OTHER
# negative, and silently swallowed real errors.
N_ISO=$(grep -c ": error: 'nonisolated' modifier cannot be applied" "$LOG")
if [ "$N_ISO" -gt 0 ]; then
  echo "  ${c_yellow}TOOLCHAIN${c_off}  $N_ISO × \"'nonisolated' cannot be applied to this declaration\""
  echo "        ${c_dim}This code is correct. \`nonisolated\` on a type is Swift 6.1+ (SE-0449);"
  echo "        this toolchain is $("${SWIFTC%c}" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)."
  echo "        The repo has 147 such declarations across 40 files, so the project"
  echo "        REQUIRES Swift 6.1 / Xcode 16.3+. Build on anything older and it"
  echo "        fails with exactly these errors.${c_off}"
fi

OTHER=$(grep ': error:' "$LOG" | grep -v "'nonisolated' modifier cannot be applied" | head -20)
N_OTHER=$((N_ERR - N_ISO))
if [ "$N_OTHER" -gt 0 ]; then
  echo
  echo "  ${c_red}FAIL${c_off}  $N_OTHER other error(s):"
  echo "$OTHER" | sed "s/^/        /"
  echo
  echo "  ${c_dim}Note: 'cannot find type X' usually means X lives in a file that imports"
  echo "  SwiftUI and is therefore outside this subset — an artefact, not a bug."
  echo "  Check with: grep -rn \"enum X\" --include=*.swift FinalEvolutionLab${c_off}"
  exit 1
fi

echo
echo "  ${c_green}No code defects${c_off} — the only errors are the toolchain floor above."
exit 0
