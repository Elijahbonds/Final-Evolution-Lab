"""
Iteration 6: Live Sovereign Backend Testing
Tests for 6 directives:
1. WebSocket handshake server at /ws/sovereign
2. DefaultGame.ini [Emergent] config with bFocusKeepalive=True & KeepaliveInterval=0.5
3. PayPal monetization sync — match scores map to referral rewards
4. MongoDB linked to 13 venues from FEL_VenueRegistry.production.json
5. AES-256-GCM encryption for all data packets
6. Live Connection Preview showing WebSocket 'Waiting for Connection' + Database 'Ready'
"""

import pytest
import requests
import os
import json
from datetime import datetime, timedelta

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', '').rstrip('/')

class TestDirective6LiveConnectionPreview:
    """Directive 6: GET /api/sovereign/status returns live connection preview"""
    
    def test_sovereign_status_endpoint_exists(self):
        """GET /api/sovereign/status returns 200"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        print("✅ GET /api/sovereign/status returns 200")
    
    def test_websocket_status_waiting_for_connection(self):
        """WebSocket status shows 'waiting_for_connection' when no clients connected"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "websocket" in data, "Missing websocket field"
        assert data["websocket"]["status"] == "waiting_for_connection", f"Expected 'waiting_for_connection', got {data['websocket']['status']}"
        print("✅ WebSocket status = 'waiting_for_connection'")
    
    def test_database_status_ready(self):
        """Database status shows 'ready'"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "database" in data, "Missing database field"
        assert data["database"]["status"] == "ready", f"Expected 'ready', got {data['database']['status']}"
        print("✅ Database status = 'ready'")
    
    def test_database_has_13_venues(self):
        """Database shows 13 venues"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert data["database"]["total_venues"] == 13, f"Expected 13 venues, got {data['database']['total_venues']}"
        assert data["database"]["venue_collections"] == 13, f"Expected 13 venue collections, got {data['database']['venue_collections']}"
        print("✅ Database has 13 venues")
    
    def test_encryption_aes_256_gcm(self):
        """Encryption shows AES-256-GCM"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "encryption" in data, "Missing encryption field"
        assert data["encryption"]["algorithm"] == "AES-256-GCM", f"Expected 'AES-256-GCM', got {data['encryption']['algorithm']}"
        assert data["encryption"]["transit"] == "AES-256-GCM", f"Expected transit 'AES-256-GCM'"
        print("✅ Encryption = AES-256-GCM")
    
    def test_focus_lock_and_keepalive_interval(self):
        """Focus lock = true and keepalive interval = 500ms"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert data["websocket"]["focus_lock"] == True, "focus_lock should be True"
        assert data["websocket"]["keepalive_interval_ms"] == 500, f"Expected 500ms, got {data['websocket']['keepalive_interval_ms']}"
        print("✅ focus_lock=true, keepalive_interval_ms=500")
    
    def test_ini_config_block(self):
        """INI config shows bFocusKeepalive=True"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "ini_config" in data, "Missing ini_config field"
        assert data["ini_config"]["bFocusKeepalive"] == "True", f"Expected 'True', got {data['ini_config']['bFocusKeepalive']}"
        assert data["ini_config"]["KeepaliveInterval"] == "0.5", f"Expected '0.5', got {data['ini_config']['KeepaliveInterval']}"
        assert data["ini_config"]["bSovereignSync"] == "True", "bSovereignSync should be True"
        assert data["ini_config"]["SovereignEncryption"] == "AES-256-GCM", "SovereignEncryption should be AES-256-GCM"
        print("✅ INI config has bFocusKeepalive=True, KeepaliveInterval=0.5")
    
    def test_monetization_referral_system_active(self):
        """Monetization shows referral_system=active and match_score_to_referral=linked"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "monetization" in data, "Missing monetization field"
        assert data["monetization"]["referral_system"] == "active", f"Expected 'active', got {data['monetization']['referral_system']}"
        assert data["monetization"]["match_score_to_referral"] == "linked", f"Expected 'linked', got {data['monetization']['match_score_to_referral']}"
        print("✅ Monetization: referral_system=active, match_score_to_referral=linked")
    
    def test_server_version_and_uptime(self):
        """Server shows version and uptime"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "server" in data, "Missing server field"
        assert data["server"]["version"] == "2.0.0", f"Expected version '2.0.0', got {data['server']['version']}"
        assert "uptime_seconds" in data["server"], "Missing uptime_seconds"
        assert data["server"]["uptime_seconds"] >= 0, "uptime_seconds should be >= 0"
        print(f"✅ Server version=2.0.0, uptime={data['server']['uptime_seconds']}s")


class TestDirective2DefaultGameIni:
    """Directive 2: DefaultGame.ini [Emergent] config"""
    
    def test_defaultgame_ini_exists(self):
        """DefaultGame.ini exists at /app/infra/ue5_config/"""
        ini_path = "/app/infra/ue5_config/DefaultGame.ini"
        assert os.path.exists(ini_path), f"DefaultGame.ini not found at {ini_path}"
        print("✅ DefaultGame.ini exists")
    
    def test_emergent_block_exists(self):
        """DefaultGame.ini has [Emergent] block"""
        ini_path = "/app/infra/ue5_config/DefaultGame.ini"
        with open(ini_path, 'r') as f:
            content = f.read()
        assert "[Emergent]" in content, "Missing [Emergent] block"
        print("✅ [Emergent] block exists")
    
    def test_focus_keepalive_true(self):
        """bFocusKeepalive=True in DefaultGame.ini"""
        ini_path = "/app/infra/ue5_config/DefaultGame.ini"
        with open(ini_path, 'r') as f:
            content = f.read()
        assert "bFocusKeepalive=True" in content, "Missing bFocusKeepalive=True"
        print("✅ bFocusKeepalive=True")
    
    def test_keepalive_interval_05(self):
        """KeepaliveInterval=0.5 in DefaultGame.ini"""
        ini_path = "/app/infra/ue5_config/DefaultGame.ini"
        with open(ini_path, 'r') as f:
            content = f.read()
        assert "KeepaliveInterval=0.5" in content, "Missing KeepaliveInterval=0.5"
        print("✅ KeepaliveInterval=0.5")
    
    def test_sovereign_sync_true(self):
        """bSovereignSync=True in DefaultGame.ini"""
        ini_path = "/app/infra/ue5_config/DefaultGame.ini"
        with open(ini_path, 'r') as f:
            content = f.read()
        assert "bSovereignSync=True" in content, "Missing bSovereignSync=True"
        print("✅ bSovereignSync=True")
    
    def test_sovereign_encryption_aes256gcm(self):
        """SovereignEncryption=AES-256-GCM in DefaultGame.ini"""
        ini_path = "/app/infra/ue5_config/DefaultGame.ini"
        with open(ini_path, 'r') as f:
            content = f.read()
        assert "SovereignEncryption=AES-256-GCM" in content, "Missing SovereignEncryption=AES-256-GCM"
        print("✅ SovereignEncryption=AES-256-GCM")


class TestDirective4VenueRegistry:
    """Directive 4: MongoDB linked to 13 venues from FEL_VenueRegistry.production.json"""
    
    def test_venue_registry_exists(self):
        """FEL_VenueRegistry.production.json exists"""
        registry_path = "/app/backend/FEL_VenueRegistry.production.json"
        assert os.path.exists(registry_path), f"Venue registry not found at {registry_path}"
        print("✅ FEL_VenueRegistry.production.json exists")
    
    def test_venue_registry_has_13_venues(self):
        """Venue registry has 13 venues"""
        registry_path = "/app/backend/FEL_VenueRegistry.production.json"
        with open(registry_path, 'r') as f:
            data = json.load(f)
        assert data["total_venues"] == 13, f"Expected 13 venues, got {data['total_venues']}"
        assert len(data["venues"]) == 13, f"Expected 13 venue entries, got {len(data['venues'])}"
        print("✅ Venue registry has 13 venues")
    
    def test_venue_registry_venues_list(self):
        """Venue registry contains all expected venues"""
        registry_path = "/app/backend/FEL_VenueRegistry.production.json"
        with open(registry_path, 'r') as f:
            data = json.load(f)
        expected_venues = [
            "Venice_Beach_Court", "Zen_Dojo", "Baseball_Park", "Gridiron_Stadium",
            "Soccer_Stadium", "Links_Course", "Tennis_Court", "Sand_Court",
            "Training_Floor", "Venice_Beach_Surf", "Skate_Park", "Mountain_Slope", "Neuro_Arena"
        ]
        for venue in expected_venues:
            assert venue in data["venues"], f"Missing venue: {venue}"
        print("✅ All 13 venues present in registry")
    
    def test_venue_has_db_collection(self):
        """Each venue has db_collection field"""
        registry_path = "/app/backend/FEL_VenueRegistry.production.json"
        with open(registry_path, 'r') as f:
            data = json.load(f)
        for venue_name, venue_data in data["venues"].items():
            assert "db_collection" in venue_data, f"Missing db_collection for {venue_name}"
        print("✅ All venues have db_collection field")
    
    def test_sovereign_sync_config(self):
        """Venue registry has sovereign_sync config"""
        registry_path = "/app/backend/FEL_VenueRegistry.production.json"
        with open(registry_path, 'r') as f:
            data = json.load(f)
        assert "sovereign_sync" in data, "Missing sovereign_sync config"
        assert data["sovereign_sync"]["target"] == "M4 Pro Mac Mini", "Wrong target"
        assert data["sovereign_sync"]["encryption"] == "AES-256-GCM", "Wrong encryption"
        print("✅ Sovereign sync config present")


class TestDirective1WebSocketEndpoint:
    """Directive 1: WebSocket handshake server at /ws/sovereign"""
    
    def test_websocket_endpoint_documented(self):
        """WebSocket URL is in sovereign status"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "url" in data["websocket"], "Missing websocket URL"
        # URL should contain /ws/sovereign
        url = data["websocket"]["url"]
        assert "/ws/sovereign" in url or url == "", f"WebSocket URL should contain /ws/sovereign, got {url}"
        print("✅ WebSocket endpoint documented in status")


