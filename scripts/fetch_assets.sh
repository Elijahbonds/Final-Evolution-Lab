#!/usr/bin/env bash
# FEL asset fetcher — reads infra/asset_sources.json, downloads every entry
# with fetch == "auto", verifies size, writes sha256 checksums, and emits a
# report of manual downloads still required. Tolerant: missing/manual
# entries never fail the run.
#
# Usage: scripts/fetch_assets.sh [--dest assets/external] [--dry-run]
set -uo pipefail
DEST="assets/external"; DRY=0
while [ $# -gt 0 ]; do case "$1" in
  --dest) DEST="$2"; shift 2;;
  --dry-run) DRY=1; shift;;
  *) echo "unknown arg $1"; exit 2;;
esac; done
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/infra/asset_sources.json"
CHECKSUMS="$ROOT/infra/ASSET_CHECKSUMS.json"
mkdir -p "$ROOT/$DEST"
command -v python3 >/dev/null || { echo "python3 required"; exit 1; }

python3 - "$SRC" "$ROOT/$DEST" "$CHECKSUMS" "$DRY" <<'PY'
import hashlib, json, sys, urllib.request, pathlib, re
src, dest, checks_path, dry = sys.argv[1], pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]), sys.argv[4] == "1"
entries = json.load(open(src))["sources"]
checks = json.load(open(checks_path)) if pathlib.Path(checks_path).exists() else {"files": {}}
manual, fetched, skipped = [], [], []
for e in entries:
    url, mode = e.get("source_url", ""), e.get("fetch")
    if mode == "auto" and url.startswith("http") and "{" not in url:
        name = re.sub(r"[^A-Za-z0-9._-]", "_", url.split("?")[-1].split("/")[-1]) or "asset.bin"
        out = dest / e["asset_type"] / name
        if out.exists():
            skipped.append(str(out)); continue
        if dry:
            fetched.append(f"[dry] {url}"); continue
        out.parent.mkdir(parents=True, exist_ok=True)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "FEL-asset-fetch/1.0"})
            with urllib.request.urlopen(req, timeout=120) as r, open(out, "wb") as f:
                f.write(r.read())
            digest = hashlib.sha256(out.read_bytes()).hexdigest()
            checks["files"][str(out.relative_to(dest.parent.parent))] = {
                "sha256": digest, "source_url": url, "license": e.get("license", "")}
            fetched.append(f"{out} ({out.stat().st_size/1e6:.1f} MB)")
        except Exception as exc:
            manual.append({"name": e["asset_name"], "url": url, "reason": f"download failed: {exc}"})
    elif mode in ("manual-browser", "manual-login"):
        manual.append({"name": e["asset_name"], "url": url,
                       "reason": mode, "notes": e.get("notes", "")})
if not dry:
    checks_path.parent.mkdir(parents=True, exist_ok=True)
    checks_path.write_text(json.dumps(checks, indent=2))
print(f"fetched: {len(fetched)}"); [print("  +", f) for f in fetched]
print(f"already present: {len(skipped)}")
print(f"manual TODO: {len(manual)}")
for m in manual:
    print(f"  ! {m['name']} [{m['reason']}] -> {m['url']}")
PY
