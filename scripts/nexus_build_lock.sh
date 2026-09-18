#!/usr/bin/env bash
# Portable lock for scripts that mutate shared CMake build directories.

nexus_acquire_build_lock() {
  local root="${1:?repo root is required}"
  local key="${root//[^[:alnum:]]/_}"
  local lock_root="${TMPDIR:-/tmp}"
  NEXUS_BUILD_LOCK_DIR="${lock_root}/nexus-build-${key}.lock"

  local announced=0
  while ! mkdir "${NEXUS_BUILD_LOCK_DIR}" 2>/dev/null; do
    local lock_pid=""
    if [[ -f "${NEXUS_BUILD_LOCK_DIR}/pid" ]]; then
      lock_pid="$(<"${NEXUS_BUILD_LOCK_DIR}/pid")"
    fi

    if [[ "${lock_pid}" =~ ^[0-9]+$ ]] && ! kill -0 "${lock_pid}" 2>/dev/null; then
      rm -rf "${NEXUS_BUILD_LOCK_DIR}"
      continue
    fi

    if [[ "${announced}" -eq 0 ]]; then
      echo "==> Waiting for NEXUS build lock (${lock_pid:-unknown pid})"
      announced=1
    fi
    sleep 2
  done

  printf '%s\n' "$$" >"${NEXUS_BUILD_LOCK_DIR}/pid"
  trap nexus_release_build_lock EXIT INT TERM
}

nexus_release_build_lock() {
  if [[ -n "${NEXUS_BUILD_LOCK_DIR:-}" && -f "${NEXUS_BUILD_LOCK_DIR}/pid" ]]; then
    local lock_pid
    lock_pid="$(<"${NEXUS_BUILD_LOCK_DIR}/pid")"
    if [[ "${lock_pid}" == "$$" ]]; then
      rm -rf "${NEXUS_BUILD_LOCK_DIR}"
    fi
  fi
}
