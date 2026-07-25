#!/usr/bin/env python3
"""
watch_assets.py — the safe drag-and-drop inbox. Runs on the Mac mini.

    python3 tools/watch_assets.py              # watch forever
    python3 tools/watch_assets.py --once       # process what's there and exit

Drop files into assets/inbox/ and walk away. Each one is conformed (via
Blender, if available) and validated (always). Clean assets land in
assets/ready/ — the only folder the pipeline will ship from. Rejects land in
assets/rejected/ with a .reasons.txt next to them.

No external dependencies: polls the folder rather than requiring watchdog,
so it runs on a fresh machine with nothing but Python.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
INBOX = os.path.join(ROOT, "assets", "inbox")
READY = os.path.join(ROOT, "assets", "ready")
REJECTED = os.path.join(ROOT, "assets", "rejected")
WORK = os.path.join(ROOT, "assets", ".work")
LEDGER = os.path.join(ROOT, "assets", "fix-ledger.jsonl")

CONFORM = os.path.join(HERE, "fel_conform.py")          # from M65
VALIDATE = os.path.join(HERE, "validate_assets.py")
ACCEPT = (".glb", ".gltf", ".fbx", ".bvh", ".obj", ".dae")


def log(msg):
    print("[WATCH] %s" % msg, flush=True)


def ensure_dirs():
    for d in (INBOX, READY, REJECTED, WORK):
        os.makedirs(d, exist_ok=True)


def blender_available():
    return shutil.which("blender") is not None


def stable(path, checks=3, delay=0.6):
    """Wait until the file stops growing — a large drop may still be copying."""
    last = -1
    for _ in range(checks * 10):
        try:
            size = os.path.getsize(path)
        except OSError:
            return False
        if size == last and size > 0:
            checks -= 1
            if checks <= 0:
                return True
        else:
            checks = 3
        last = size
        time.sleep(delay)
    return False


def run(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def conform(src):
    """Blender conform step. Returns (path, note). Falls through when Blender
    is missing or the input is already a GLB — validation still runs."""
    if not blender_available():
        if src.lower().endswith(".glb"):
            return src, "blender not installed — skipped conform, validating as-is"
        return None, ("blender not installed and input is %s — cannot conform. "
                      "Install Blender or drop a .glb." % os.path.splitext(src)[1])

    out = os.path.join(WORK, os.path.splitext(os.path.basename(src))[0] + ".fel.glb")
    code, output = run([
        "blender", "--background", "--python", CONFORM, "--",
        "--input", src, "--output", out, "--decimate",
    ])
    if code != 0 or not os.path.exists(out):
        return None, "conform failed:\n" + output[-2000:]
    return out, "conformed via Blender"


def validate(path):
    code, output = run([sys.executable, VALIDATE, path])
    return code == 0, output


def reject(src, reasons):
    dest = os.path.join(REJECTED, os.path.basename(src))
    shutil.move(src, dest)
    with open(dest + ".reasons.txt", "w") as fh:
        fh.write(reasons)
    log("REJECTED %s" % os.path.basename(src))


def accept(src, conformed, note, report):
    dest = os.path.join(READY, os.path.basename(conformed))
    shutil.move(conformed, dest)
    if os.path.exists(src) and os.path.abspath(src) != os.path.abspath(dest):
        os.remove(src)
    with open(LEDGER, "a") as fh:
        fh.write(json.dumps({
            "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "source": os.path.basename(src),
            "output": os.path.basename(dest),
            "note": note,
            "validation": report.strip().splitlines()[-1] if report.strip() else "",
        }) + "\n")
    log("READY    %s  (%s)" % (os.path.basename(dest), note))


def process(path):
    name = os.path.basename(path)
    if not name.lower().endswith(ACCEPT):
        log("ignoring %s (unsupported type)" % name)
        return
    if not stable(path):
        log("skipping %s — still being written" % name)
        return

    log("processing %s" % name)
    conformed, note = conform(path)
    if not conformed:
        reject(path, note)
        return

    ok, report = validate(conformed)
    if not ok:
        if os.path.abspath(conformed) != os.path.abspath(path):
            shutil.move(conformed, os.path.join(REJECTED, os.path.basename(conformed)))
            os.remove(path)
            with open(os.path.join(REJECTED, os.path.basename(conformed)) + ".reasons.txt", "w") as fh:
                fh.write(report)
            log("REJECTED %s" % os.path.basename(conformed))
        else:
            reject(path, report)
        return

    accept(path, conformed, note, report)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true")
    ap.add_argument("--interval", type=float, default=2.0)
    args = ap.parse_args()

    ensure_dirs()
    log("inbox=%s" % INBOX)
    log("blender: %s" % ("found" if blender_available() else "NOT INSTALLED (non-GLB drops will be rejected)"))

    while True:
        for entry in sorted(os.listdir(INBOX)):
            full = os.path.join(INBOX, entry)
            if os.path.isfile(full):
                try:
                    process(full)
                except Exception as exc:                      # never die on one bad file
                    log("ERROR on %s: %s" % (entry, exc))
        if args.once:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    sys.exit(main())
