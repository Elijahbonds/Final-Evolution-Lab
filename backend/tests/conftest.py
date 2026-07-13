import os
import sys
import asyncio
from pathlib import Path

def pytest_configure(config):
    # Use the pre-seeded session token so that relations like owned videos map correctly
    os.environ['TEST_SESSION_TOKEN'] = 'sess_1777957943281'
    
    # Run database seed to start with a fresh slate
    backend_dir = Path(__file__).resolve().parent.parent
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))
    
    # Seed the legacy Postgres fixtures when a database is reachable. Gateway
    # contract tests (test_gateway_contract.py) run against in-memory fakes and
    # must stay runnable without Postgres, so a seed failure is non-fatal here;
    # legacy DB-backed tests will fail at test time with a clear message instead
    # of aborting the whole collection with an INTERNALERROR.
    try:
        import seed_db
        asyncio.run(seed_db.main())
    except Exception as exc:  # noqa: BLE001
        print(f"[conftest] WARNING: seed_db skipped ({type(exc).__name__}: {exc}); "
              "Postgres-backed legacy tests will fail, in-memory suites are unaffected.")
