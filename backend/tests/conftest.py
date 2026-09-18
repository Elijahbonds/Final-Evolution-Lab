import os
import sys
import asyncio
import socket
from urllib.parse import urlparse
from pathlib import Path

def pytest_configure(config):
    # Use the pre-seeded session token so that relations like owned videos map correctly
    os.environ['TEST_SESSION_TOKEN'] = 'sess_1777957943281'
    if os.environ.get("MOCK_DB") == "1" or os.environ.get("SKIP_DB_SEED") == "1":
        return
    
    # Run database seed to start with a fresh slate
    backend_dir = Path(__file__).resolve().parent.parent
    if str(backend_dir) not in sys.path:
        sys.path.insert(0, str(backend_dir))

    database_url = os.environ.get("DATABASE_URL")
    parsed = urlparse(database_url.replace("+asyncpg", "")) if database_url else None
    db_host = parsed.hostname if parsed and parsed.hostname else os.environ.get("DB_HOST", "localhost")
    db_port = parsed.port if parsed and parsed.port else int(os.environ.get("DB_PORT", "5432"))
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(0.25)
        try:
            reachable = probe.connect_ex((db_host, db_port)) == 0
        except OSError:
            reachable = False
        if not reachable:
            return
    
    import seed_db
    asyncio.run(seed_db.main())
