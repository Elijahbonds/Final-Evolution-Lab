#!/usr/bin/env bash
# Shared CMake build directories are intentionally reused by local scripts.
# Serialize destructive resets/builds so parallel agents cannot delete objects
# while another gate is compiling or running ctest.

NEXUS_BUILD_LOCK_DIR="${NEXUS_BUILD_LOCK_DIR:-${ROOT}/.nexus-build.lock}"
NEXUS_BUILD_LOCK_PID_FILE="${NEXUS_BUILD_LOCK_DIR}/pid"
NEXUS_BUILD_LOCK_HELD=0

nexus_acquire_build_lock() {
  while ! mkdir "${NEXUS_BUILD_LOCK_DIR}" 2>/dev/null; do
    local owner=""
    if [[ -r "${NEXUS_BUILD_LOCK_PID_FILE}" ]]; then
      owner="$(<"${NEXUS_BUILD_LOCK_PID_FILE}")"
    fi

    if [[ -z "${owner}" ]]; then
      if rmdir "${NEXUS_BUILD_LOCK_DIR}" 2>/dev/null; then
        echo "==> Removed stale empty NEXUS build lock"
        continue
      fi
    elif [[ ! "${owner}" =~ ^[0-9]+$ ]]; then
      echo "==> Removing stale NEXUS build lock with invalid pid"
      rm -rf "${NEXUS_BUILD_LOCK_DIR}"
      continue
    fi

    if [[ "${owner}" =~ ^[0-9]+$ ]] && ! kill -0 "${owner}" 2>/dev/null; then
      echo "==> Removing stale NEXUS build lock from pid ${owner}"
      rm -rf "${NEXUS_BUILD_LOCK_DIR}"
      continue
    fi

    if [[ -n "${owner}" ]]; then
      echo "==> Waiting for NEXUS build lock (pid ${owner})..."
    else
      echo "==> Waiting for NEXUS build lock..."
    fi
    sleep 2
  done

  NEXUS_BUILD_LOCK_HELD=1
  printf '%s\n' "$$" >"${NEXUS_BUILD_LOCK_PID_FILE}"
}

nexus_release_build_lock() {
  if [[ "${NEXUS_BUILD_LOCK_HELD}" -eq 1 ]]; then
    rm -rf "${NEXUS_BUILD_LOCK_DIR}"
    NEXUS_BUILD_LOCK_HELD=0
  fi
}

trap nexus_release_build_lock EXIT
