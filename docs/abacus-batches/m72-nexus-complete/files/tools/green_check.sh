#!/usr/bin/env bash
# green_check.sh — ONE command, BOTH products, an honest verdict.
#
#     bash tools/green_check.sh            # everything that can run here
#     bash tools/green_check.sh --fel      # FEL (live Babylon app) only
#     bash tools/green_check.sh --nexus    # Nexus (repo: backend/Swift/web) only
#
# DESIGN RULE: a check that CANNOT run on this machine is reported as SKIPPED
# with the reason — never silently passed, never counted as a failure. A
# green build you got by not looking is worse than a red one.
#
# Exit 0 only when every RUNNABLE check passed.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

PASS=0; FAIL=0; SKIP=0
FAILED_NAMES=()

c_green=$'\033[32m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'

pass() { PASS=$((PASS+1)); printf "  ${c_green}PASS${c_off}  %s\n" "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_NAMES+=("$1"); printf "  ${c_red}FAIL${c_off}  %s\n" "$1"; [ -n "${2:-}" ] && printf "        ${c_dim}%s${c_off}\n" "$2"; }
skip() { SKIP=$((SKIP+1)); printf "  ${c_yellow}SKIP${c_off}  %s\n" "$1"; printf "        ${c_dim}%s${c_off}\n" "${2:-}"; }
head_() { printf "\n${c_dim}── %s ─────────────────────────────${c_off}\n" "$1"; }

run() { # run <name> <cmd...>
  local name="$1"; shift
  local out
  if out=$("$@" 2>&1); then pass "$name"
  else fail "$name" "$(printf '%s' "$out" | tail -3 | tr '\n' ' ')"; fi
}

WHICH="${1:---all}"

# ═══════════════════════════ NEXUS (this repo) ═══════════════════════════
if [ "$WHICH" = "--all" ] || [ "$WHICH" = "--nexus" ]; then
  head_ "NEXUS — backend (Python/FastAPI)"

  if command -v python3 >/dev/null; then
    run "python syntax (compileall)" python3 -m compileall -q backend

    if python3 -c "import fastapi" 2>/dev/null; then
      # app must be IMPORTABLE with no DB configured — that is what CI has
      if (cd backend && MOCK_DB=1 python3 -c "import sys;sys.path.insert(0,'.');import server" >/dev/null 2>&1); then
        pass "server.py imports with no DB configured"
      else
        fail "server.py imports with no DB configured" \
             "$(cd backend && MOCK_DB=1 python3 -c "import sys;sys.path.insert(0,'.');import server" 2>&1 | tail -2 | tr '\n' ' ')"
      fi
      if (cd backend && MOCK_DB=1 python3 -m pytest -q >/tmp/felpytest.txt 2>&1); then
        pass "pytest unit suite — $(tail -2 /tmp/felpytest.txt | grep -oE '[0-9]+ passed.*' | head -1)"
      else
        fail "pytest unit suite" "$(grep -E '^(FAILED|ERROR)' /tmp/felpytest.txt | head -2 | tr '\n' ' ')"
      fi
    else
      skip "backend imports + pytest" "FastAPI not installed — pip install -r backend/requirements.txt"
    fi
  else
    skip "backend checks" "python3 not available"
  fi

  head_ "NEXUS — registries & config"
  run "mode registry JSON parses" python3 -c "
import json,sys
d=json.load(open('backend/FEL_ModeManager.production.json'))
m=d['mode_manager']['modes']
assert len(m)>0, 'no modes'
print(len(m),'modes')"
  run "NexusProject.json parses" python3 -c "import json;json.load(open('NexusStarter/NexusProject.json'))"

  head_ "NEXUS — iOS / Swift"
  # Static gate FIRST. It cannot replace a compiler, but it catches the class
  # of defect that was silently riding along while the real build was skipped
  # — a file with unbalanced braces, a package manifest compiled as app
  # source, an import with no linked product. All of those break xcodebuild,
  # and none of them need xcodebuild to find.
  if command -v python3 >/dev/null; then
    run "Swift/Nexus static gate" python3 tools/nexus_check.py
  else
    skip "Swift/Nexus static gate" "python3 not available"
  fi

  # Descriptors are generated from the Swift model; verifying them drives the
  # REAL NexusSceneLoader over all 20 modes. Skips cleanly with no toolchain.
  run "Nexus scene descriptors load" bash tools/nexus_scenes.sh

  if command -v swiftc >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
    run "swift build" swift build
  else
    # Count PRODUCT sources only. `find . -name '*.swift'` returns 1425 here
    # because .claude/worktrees holds 1266 files from abandoned agent runs;
    # reporting that number described Nexus as ~9x its real size.
    SWIFT_N=$(find FinalEvolutionLab FinalEvolutionLabTests FinalEvolutionLabUITests infra \
                -name '*.swift' 2>/dev/null | wc -l | tr -d ' ')
    skip "Swift/Xcode build (${SWIFT_N} product sources)" \
         "needs macOS + Xcode. Run on the Mac mini runner: xcodebuild -scheme FinalEvolutionLab build"
  fi

  head_ "NEXUS — web frontend"
  if [ -d frontend/node_modules ]; then
    skip "frontend build" "run 'cd frontend && npm run build' — slow; excluded from the fast gate by design"
  else
    skip "frontend build" "frontend/node_modules missing — npm ci first"
  fi
fi

# ═══════════════════════════ FEL (live app) ══════════════════════════════
if [ "$WHICH" = "--all" ] || [ "$WHICH" = "--fel" ]; then
  head_ "FEL — drag-and-drop batches"
  if command -v node >/dev/null; then
    run "batch structure + syntax" node tools/verify_batch.mjs --all
  else
    skip "batch verify" "node not available"
  fi

  head_ "FEL — assets"
  if [ -d assets/ready ]; then
    run "asset budgets + skeleton" python3 tools/validate_assets.py assets/ready
  else
    skip "asset gate" "no assets/ready directory yet"
  fi

  head_ "FEL — live smoke"
  if [ -f smoke-state.json ]; then
    run "live modes render" node tools/smoke.mjs
  else
    skip "live smoke" "no smoke-state.json — FEL is behind a sign-in wall. Run: node tools/smoke.mjs --login"
  fi
fi

# ═══════════════════════════ verdict ═════════════════════════════════════
printf "\n${c_dim}════════════════════════════════════════════${c_off}\n"
printf "  ${c_green}%d passed${c_off}   ${c_red}%d failed${c_off}   ${c_yellow}%d skipped${c_off}\n" "$PASS" "$FAIL" "$SKIP"
if [ "$FAIL" -gt 0 ]; then
  printf "\n  Red:\n"
  for n in "${FAILED_NAMES[@]}"; do printf "   · %s\n" "$n"; done
  printf "\n  ${c_red}BUILD NOT GREEN${c_off}\n"
  exit 1
fi
if [ "$SKIP" -gt 0 ]; then
  printf "\n  ${c_green}GREEN${c_off} on everything runnable here.\n"
  printf "  ${c_yellow}%d check(s) skipped${c_off} — see the reasons above. A skip is not a pass.\n" "$SKIP"
else
  printf "\n  ${c_green}FULLY GREEN${c_off}\n"
fi
exit 0
