#!/bin/bash
# Builds or stages NEXUS static libraries for the active iOS SDK.
#
# Xcode: stages NexusPrebuilt/${PLATFORM_NAME}/*.a → DERIVED_FILE_DIR/nexus-ios.
#        Rebuilds inline when platform prebuilts are missing or SDK-mismatched.
# Terminal/CI: cmake cross-compile → build-ios/nexus-ios-${SYSROOT}/ + NexusPrebuilt/${SYSROOT}/.
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PREBUILT_DIR="${ROOT}/build-ios"
NEXUS_PREBUILT="${ROOT}/NexusPrebuilt"

LINK_LIBS=(
  libnexus_gameplay.a
  libnexus_renderer.a
  libnexus_ai_interface.a
  libnexus_generative.a
  libnexus_assets.a
  libnexus_luma.a
  libnexus_creative.a
  libnexus_physics.a
  libnexus_core.a
)

resolve_sysroot() {
  if [[ "${PLATFORM_NAME:-iphonesimulator}" == "iphonesimulator" ]]; then
    echo "iphonesimulator"
  else
    echo "iphoneos"
  fi
}

# LC_BUILD_VERSION platform: 2 = iOS device, 7 = iOS Simulator (macOS SDK headers).
expected_platform_id() {
  if [[ "$1" == "iphonesimulator" ]]; then
    echo "7"
  else
    echo "2"
  fi
}

archive_matches_sysroot() {
  local archive="$1"
  local sysroot="$2"
  [[ -f "${archive}" ]] || return 1

  local expected
  expected="$(expected_platform_id "${sysroot}")"
  local member
  member="$(ar -t "${archive}" 2>/dev/null | head -n 1 || true)"
  [[ -n "${member}" ]] || return 1

  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/nexus-ios-check.XXXXXX")"
  (
    cd "${tmp}"
    ar x "${archive}" "${member}" 2>/dev/null
    otool -l "${member}" 2>/dev/null | awk -v want="${expected}" '
      $1 == "platform" { plat = $2 }
      END { exit (plat == want ? 0 : 1) }
    '
  )
  local ok=$?
  rm -rf "${tmp}"
  return "${ok}"
}

prebuilt_complete() {
  local src="$1"
  local sysroot="$2"
  local lib
  for lib in "${LINK_LIBS[@]}"; do
    [[ -f "${src}/${lib}" ]] || return 1
    archive_matches_sysroot "${src}/${lib}" "${sysroot}" || return 1
  done
}

stage_from_prebuilt() {
  local src="$1"
  local dest="$2"
  mkdir -p "${dest}"
  local lib
  for lib in "${LINK_LIBS[@]}"; do
    cp -f "${src}/${lib}" "${dest}/${lib}"
  done
}

xcode_stage_dest() {
  if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" ]]; then
    dirname "${SCRIPT_OUTPUT_FILE_0}"
  elif [[ -n "${DERIVED_FILE_DIR:-}" ]]; then
    echo "${DERIVED_FILE_DIR}/nexus-ios"
  else
    echo ""
  fi
}

build_for_sysroot() {
  local sysroot="$1"
  local build_dir="${PREBUILT_DIR}/nexus-ios-${sysroot}"
  local platform_prebuilt="${NEXUS_PREBUILT}/${sysroot}"

  local arch="${ARCHS:-arm64}"
  arch="${arch// /;}"
  arch="${arch%%;*}"

  mkdir -p "${build_dir}" "${platform_prebuilt}" "${PREBUILT_DIR}"

  if [[ ! -f "${build_dir}/CMakeCache.txt" ]] ||
     ! grep -q "CMAKE_OSX_SYSROOT:STRING=${sysroot}" "${build_dir}/CMakeCache.txt" 2>/dev/null; then
    rm -rf "${build_dir}"
    mkdir -p "${build_dir}"
    cmake -S "${ROOT}" -B "${build_dir}" \
      -DCMAKE_SYSTEM_NAME=iOS \
      -DCMAKE_OSX_SYSROOT="${sysroot}" \
      -DCMAKE_OSX_ARCHITECTURES="${arch}" \
      -DNEXUS_ENABLE_RENDERER=OFF \
      -DNEXUS_ENABLE_METAL_RENDERER=ON \
      -DNEXUS_BUILD_RUNTIME=OFF \
      -DNEXUS_BUILD_TESTS=OFF \
      -DNEXUS_BUILD_AGENT_CLI=OFF
  fi

  local lib
  for lib in nexus_core nexus_physics nexus_creative nexus_assets nexus_luma nexus_generative nexus_ai_interface nexus_gameplay nexus_renderer; do
    cmake --build "${build_dir}" -j1 --target "${lib}"
    cp -f "${build_dir}/lib${lib}.a" "${platform_prebuilt}/lib${lib}.a"
    cp -f "${build_dir}/lib${lib}.a" "${PREBUILT_DIR}/lib${lib}.a"
  done

  if [[ -d "${build_dir}/_deps/nlohmann_json-src/include" ]]; then
    rm -rf "${NEXUS_PREBUILT}/_deps"
    mkdir -p "${NEXUS_PREBUILT}/_deps"
    cp -R "${build_dir}/_deps/nlohmann_json-src" "${NEXUS_PREBUILT}/_deps/nlohmann_json-src"
  fi

  echo "NEXUS iOS libs ready: ${platform_prebuilt} (sysroot=${sysroot})"
}

SYSROOT="$(resolve_sysroot)"
PLATFORM_PREBUILT="${NEXUS_PREBUILT}/${SYSROOT}"

if [[ -n "${XCODE_VERSION_ACTUAL:-}" ]]; then
  DEST="$(xcode_stage_dest)"
  if [[ -z "${DEST}" ]]; then
    echo "error: Xcode script phase missing DERIVED_FILE_DIR / SCRIPT_OUTPUT_FILE_0." >&2
    exit 1
  fi
  if prebuilt_complete "${PLATFORM_PREBUILT}" "${SYSROOT}"; then
    stage_from_prebuilt "${PLATFORM_PREBUILT}" "${DEST}"
    echo "note: staged NEXUS prebuilt from ${PLATFORM_PREBUILT}"
    exit 0
  fi
  echo "note: building NEXUS for ${SYSROOT} (missing or SDK-mismatched prebuilt)"
  build_for_sysroot "${SYSROOT}"
  stage_from_prebuilt "${PLATFORM_PREBUILT}" "${DEST}"
  exit 0
fi

if prebuilt_complete "${PLATFORM_PREBUILT}" "${SYSROOT}"; then
  echo "NEXUS iOS prebuilt up to date: ${PLATFORM_PREBUILT}"
  exit 0
fi

build_for_sysroot "${SYSROOT}"
