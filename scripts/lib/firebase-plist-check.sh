#!/usr/bin/env bash
# Shared GoogleService-Info.plist checks for archive / CI (no secrets printed).
set -euo pipefail

FEL_EXPECTED_BUNDLE_ID="${FEL_EXPECTED_BUNDLE_ID:-com.finalevolutionlab.app}"

fel_is_placeholder_plist() {
  local plist="${1:?plist path required}"
  [[ -f "$plist" ]] || return 1
  if grep -q 'REPLACE_ME' "$plist" 2>/dev/null; then
    return 0
  fi
  local app_id
  app_id="$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$plist" 2>/dev/null || true)"
  if [[ "$app_id" == "1:000000000000:ios:0000000000000000000000" ]]; then
    return 0
  fi
  local preview_flag
  preview_flag="$(/usr/libexec/PlistBuddy -c "Print :FEL_FIREBASE_PREVIEW" "$plist" 2>/dev/null || true)"
  if [[ "$preview_flag" == "1" ]]; then
    return 0
  fi
  return 1
}

fel_validate_bundle_id() {
  local plist="${1:?plist path required}"
  local expected="${2:-$FEL_EXPECTED_BUNDLE_ID}"
  [[ -f "$plist" ]] || { echo "error: plist not found: ${plist}" >&2; return 1; }

  local bundle
  bundle="$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$plist" 2>/dev/null || true)"
  if [[ -z "$bundle" ]]; then
    echo "error: BUNDLE_ID missing in ${plist}" >&2
    return 1
  fi
  if [[ "$bundle" != "$expected" ]]; then
    echo "error: BUNDLE_ID is '${bundle}'; expected '${expected}'" >&2
    if [[ "$bundle" == "FinalEvoLab" ]]; then
      echo "hint: plist is from legacy Firebase iOS app — download from com.finalevolutionlab.app registration" >&2
      echo "      https://console.firebase.google.com/project/final-evolution-lab/settings/general" >&2
    fi
    return 1
  fi
  return 0
}

fel_validate_plist() {
  local plist="${1:?plist path required}"
  local expected="${2:-$FEL_EXPECTED_BUNDLE_ID}"
  [[ -f "$plist" ]] || { echo "error: plist not found: ${plist}" >&2; return 1; }

  if fel_is_placeholder_plist "$plist"; then
    echo "warning: ${plist} is preview/placeholder — skip for production Firebase" >&2
    return 0
  fi

  fel_validate_bundle_id "$plist" "$expected"

  local project_id
  project_id="$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$plist" 2>/dev/null || true)"
  if [[ -n "$project_id" && "$project_id" != "final-evolution-lab" ]]; then
    echo "warning: PROJECT_ID is '${project_id}'; expected 'final-evolution-lab'" >&2
  fi
  return 0
}

case "${1:-}" in
  is-placeholder)
    fel_is_placeholder_plist "${2:?missing plist path}"
    ;;
  validate-bundle-id)
    fel_validate_bundle_id "${2:?missing plist path}" "${3:-$FEL_EXPECTED_BUNDLE_ID}"
    ;;
  validate)
    fel_validate_plist "${2:?missing plist path}" "${3:-$FEL_EXPECTED_BUNDLE_ID}"
    ;;
  *)
    echo "usage: $0 {is-placeholder|validate-bundle-id|validate} <GoogleService-Info.plist> [bundle_id]" >&2
    exit 2
    ;;
esac
