# Legacy helper: executes fel_luma_venue_texture_presave.py with FEL_RUN_STAMP=1 (same effect as package_gold_master.sh).
import os
import sys

_ROOT = os.path.dirname(os.path.abspath(__file__))
_PATH = os.path.join(_ROOT, "fel_luma_venue_texture_presave.py")

os.environ.setdefault("FEL_RUN_STAMP", "1")
_plat = os.environ.get("FEL_STAMP_PLATFORM", "").strip().lower()
if not _plat and len(sys.argv) > 1:
    _plat = sys.argv[1].strip().lower()
if not _plat:
    _plat = "ios"
os.environ["FEL_STAMP_PLATFORM"] = _plat

_globals = {"__builtins__": __builtins__}
with open(_PATH, encoding="utf-8") as _f:
    exec(compile(_f.read(), _PATH, "exec"), _globals)
