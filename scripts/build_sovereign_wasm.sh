#!/usr/bin/env bash
# Sovereign web target — WebGPU / WASM packaging hooks.
# Unreal Engine 5.2+ does not ship first-party HTML5; typical paths are:
#   - Pixel Streaming + web client (recommended for FEL arenas), or
#   - Custom Emscripten fork with WebGPU RHI (advanced).
# This script exports env defaults consumed by CI and copies PWA assets next to your static host root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FEL_WEBGPU_WASM="${FEL_WEBGPU_WASM:-1}"
export FEL_PWA_ROOT="${FEL_PWA_ROOT:-$ROOT/web/fel-sovereign}"
echo "FEL_WEBGPU_WASM=$FEL_WEBGPU_WASM"
echo "PWA manifest: $FEL_PWA_ROOT/manifest.webmanifest"
echo "Next: deploy web/fel-sovereign/ to finalevolutiongroup.com with COOP/COEP headers if using cross-origin isolation for WASM threads."
