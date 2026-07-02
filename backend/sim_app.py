"""
sim_app.py — Minimal ASGI app for the Nexus sim harness (Agent 4).

Serves ONLY the match lifecycle + dunk scoring routers with MOCK_DB=1,
so scripts/simulate_matches.py can run end-to-end without the full
server.py dependency set (LLM SDKs, PayPal, etc.).

Run:
    cd backend && MOCK_DB=1 python3 -m uvicorn sim_app:app --port 8000
"""
import os

os.environ.setdefault("MOCK_DB", "1")

from fastapi import FastAPI

from routers import dunk as dunk_router
from routers import matches as matches_router

app = FastAPI(title="FEL Nexus Sim Harness")
app.include_router(matches_router.router)
app.include_router(dunk_router.router)


@app.get("/health")
async def health():
    return {"status": "healthy", "mock_db": os.environ.get("MOCK_DB") == "1"}
