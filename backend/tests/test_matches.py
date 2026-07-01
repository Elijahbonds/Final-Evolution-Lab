import pytest
from fastapi.testclient import TestClient
import os
import types
from unittest.mock import MagicMock, AsyncMock, patch

# Ensure MOCK_DB mode
os.environ["MOCK_DB"] = "1"

# Stub motor to avoid real Mongo connections
_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor = _motor_patcher.start()
_mock_motor.return_value.__getitem__ = lambda self, n: MagicMock()

# Stub emergentintegrations LLM modules used by other routers
def _stub(name):
    parts = name.split('.')
    for i in range(1, len(parts)+1):
        pkg = '.'.join(parts[:i])
        if pkg not in globals().get('sys', __import__('sys')).modules:
            globals()['sys'].modules[pkg] = types.ModuleType(pkg)
    return globals()['sys'].modules[name]

_stub('emergentintegrations.llm.chat')

from fastapi import FastAPI
from routers.matches import router as match_router, get_current_user
from core import User

app = FastAPI()
app.include_router(match_router)

_USER_A = User(user_id="player_a", email="a@fellab.io", name="Player A", sport="basketball", prq_score=80.0, level=2, xp=200, streak_days=3, coins=100)
_USER_B = User(user_id="player_b", email="b@fellab.io", name="Player B", sport="basketball", prq_score=75.0, level=1, xp=100, streak_days=1, coins=50)

client_a = TestClient(app)
client_b = TestClient(app)


def test_create_and_join_match():
    app.dependency_overrides[get_current_user] = lambda: _USER_A
    resp = client_a.post('/api/matches/create', json={'mode_id': 'basketball_h2h'})
    assert resp.status_code == 200
    data = resp.json()
    mid = data['match_id']
    assert data['state'] == 'waiting' or data.get('status') == 'waiting'

    # player A joins (creator)
    resp = client_a.post('/api/matches/join', json={'match_id': mid, 'user_id': _USER_A.user_id})
    assert resp.status_code == 200
    assert any(p['user_id'] == _USER_A.user_id for p in resp.json()['match']['players'])

    # player B joins
    app.dependency_overrides[get_current_user] = lambda: _USER_B
    resp = client_b.post('/api/matches/join', json={'match_id': mid, 'user_id': _USER_B.user_id})
    assert resp.status_code == 200
    match = resp.json()['match']
    assert match['state'] == 'active'
    assert len(match['players']) >= 2


def test_match_events_persisted():
    # Create match and join two players, then check events store
    app.dependency_overrides[get_current_user] = lambda: _USER_A
    resp = client_a.post('/api/matches/create', json={'mode_id': 'test_mode'})
    mid = resp.json()['match_id']
    client_a.post('/api/matches/join', json={'match_id': mid, 'user_id': _USER_A.user_id})
    app.dependency_overrides[get_current_user] = lambda: _USER_B
    client_b.post('/api/matches/join', json={'match_id': mid, 'user_id': _USER_B.user_id})

    # Wait briefly for simulated events (matches router creates background tasks)
    import time
    time.sleep(2)

    resp = client_a.get(f'/api/matches/{mid}')
    assert resp.status_code == 200
    data = resp.json()
    assert 'events' in data
    assert len(data['events']) >= 1
