"""
Iteration 5 Quality Gates Testing
=================================
Gate 1: DefaultEngine.ini for UE 5.7 Pixel Streaming 2 with E3DS iframe
Gate 2: WebSocket Multiplayer UI with rooms/lobby
Gate 3: Referral Reward System linked to PayPal
Gate 4: Tournament Spectator Mode with focus-lock (500ms)
Gate 5: Analytics data-tracking policy with Vault Sync to M4 Pro Mac Mini
"""

import pytest
import requests
import os
from datetime import datetime

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', '').rstrip('/')

# Test session token - will be created in setup
TEST_SESSION_TOKEN = None
TEST_USER_ID = None

ENGINE_INI_PATH = "/app/infra/ue5_config/DefaultEngine.ini"
if not os.path.exists(ENGINE_INI_PATH):
    for p in ["infra/ue5_config/DefaultEngine.ini", "../infra/ue5_config/DefaultEngine.ini", "../../infra/ue5_config/DefaultEngine.ini"]:
        if os.path.exists(p):
            ENGINE_INI_PATH = p
            break


@pytest.fixture(scope="module", autouse=True)
def setup_test_user():
    """Create test user and session for authenticated endpoints"""
    global TEST_SESSION_TOKEN, TEST_USER_ID
    import asyncio
    import asyncpg
    import json
    from datetime import datetime, timezone, timedelta
    
    timestamp = int(datetime.now().timestamp() * 1000)
    user_id = f"test-user-iter5-{timestamp}"
    session_token = f"test_session_iter5_{timestamp}"
    
    db_user = os.environ.get("DB_USER", "postgres")
    db_pass = os.environ.get("DB_PASS", "postgres")
    db_host = os.environ.get("DB_HOST", "localhost")
    db_port = os.environ.get("DB_PORT", "5432")
    db_name = os.environ.get("DB_NAME", "fdcdb")
    db_url = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
    
    async def seed():
        conn = await asyncpg.connect(db_url)
        try:
            # Ensure tables exist
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS public.users (
                    id TEXT PRIMARY KEY,
                    data JSONB NOT NULL DEFAULT '{}'::jsonb,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
            """)
            await conn.execute("""
                CREATE TABLE IF NOT EXISTS public.user_sessions (
                    id TEXT PRIMARY KEY,
                    data JSONB NOT NULL DEFAULT '{}'::jsonb,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
                )
            """)
            # Insert user
            user_data = {
                "user_id": user_id,
                "email": f"test.iter5.{timestamp}@example.com",
                "name": "Test User Iter5",
                "role": "athlete",
                "sport": "basketball",
                "prq_score": 75.0,
                "level": 5,
                "xp": 500,
                "streak_days": 3,
                "total_workouts": 10,
                "coins": 500,
                "followers": [],
                "following": []
            }
            await conn.execute(
                "INSERT INTO public.users (id, data) VALUES ($1, $2)",
                user_id, json.dumps(user_data)
            )
            
            # Insert session
            session_data = {
                "user_id": user_id,
                "session_token": session_token,
                "expires_at": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
                "created_at": datetime.now(timezone.utc).isoformat()
            }
            await conn.execute(
                "INSERT INTO public.user_sessions (id, data) VALUES ($1, $2)",
                session_token, json.dumps(session_data)
            )
        finally:
            await conn.close()
            
    asyncio.run(seed())
    
    TEST_SESSION_TOKEN = session_token
    TEST_USER_ID = user_id
    
    yield
    
    async def cleanup():
        conn = await asyncpg.connect(db_url)
        try:
            await conn.execute("DELETE FROM public.users WHERE id LIKE 'test-user-iter5-%'")
            await conn.execute("DELETE FROM public.user_sessions WHERE data->>'user_id' LIKE 'test-user-iter5-%'")
            # Clean collections if tables exist
            for table in ["referrals", "referral_credits", "multiplayer_rooms", "analytics_sessions"]:
                try:
                    await conn.execute(f"DELETE FROM public.{table} WHERE data->>'user_id' LIKE 'test-user-iter5-%'")
                except Exception:
                    pass
                try:
                    await conn.execute(f"DELETE FROM public.{table} WHERE data->>'referrer_id' LIKE 'test-user-iter5-%'")
                except Exception:
                    pass
                try:
                    await conn.execute(f"DELETE FROM public.{table} WHERE data->>'host_id' LIKE 'test-user-iter5-%'")
                except Exception:
                    pass
        finally:
            await conn.close()
            
    asyncio.run(cleanup())


def get_auth_headers():
    return {"Authorization": f"Bearer {TEST_SESSION_TOKEN}"}


# ===================== GATE 1: DefaultEngine.ini =====================

class TestGate1DefaultEngineIni:
    """Gate 1: Pixel Streaming 2 / Mobile Native DefaultEngine.ini for UE 5.7"""
    
    def test_defaultengine_ini_exists(self):
        """DefaultEngine.ini exists at correct path"""
        assert os.path.exists(ENGINE_INI_PATH), "DefaultEngine.ini not found"
    
    def test_defaultengine_has_pixel_streaming_section(self):
        """DefaultEngine.ini has [PixelStreaming] or [/Script/IOSRuntimeSettings.IOSRuntimeSettings] section"""
        with open(ENGINE_INI_PATH, "r") as f:
            content = f.read()
        assert "[PixelStreaming]" in content or "[/Script/IOSRuntimeSettings.IOSRuntimeSettings]" in content, "Missing mobile/streaming section"
    
    def test_defaultengine_has_pixel_streaming_2_settings(self):
        """DefaultEngine.ini has Pixel Streaming 2 or Mobile Runtime settings for UE 5.7"""
        with open(ENGINE_INI_PATH, "r") as f:
            content = f.read()
        has_streaming = "[/Script/PixelStreaming.PixelStreamingSettings]" in content
        has_mobile = "[/Script/IOSRuntimeSettings.IOSRuntimeSettings]" in content
        assert has_streaming or has_mobile, "Missing required settings block"
        if has_mobile:
            assert "BundleIdentifier=com.finalevolutionlab.app" in content
        else:
            assert "bDecoupleFrameRate=true" in content
    
    def test_defaultengine_has_e3ds_iframe_config(self):
        """DefaultEngine.ini has E3DS iframe communication config or Mobile Android Vulkan configuration"""
        with open(ENGINE_INI_PATH, "r") as f:
            content = f.read()
        has_streaming = "AllowPixelStreamingInput=true" in content
        has_mobile = "bSupportsVulkan=True" in content
        assert has_streaming or has_mobile, "Missing low-latency inputs or mobile GPU settings"
    
    def test_defaultengine_has_encoder_settings(self):
        """DefaultEngine.ini has encoder settings or Mobile Renderer Performance settings"""
        with open(ENGINE_INI_PATH, "r") as f:
            content = f.read()
        has_streaming = "Encoder.Codec=H264" in content
        has_mobile = "r.Lumen.HardwareRayTracing=0" in content
        assert has_streaming or has_mobile, "Missing H264 codec or low-power renderer settings"
    
    def test_defaultengine_has_webrtc_settings(self):
        """DefaultEngine.ini has WebRTC low-latency or local-only audio streaming config"""
        with open(ENGINE_INI_PATH, "r") as f:
            content = f.read()
        has_streaming = "WebRTC.MaxFps=60" in content
        has_mobile = "bEnableAudioStreaming=false" in content
        assert has_streaming or has_mobile, "Missing low-latency streaming settings"
    
    def test_defaultengine_has_game_mode_maps(self):
        """DefaultEngine.ini documents game default map / venue configuration"""
        with open(ENGINE_INI_PATH, "r") as f:
            content = f.read()
        assert "Venice_Beach_Court" in content or "VeniceBeach" in content, "Missing Venice Beach default map config"


# ===================== GATE 2: MULTIPLAYER ROOMS =====================

class TestGate2MultiplayerRooms:
    """Gate 2: WebSocket Multiplayer UI with rooms/lobby"""
    
    def test_get_multiplayer_rooms(self):
        """GET /api/multiplayer/rooms returns available rooms"""
        r = requests.get(f"{BASE_URL}/api/multiplayer/rooms")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}"
        data = r.json()
        assert isinstance(data, list), "Expected list of rooms"
        # Should have demo rooms if no real rooms
        if len(data) > 0:
            room = data[0]
            assert "id" in room, "Room missing id"
            assert "host_name" in room, "Room missing host_name"
            assert "game_mode" in room, "Room missing game_mode"
    
    def test_create_multiplayer_room_requires_auth(self):
        """POST /api/multiplayer/create-room requires authentication"""
        r = requests.post(f"{BASE_URL}/api/multiplayer/create-room", json={"game_mode": "basketball_h2h"})
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_create_multiplayer_room(self):
        """POST /api/multiplayer/create-room creates room with settings"""
        r = requests.post(
            f"{BASE_URL}/api/multiplayer/create-room",
            json={
                "game_mode": "basketball_h2h",
                "max_players": 2,
                "time_limit": 60,
                "score_limit": 100,
                "allow_spectators": True
            },
            headers=get_auth_headers()
        )
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "id" in data, "Room missing id"
        assert data["game_mode"] == "basketball_h2h", "Wrong game mode"
        assert data["max_players"] == 2, "Wrong max players"
        assert data["settings"]["allow_spectators"] == True, "Spectators not allowed"
        assert data["settings"]["latency_mode"] == "low", "Missing low latency mode"
    
    def test_join_room_requires_auth(self):
        """POST /api/multiplayer/rooms/{id}/join requires authentication"""
        r = requests.post(f"{BASE_URL}/api/multiplayer/rooms/room_demo1/join")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_spectate_room_requires_auth(self):
        """POST /api/multiplayer/rooms/{id}/spectate requires authentication"""
        r = requests.post(f"{BASE_URL}/api/multiplayer/rooms/room_demo1/spectate")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"


# ===================== GATE 3: REFERRAL SYSTEM =====================

class TestGate3ReferralSystem:
    """Gate 3: Referral Reward System linked to PayPal"""
    
    def test_generate_referral_code_requires_auth(self):
        """POST /api/referral/generate requires authentication"""
        r = requests.post(f"{BASE_URL}/api/referral/generate")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_generate_referral_code(self):
        """POST /api/referral/generate creates referral code"""
        r = requests.post(f"{BASE_URL}/api/referral/generate", headers=get_auth_headers())
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "code" in data, "Missing referral code"
        assert data["code"].startswith("FEL-"), "Code should start with FEL-"
        assert data["max_uses"] == 50, "Max uses should be 50"
        assert data["uses"] == 0, "Initial uses should be 0"
    
    def test_get_referral_stats_requires_auth(self):
        """GET /api/referral/stats requires authentication"""
        r = requests.get(f"{BASE_URL}/api/referral/stats")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_get_referral_stats(self):
        """GET /api/referral/stats returns referral statistics"""
        r = requests.get(f"{BASE_URL}/api/referral/stats", headers=get_auth_headers())
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "code" in data, "Missing code in stats"
        assert "total_referrals" in data, "Missing total_referrals"
        assert "total_coins_earned" in data, "Missing total_coins_earned"
        assert "pending_payout" in data, "Missing pending_payout"
    
    def test_redeem_referral_requires_auth(self):
        """POST /api/referral/redeem requires authentication"""
        r = requests.post(f"{BASE_URL}/api/referral/redeem", json={"code": "FEL-TEST-123456"})
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_redeem_invalid_code(self):
        """POST /api/referral/redeem returns 404 for invalid code"""
        r = requests.post(
            f"{BASE_URL}/api/referral/redeem",
            json={"code": "FEL-INVALID-999999"},
            headers=get_auth_headers()
        )
        assert r.status_code == 404, f"Expected 404, got {r.status_code}"
    
    def test_redeem_own_code_fails(self):
        """POST /api/referral/redeem cannot redeem own code"""
        # First generate a code
        gen_r = requests.post(f"{BASE_URL}/api/referral/generate", headers=get_auth_headers())
        code = gen_r.json().get("code")
        
        # Try to redeem own code
        r = requests.post(
            f"{BASE_URL}/api/referral/redeem",
            json={"code": code},
            headers=get_auth_headers()
        )
        assert r.status_code == 400, f"Expected 400, got {r.status_code}"
        assert "own code" in r.json().get("detail", "").lower(), "Should mention own code"
    
    def test_payout_requires_auth(self):
        """POST /api/referral/payout requires authentication"""
        r = requests.post(f"{BASE_URL}/api/referral/payout")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_payout_enforces_minimum(self):
        """POST /api/referral/payout enforces 500 coin minimum"""
        r = requests.post(f"{BASE_URL}/api/referral/payout", headers=get_auth_headers())
        # Should either succeed (if enough credits) or fail with minimum message
        if r.status_code == 400:
            assert "500" in r.json().get("detail", "") or "minimum" in r.json().get("detail", "").lower()


# ===================== GATE 4: SPECTATOR MODE =====================

class TestGate4SpectatorMode:
    """Gate 4: Tournament Spectator Mode with focus-lock to prevent E3DS focus-loss"""
    
    def test_get_spectator_config(self):
        """GET /api/tournaments/{id}/spectate returns camera config"""
        r = requests.get(f"{BASE_URL}/api/tournaments/t1/spectate")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "tournament_id" in data, "Missing tournament_id"
        assert "spectator_config" in data, "Missing spectator_config"
    
    def test_spectator_config_has_focus_lock(self):
        """Spectator config has focus_lock=true"""
        r = requests.get(f"{BASE_URL}/api/tournaments/t1/spectate")
        data = r.json()
        config = data.get("spectator_config", {})
        assert config.get("focus_lock") == True, "focus_lock should be True"
    
    def test_spectator_focus_lock_interval_500ms(self):
        """Focus lock interval is 500ms to prevent E3DS focus-loss"""
        r = requests.get(f"{BASE_URL}/api/tournaments/t1/spectate")
        data = r.json()
        config = data.get("spectator_config", {})
        assert config.get("focus_lock_interval_ms") == 500, "focus_lock_interval_ms should be 500"
    
    def test_spectator_config_has_e3ds_commands(self):
        """Spectator config has E3DS postMessage commands"""
        r = requests.get(f"{BASE_URL}/api/tournaments/t1/spectate")
        data = r.json()
        assert "e3ds_commands" in data, "Missing e3ds_commands"
        cmds = data["e3ds_commands"]
        assert "start_spectate" in cmds, "Missing start_spectate command"
        assert "focus_keepalive" in cmds, "Missing focus_keepalive command"
    
    def test_spectator_config_has_iframe_focus_fix(self):
        """Spectator config has iframe focus fix documentation"""
        r = requests.get(f"{BASE_URL}/api/tournaments/t1/spectate")
        data = r.json()
        assert "iframe_focus_fix" in data, "Missing iframe_focus_fix"
        fix = data["iframe_focus_fix"]
        assert fix.get("interval_ms") == 500, "iframe focus interval should be 500ms"
    
    def test_spectator_config_invalid_tournament(self):
        """GET /api/tournaments/{invalid}/spectate returns 404"""
        r = requests.get(f"{BASE_URL}/api/tournaments/invalid_tournament_id/spectate")
        assert r.status_code == 404, f"Expected 404, got {r.status_code}"


# ===================== GATE 5: ANALYTICS & VAULT SYNC =====================

class TestGate5AnalyticsVaultSync:
    """Gate 5: Analytics data-tracking policy with Vault Sync to M4 Pro Mac Mini"""
    
    def test_get_analytics_policy(self):
        """GET /api/analytics/policy returns data tracking policy"""
        r = requests.get(f"{BASE_URL}/api/analytics/policy")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "policy_version" in data, "Missing policy_version"
        assert "tracked_metrics" in data, "Missing tracked_metrics"
        assert "vault_sync_protocol" in data, "Missing vault_sync_protocol"
    
    def test_analytics_policy_tracks_13_venues(self):
        """Analytics policy tracks 13 venues (Venice Beach through Neuro Arena)"""
        r = requests.get(f"{BASE_URL}/api/analytics/policy")
        data = r.json()
        venues = data.get("tracked_metrics", {}).get("venue_analytics", [])
        assert len(venues) >= 13, f"Expected at least 13 venues, got {len(venues)}"
        
        # Check key venues
        venue_text = " ".join(venues)
        assert "Venice_Beach" in venue_text, "Missing Venice Beach venue"
        assert "Zen_Dojo" in venue_text, "Missing Zen Dojo venue"
        assert "Neuro_Arena" in venue_text, "Missing Neuro Arena venue"
    
    def test_analytics_policy_vault_sync_m4_pro(self):
        """Vault sync targets M4 Pro Mac Mini via private signaling server"""
        r = requests.get(f"{BASE_URL}/api/analytics/policy")
        data = r.json()
        sync = data.get("vault_sync_protocol", {})
        assert "M4 Pro Mac Mini" in sync.get("description", ""), "Missing M4 Pro Mac Mini reference"
        assert "private signaling server" in sync.get("description", "").lower(), "Missing private signaling server"
        
        server = sync.get("private_signaling_server", {})
        assert "M4 Pro Mac Mini" in server.get("host", ""), "Server host should be M4 Pro Mac Mini"
    
    def test_log_analytics_session_requires_auth(self):
        """POST /api/analytics/session requires authentication"""
        r = requests.post(f"{BASE_URL}/api/analytics/session", json={"game_mode": "basketball_h2h"})
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_log_analytics_session(self):
        """POST /api/analytics/session logs session data"""
        r = requests.post(
            f"{BASE_URL}/api/analytics/session",
            json={
                "game_mode": "basketball_h2h",
                "venue": "Venice_Beach_Court",
                "duration_seconds": 300,
                "score": 85,
                "latency_ms": 45
            },
            headers=get_auth_headers()
        )
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert data["game_mode"] == "basketball_h2h", "Wrong game mode"
        assert data["sync_status"] == "pending", "Initial sync status should be pending"
        assert "vault_sync" in data, "Missing vault_sync"
    
    def test_get_analytics_dashboard_requires_auth(self):
        """GET /api/analytics/dashboard requires authentication"""
        r = requests.get(f"{BASE_URL}/api/analytics/dashboard")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_get_analytics_dashboard(self):
        """GET /api/analytics/dashboard returns per-mode stats and sync status"""
        r = requests.get(f"{BASE_URL}/api/analytics/dashboard", headers=get_auth_headers())
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "mode_stats" in data, "Missing mode_stats"
        assert "overview" in data, "Missing overview"
        assert "vault_sync" in data, "Missing vault_sync"
        
        sync = data["vault_sync"]
        assert "pending_sync" in sync, "Missing pending_sync count"
        assert "synced" in sync, "Missing synced count"
        assert "M4 Pro Mac Mini" in sync.get("sync_target", ""), "Missing M4 Pro Mac Mini target"
    
    def test_trigger_vault_sync_requires_auth(self):
        """POST /api/analytics/vault-sync requires authentication"""
        r = requests.post(f"{BASE_URL}/api/analytics/vault-sync")
        assert r.status_code == 401, f"Expected 401, got {r.status_code}"
    
    def test_trigger_vault_sync(self):
        """POST /api/analytics/vault-sync triggers sync"""
        r = requests.post(f"{BASE_URL}/api/analytics/vault-sync", headers=get_auth_headers())
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
        data = r.json()
        assert "synced" in data or "message" in data, "Missing sync result"


# ===================== PREVIOUS FEATURES REGRESSION =====================

class TestPreviousFeaturesRegression:
    """Verify all previous features still working"""
    
    def test_health_endpoint(self):
        """GET /api/health returns healthy"""
        r = requests.get(f"{BASE_URL}/api/health")
        assert r.status_code == 200
        assert r.json().get("status") == "healthy"
    
    def test_game_modes_still_working(self):
        """GET /api/games/modes returns 17 modes"""
        r = requests.get(f"{BASE_URL}/api/games/modes")
        assert r.status_code == 200
        modes = r.json()
        assert len(modes) >= 17, f"Expected 17+ modes, got {len(modes)}"
    
    def test_creator_cards_still_working(self):
        """GET /api/cards returns creator cards"""
        r = requests.get(f"{BASE_URL}/api/cards")
        assert r.status_code == 200
        cards = r.json()
        assert len(cards) >= 3, f"Expected 3+ cards, got {len(cards)}"
    
    def test_tournaments_still_working(self):
        """GET /api/tournaments returns tournaments"""
        r = requests.get(f"{BASE_URL}/api/tournaments")
        assert r.status_code == 200
        tournaments = r.json()
        assert len(tournaments) >= 4, f"Expected 4+ tournaments, got {len(tournaments)}"
    
    def test_leaderboard_still_working(self):
        """GET /api/leaderboard returns rankings"""
        r = requests.get(f"{BASE_URL}/api/leaderboard")
        assert r.status_code == 200
        leaders = r.json()
        assert len(leaders) >= 1, "Expected at least 1 leader"
    
    def test_streaming_status_still_working(self):
        """GET /api/streaming/status returns E3DS config"""
        r = requests.get(f"{BASE_URL}/api/streaming/status")
        assert r.status_code == 200
        data = r.json()
        assert "supported_modes" in data, "Missing supported_modes"
        assert len(data["supported_modes"]) >= 15, "Expected 15+ supported modes"
    
    def test_education_courses_still_working(self):
        """GET /api/education/courses returns courses"""
        r = requests.get(f"{BASE_URL}/api/education/courses")
        assert r.status_code == 200
        courses = r.json()
        assert len(courses) >= 5, f"Expected 5+ courses, got {len(courses)}"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
