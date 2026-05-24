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
    
    import seed_db
    asyncio.run(seed_db.main())
