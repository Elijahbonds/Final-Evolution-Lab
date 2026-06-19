#!/bin/bash
# Builds or reuses headless NEXUS static libraries for the active iOS SDK.
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PREBUILT_DIR="${ROOT}/build-ios"
BUILD_DIR="${TARGET_TEMP_DIR:-${DERIVED_FILE_DIR:-${PREBUILT_DIR}}}/nexus-ios"

if [[ -f "${PREBUILT_DIR}/libnexus_gameplay.a" ]]; then
  mkdir -p "$(dirname "${SCRIPT_OUTPUT_FILE_0:-${BUILD_DIR}/libnexus_gameplay.a}")"
  if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" && ! -f "${SCRIPT_OUTPUT_FILE_0}" ]]; then
    cp "${PREBUILT_DIR}/libnexus_gameplay.a" "${SCRIPT_OUTPUT_FILE_0}"
  fi
  exit 0
fi

if [[ "${PLATFORM_NAME:-}" == "iphonesimulator" ]]; then
  SYSROOT="iphonesimulator"
else
  SYSROOT="iphoneos"
fi

ARCH="${ARCHS:-arm64}"
ARCH="${ARCH// /;}"
ARCH="${ARCH%%;*}"

mkdir -p "${BUILD_DIR}"

if [[ -f "${BUILD_DIR}/libnexus_gameplay.a" ]]; then
  if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" && "${BUILD_DIR}/libnexus_gameplay.a" != "${SCRIPT_OUTPUT_FILE_0}" ]]; then
    cp "${BUILD_DIR}/libnexus_gameplay.a" "${SCRIPT_OUTPUT_FILE_0}"
  fi
  exit 0
fi

cmake -S "${ROOT}" -B "${BUILD_DIR}" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="${SYSROOT}" \
  -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
  -DNEXUS_ENABLE_RENDERER=OFF \
  -DNEXUS_BUILD_RUNTIME=OFF \
  -DNEXUS_BUILD_TESTS=OFF

cmake --build "${BUILD_DIR}" --target nexus_gameplay

if [[ -n "${SCRIPT_OUTPUT_FILE_0:-}" && -f "${BUILD_DIR}/libnexus_gameplay.a" ]]; then
  cp "${BUILD_DIR}/libnexus_gameplay.a" "${SCRIPT_OUTPUT_FILE_0}"
fi