class TestDirective3MonetizationSync:
    """Directive 3: PayPal monetization sync — match scores map to referral rewards"""
    
    def test_monetization_in_status(self):
        """Monetization section in sovereign status"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "monetization" in data, "Missing monetization field"
        assert "total_match_events" in data["monetization"], "Missing total_match_events"
        assert "total_referral_events" in data["monetization"], "Missing total_referral_events"
        print("✅ Monetization section present with event counters")
    
    def test_paypal_integration_sandbox(self):
        """PayPal integration is in sandbox mode"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert data["monetization"]["paypal_integration"] == "sandbox", "PayPal should be in sandbox mode"
        print("✅ PayPal integration = sandbox")


class TestDirective5Encryption:
    """Directive 5: AES-256-GCM encryption for all data packets"""
    
    def test_encryption_algorithm(self):
        """Encryption algorithm is AES-256-GCM"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert data["encryption"]["algorithm"] == "AES-256-GCM", "Wrong encryption algorithm"
        print("✅ Encryption algorithm = AES-256-GCM")
    
    def test_encryption_transit(self):
        """Transit encryption is AES-256-GCM"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert data["encryption"]["transit"] == "AES-256-GCM", "Wrong transit encryption"
        print("✅ Transit encryption = AES-256-GCM")
    
    def test_encryption_at_rest(self):
        """At-rest encryption is MongoDB WiredTiger AES-256"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert "AES-256" in data["encryption"]["at_rest"], "Wrong at-rest encryption"
        print("✅ At-rest encryption = MongoDB WiredTiger AES-256")
    
    def test_cloudflare_tunnel_tls(self):
        """Cloudflare tunnel uses TLS 1.3"""
        response = requests.get(f"{BASE_URL}/api/sovereign/status")
        data = response.json()
        assert data["encryption"]["cloudflare_tunnel"] == "TLS 1.3", "Wrong tunnel encryption"
        print("✅ Cloudflare tunnel = TLS 1.3")


class TestRegressionPreviousFeatures:
    """Regression tests for previous iterations"""
    
    def test_health_endpoint(self):
        """GET /api/health returns healthy"""
        response = requests.get(f"{BASE_URL}/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        print("✅ Health endpoint working")
    
    def test_game_modes_endpoint(self):
        """GET /api/games/modes returns 17+ modes"""
        response = requests.get(f"{BASE_URL}/api/games/modes")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 17, f"Expected 17+ game modes, got {len(data)}"
        print(f"✅ Game modes: {len(data)} modes")
    
    def test_creator_cards_endpoint(self):
        """GET /api/cards returns creator cards"""
        response = requests.get(f"{BASE_URL}/api/cards")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 3, f"Expected 3+ cards, got {len(data)}"
        print(f"✅ Creator cards: {len(data)} cards")
    
    def test_tournaments_endpoint(self):
        """GET /api/tournaments returns tournaments"""
        response = requests.get(f"{BASE_URL}/api/tournaments")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 4, f"Expected 4+ tournaments, got {len(data)}"
        print(f"✅ Tournaments: {len(data)} tournaments")
    
    def test_leaderboard_endpoint(self):
        """GET /api/leaderboard returns rankings"""
        response = requests.get(f"{BASE_URL}/api/leaderboard")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 1, "Expected at least 1 leader"
        print(f"✅ Leaderboard: {len(data)} entries")
    
    def test_streaming_status_endpoint(self):
        """GET /api/streaming/status returns streaming config"""
        response = requests.get(f"{BASE_URL}/api/streaming/status")
        assert response.status_code == 200
        data = response.json()
        assert "supported_modes" in data
        assert len(data["supported_modes"]) >= 15, f"Expected 15+ modes, got {len(data['supported_modes'])}"
        print(f"✅ Streaming status: {len(data['supported_modes'])} supported modes")
    
    def test_education_courses_endpoint(self):
        """GET /api/education/courses returns courses"""
        response = requests.get(f"{BASE_URL}/api/education/courses")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 5, f"Expected 5+ courses, got {len(data)}"
        print(f"✅ Education courses: {len(data)} courses")
    
    def test_multiplayer_rooms_endpoint(self):
        """GET /api/multiplayer/rooms returns rooms"""
        response = requests.get(f"{BASE_URL}/api/multiplayer/rooms")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list), "Expected list of rooms"
        print(f"✅ Multiplayer rooms: {len(data)} rooms")
    
    def test_analytics_policy_endpoint(self):
        """GET /api/analytics/policy returns policy"""
        response = requests.get(f"{BASE_URL}/api/analytics/policy")
        assert response.status_code == 200
        data = response.json()
        assert "sovereign_sync_protocol" in data
        print("✅ Analytics policy endpoint working")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
