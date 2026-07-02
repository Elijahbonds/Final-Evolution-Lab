#!/usr/bin/env bash
# Compiles GLSL under engine/renderer/shaders/ to embedded SPIR-V headers.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHADER_DIR="${ROOT}/engine/renderer/shaders"
OUT_DIR="${ROOT}/engine/renderer/include/nexus/renderer"
GLSLC="${GLSLC:-glslc}"

if ! command -v "${GLSLC}" >/dev/null 2>&1; then
  echo "glslc not found; install Vulkan SDK or: brew install shaderc" >&2
  exit 1
fi

emit_header() {
  local spv_path="$1"
  local array_name="$2"
  local size_name="$3"
  local out_path="$4"

  python3 - "${spv_path}" "${array_name}" "${size_name}" "${out_path}" <<'PY'
import pathlib
import sys

spv_path, array_name, size_name, out_path = sys.argv[1:5]
data = pathlib.Path(spv_path).read_bytes()
lines = ["#pragma once", "", "#include <cstddef>", "", f"inline constexpr unsigned char {array_name}[] = {{"]
chunk = []
for index, byte in enumerate(data):
    chunk.append(f"0x{byte:02x}")
    if len(chunk) == 16:
        lines.append("  " + ", ".join(chunk) + ",")
        chunk = []
if chunk:
    lines.append("  " + ", ".join(chunk) + ",")
lines.append("};")
lines.append(f"inline constexpr std::size_t {size_name} = {len(data)};")
lines.append("")
pathlib.Path(out_path).write_text("\n".join(lines))
PY
}

compile_pair() {
  local base="$1"
  local vert_array="$2"
  local vert_size="$3"
  local frag_array="$4"
  local frag_size="$5"
  local header_path="$6"

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  "${GLSLC}" -fshader-stage=vertex "${SHADER_DIR}/${base}.vert" -o "${tmp}/${base}.vert.spv"
  "${GLSLC}" -fshader-stage=fragment "${SHADER_DIR}/${base}.frag" -o "${tmp}/${base}.frag.spv"

  {
    emit_header "${tmp}/${base}.vert.spv" "${vert_array}" "${vert_size}" "${tmp}/vert.h"
    cat "${tmp}/vert.h"
    echo
    emit_header "${tmp}/${base}.frag.spv" "${frag_array}" "${frag_size}" "${tmp}/frag.h"
    cat "${tmp}/frag.h"
  } > "${header_path}"

  echo "Wrote ${header_path}"
}

mkdir -p "${OUT_DIR}"
compile_pair "triangle" "kTriangleVertSpv" "kTriangleVertSpv_size" "kTriangleFragSpv" "kTriangleFragSpv_size" \
  "${OUT_DIR}/triangle_shader_spv.h"
compile_pair "arena" "kArenaVertSpv" "kArenaVertSpv_size" "kArenaFragSpv" "kArenaFragSpv_size" \
  "${OUT_DIR}/arena_shader_spv.h"
