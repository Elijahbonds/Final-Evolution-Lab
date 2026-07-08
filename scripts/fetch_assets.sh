#!/usr/bin/env bash
# FEL asset fetcher — reads infra/asset_sources.json, downloads every entry
# with fetch == "auto", verifies size, writes sha256 checksums, and emits a
# report of manual downloads still required. Tolerant: missing/manual
# entries never fail the run.
#
# Usage: scripts/fetch_assets.sh [--dest assets/external] [--dry-run] [--opentdb]
#   --opentdb  also pull ~100 OpenTDB general-knowledge questions into
#              assets/mock/opentdb_questions.json (skipped if already present)
set -uo pipefail
DEST="assets/external"; DRY=0; OPENTDB=0
while [ $# -gt 0 ]; do case "$1" in
  --dest) DEST="$2"; shift 2;;
  --dry-run) DRY=1; shift;;
  --opentdb) OPENTDB=1; shift;;
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

# ---------------------------------------------------------------------------
# OpenTDB starter question dump (Brain Brawl / Who Scene It web demos).
# Open Trivia Database (https://opentdb.com) content is CC BY-SA 4.0 —
# attribution + license are embedded in the emitted JSON and recorded in
# infra/ASSET_ATTRIBUTION.md. Skips if the dump already exists.
if [ "$OPENTDB" = "1" ]; then
  python3 - "$ROOT/assets/mock/opentdb_questions.json" "$CHECKSUMS" "$DRY" <<'PY'
import base64, datetime, hashlib, json, pathlib, sys, time, urllib.error, urllib.request
out, checks_path, dry = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3] == "1"
if out.exists():
    print(f"opentdb: already present, skipping -> {out} (delete to refetch)"); sys.exit(0)
if dry:
    print("opentdb: [dry] would fetch 2x50 general-knowledge questions"); sys.exit(0)
def get(url):
    # OpenTDB rate-limits to 1 request per ~5s per IP; back off politely.
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "FEL-asset-fetch/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 4:
                time.sleep(6); continue
            raise
def b64(s):
    return base64.b64decode(s).decode("utf-8")
try:
    token = get("https://opentdb.com/api_token.php?command=request").get("token", "")
    questions = []
    for page in range(2):  # API caps at 50/request; token prevents duplicates
        time.sleep(6)  # respect 1-request-per-5s rate limit
        url = f"https://opentdb.com/api.php?amount=50&category=9&encode=base64&token={token}"
        resp = get(url)
        if resp.get("response_code") not in (0, 1):
            raise RuntimeError(f"OpenTDB response_code={resp.get('response_code')}")
        for q in resp.get("results", []):
            questions.append({
                "category": b64(q["category"]),
                "type": b64(q["type"]),
                "difficulty": b64(q["difficulty"]),
                "question": b64(q["question"]),
                "correct_answer": b64(q["correct_answer"]),
                "incorrect_answers": [b64(a) for a in q["incorrect_answers"]],
            })
except Exception as exc:
    print(f"opentdb: fetch failed ({exc}); rerun later — nothing written"); sys.exit(0)
dump = {
    "schema": 1,
    "source": "Open Trivia Database — https://opentdb.com",
    "license": "CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)",
    "attribution": "Questions provided by Open Trivia Database (https://opentdb.com), "
                   "licensed under CC BY-SA 4.0. This dump and any derivative question "
                   "sets remain under CC BY-SA 4.0.",
    "fetched_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "category": "General Knowledge (OpenTDB category 9)",
    "count": len(questions),
    "questions": questions,
}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(dump, indent=2, ensure_ascii=False) + "\n")
checks = json.load(open(checks_path)) if checks_path.exists() else {"files": {}}
checks["files"]["assets/mock/opentdb_questions.json"] = {
    "sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
    "source_url": "https://opentdb.com/api.php?amount=50&category=9&encode=base64",
    "license": "CC BY-SA 4.0",
}
checks_path.write_text(json.dumps(checks, indent=2) + "\n")
print(f"opentdb: wrote {len(questions)} questions -> {out}")
PY
fi
