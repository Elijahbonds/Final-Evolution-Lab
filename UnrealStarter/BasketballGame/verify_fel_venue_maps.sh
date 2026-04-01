#!/usr/bin/env bash
# Release gate: every MapsToCook venue in DefaultGame.ini must have a matching .umap on disk.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
INI="${PROJECT_DIR}/Config/DefaultGame.ini"
CONTENT="${PROJECT_DIR}/Content"

if [[ ! -f "$INI" ]]; then
	echo "error: missing ${INI}" >&2
	exit 1
fi

if [[ ! -d "$CONTENT" ]]; then
	echo "error: missing Content dir ${CONTENT}" >&2
	exit 1
fi

fail=0
while IFS= read -r line; do
	raw="${line#*FilePath=}"
	raw="${raw#\"}"
	raw="${raw%%\"*}"
	raw="${raw%%)*}"
	if [[ -z "$raw" ]]; then
		continue
	fi
	# /Game/FEL/Venues/Foo/Foo -> Content/FEL/Venues/Foo/Foo.umap
	rel="${raw#/Game/}"
	map_path="${CONTENT}/${rel}.umap"
	if [[ ! -f "$map_path" ]]; then
		echo "MISSING: ${raw} -> expected file ${map_path}" >&2
		fail=1
	fi
done < <(grep '^\s*+MapsToCook=' "$INI" || true)

if [[ "$fail" -ne 0 ]]; then
	echo "verify_fel_venue_maps: FAILED (add .umap or fix MapsToCook paths)" >&2
	exit 1
fi

echo "verify_fel_venue_maps: OK (all MapsToCook paths have .umap under Content/)"
exit 0
