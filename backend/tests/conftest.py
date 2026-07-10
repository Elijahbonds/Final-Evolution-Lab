import os
import sys
import asyncio
from pathlib import Path

# E2E suites drive a live deployed backend over HTTP (REACT_APP_BACKEND_URL)
# and require a seeded SQL database. In hermetic runs (MOCK_DB=1 with no
# backend URL, e.g. CI) they cannot pass, so skip them at collection time.
_E2E_SUITES = [
    "test_fel_os_education.py",
    "test_final_evolution_lab.py",
    "test_iteration3_features.py",
    "test_iteration4_e3ds.py",
    "test_iteration5_quality_gates.py",
    "test_iteration6_sovereign.py",
    "test_iteration6_vault.py",
    "test_iteration8_biofuel_pass.py",
]

_HERMETIC = (
    os.environ.get("MOCK_DB") == "1"
    and not os.environ.get("REACT_APP_BACKEND_URL")
)

if _HERMETIC:
    collect_ignore = list(_E2E_SUITES)


def pytest_configure(config):
    # Use the pre-seeded session token so that relations like owned videos map correctly
    os.environ['TEST_SESSION_TOKEN'] = 'sess_1777957943281'

    backend_dir = Path(__file__).resolve().parent.parent
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))

    if _HERMETIC:
        return  # no live database to seed; unit suites use in-memory stores

    # Run database seed to start with a fresh slate
    import seed_db
    asyncio.run(seed_db.main())
