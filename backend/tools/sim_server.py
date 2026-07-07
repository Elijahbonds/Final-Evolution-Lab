"""
CI simulation harness server — NOT a production entrypoint.

Boots a minimal FastAPI app that mounts ONLY the match-lifecycle router
(backend/routers/matches.py) with:
  * MOCK_DB=1 forced, so the in-memory store is used (no MongoDB needed), and
  * `get_current_user` overridden to a header-driven stub identity
    (`X-Sim-Player`, default "sim_player_a"), so no session tokens or real
    auth secrets are required in CI.

The production auth path in backend/core.py is untouched; this file simply
never goes through it. Used by .github/workflows/ci.yml (sim job) together
with scripts/simulate_matches.py.

Run:
    MOCK_DB=1 python backend/tools/sim_server.py --port 8811
"""
import argparse
import os
import sys
from pathlib import Path

# Force mock mode BEFORE importing any backend module.
os.environ["MOCK_DB"] = "1"
os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "sim_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "sim-key-unused")

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from fastapi import FastAPI, Request  # noqa: E402

from core import User, get_current_user  # noqa: E402
from routers.matches import router as match_router  # noqa: E402

app = FastAPI(title="FEL Match Simulation Harness (CI only)")
app.include_router(match_router)


async def _sim_user(request: Request) -> User:
    player_id = request.headers.get("X-Sim-Player", "sim_player_a")
    return User(
        user_id=player_id,
        email=f"{player_id}@sim.fellab.io",
        name=player_id.replace("_", " ").title(),
    )


app.dependency_overrides[get_current_user] = _sim_user


@app.get("/health")
async def health():
    return {"status": "healthy", "harness": "sim", "mock_db": True}


if __name__ == "__main__":
    import uvicorn

    parser = argparse.ArgumentParser(description="FEL CI match simulation server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8811)
    args = parser.parse_args()
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")
