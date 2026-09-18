import os
import sys
import asyncio
from pathlib import Path


def _should_seed_postgres() -> bool:
    if os.environ.get("FEL_SKIP_DB_SEED") == "1" or os.environ.get("MOCK_DB") == "1":
        return False

    database_url = os.environ.get("DATABASE_URL", "")
    if not database_url:
        return True

    postgres_schemes = (
        "postgres://",
        "postgresql://",
        "postgres+asyncpg://",
        "postgresql+asyncpg://",
    )
    return database_url.startswith(postgres_schemes)


def pytest_configure(config):
    # Use the pre-seeded session token so that relations like owned videos map correctly
    os.environ['TEST_SESSION_TOKEN'] = 'sess_1777957943281'

    if not _should_seed_postgres():
        return
    
    # Run database seed to start with a fresh slate
    backend_dir = Path(__file__).resolve().parent.parent
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))
    
    import seed_db
    asyncio.run(seed_db.main())
