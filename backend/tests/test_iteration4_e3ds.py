"""
Iteration 4 Tests: Eagle 3D Streaming (E3DS) Integration
Tests streaming status, connect, and launch-mode endpoints
"""
import pytest
import requests
import os
from datetime import datetime, timedelta

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', 'http://localhost:8000').rstrip('/')

# Test session token created for iteration 4 testing
TEST_SESSION_TOKEN = "test_session_iter4_1776470135373"

@pytest.fixture
def api_client():
    """Shared requests session"""
    session = requests.Session()
    session.headers.update({"Content-Type": "application/json"})
    return session

@pytest.fixture
def authenticated_client(api_client):
    """Session with auth header"""
    api_client.headers.update({"Authorization": f"Bearer {TEST_SESSION_TOKEN}"})
    return api_client


class TestStreamingStatus:
    """Tests for GET /api/streaming/status endpoint"""
    
    def test_streaming_status_returns_mode_maps(self, api_client):
        """Streaming status should return E3DS configuration with full UE mode registry"""
        response = api_client.get(f"{BASE_URL}/api/streaming/status")
        assert response.status_code == 200
        
        data = response.json()
        assert "mode_maps" in data
        assert "supported_modes" in data
        
        mode_maps = data["mode_maps"]
        assert len(mode_maps) == 16

        expected_mappings = {
            "basketball_h2h": "Venice_Beach_Court",
            "basketball_dunk": "Venice_Beach_Court",
            "basketball_3v3": "Venice_Beach_Court",
            "karate_h2h": "Zen_Dojo",
            "karate_endless": "Zen_Dojo",
            "baseball": "Baseball_Park",
            "football": "Gridiron_Stadium",
            "soccer": "Soccer_Stadium",
            "golf": "Links_Course",
            "tennis": "Tennis_Court",
            "volleyball": "Sand_Court",
            "gymnastics": "Training_Floor",
            "surfing": "Venice_Beach_Surf",
            "skateboarding": "Skate_Park",
            "snowboarding": "Mountain_Slope",
            "brain_brawl": "Neuro_Arena",
        }
        
        for mode, expected_map in expected_mappings.items():
            assert mode in mode_maps, f"Missing mode: {mode}"
            assert mode_maps[mode] == expected_map, f"Wrong map for {mode}"
    
    def test_streaming_status_has_required_fields(self, api_client):
        """Streaming status should have all required fields"""
        response = api_client.get(f"{BASE_URL}/api/streaming/status")
        assert response.status_code == 200
        
        data = response.json()
        required_fields = ["available", "stream_url", "iframe_url", "provider", "message", "supported_modes", "mode_maps"]
        for field in required_fields:
            assert field in data, f"Missing field: {field}"
    
    def test_streaming_status_supported_modes_count(self, api_client):
        """Should have 16 supported Unreal / E3DS game modes (excludes web-only shop)"""
        response = api_client.get(f"{BASE_URL}/api/streaming/status")
        assert response.status_code == 200
        
        data = response.json()
        assert len(data["supported_modes"]) == 16


class TestStreamingConnect:
    """Tests for POST /api/streaming/connect endpoint"""
    
    def test_connect_requires_auth(self, api_client):
        """Connect endpoint should require authentication"""
        response = api_client.post(f"{BASE_URL}/api/streaming/connect", json={
            "stream_url": "https://test.stream.url"
        })
        assert response.status_code == 401
    
    def test_connect_requires_stream_url(self, authenticated_client):
        """Connect should require stream_url parameter"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/connect", json={})
        assert response.status_code == 400
        assert "stream_url required" in response.json().get("detail", "")
    
    def test_connect_persists_url_and_updates_status(self, authenticated_client, api_client):
        """Connect should persist E3DS URL and update status to available"""
        test_url = "https://stream.eagle3dstreaming.com/test-iter4-connect"
        
        # Connect with stream URL
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/connect", json={
            "stream_url": test_url
        })
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "connected"
        assert data["stream_url"] == test_url
        
        # Verify status is now available
        status_response = api_client.get(f"{BASE_URL}/api/streaming/status")
        assert status_response.status_code == 200
        
        status_data = status_response.json()
        assert status_data["available"] == True
        assert status_data["stream_url"] == test_url
        assert status_data["provider"] == "eagle3d"
    
    def test_connect_with_iframe_url(self, authenticated_client):
        """Connect should accept optional iframe_url"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/connect", json={
            "stream_url": "https://stream.eagle3dstreaming.com/app-123",
            "iframe_url": "https://stream.eagle3dstreaming.com/view/app-123"
        })
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "connected"
        assert data["iframe_url"] == "https://stream.eagle3dstreaming.com/view/app-123"


class TestStreamingLaunchMode:
    """Tests for POST /api/streaming/launch-mode endpoint"""
    
    def test_launch_mode_requires_auth(self, api_client):
        """Launch mode should require authentication"""
        response = api_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "basketball_h2h"
        })
        assert response.status_code == 401
    
    def test_launch_mode_returns_correct_map_basketball(self, authenticated_client):
        """Launch mode should return correct map for basketball_h2h"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "basketball_h2h"
        })
        assert response.status_code == 200
        
        data = response.json()
        assert data["mode_id"] == "basketball_h2h"
        assert data["map"] == "Venice_Beach_Court"
        assert "command" in data
        assert data["command"]["cmd"] == "ueapp04"
        assert "ServerTravel" in data["command"]["value"]
        assert "Venice_Beach_Court" in data["command"]["value"]["ServerTravel"]
    
    def test_launch_mode_returns_correct_map_karate(self, authenticated_client):
        """Launch mode should return correct map for karate_h2h"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "karate_h2h"
        })
        assert response.status_code == 200
        
        data = response.json()
        assert data["mode_id"] == "karate_h2h"
        assert data["map"] == "Zen_Dojo"
    
    def test_launch_mode_returns_correct_map_soccer(self, authenticated_client):
        """Launch mode should return correct map for soccer"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "soccer"
        })
        assert response.status_code == 200
        
        data = response.json()
        assert data["mode_id"] == "soccer"
        assert data["map"] == "Soccer_Stadium"
    
    def test_launch_mode_returns_correct_map_surfing(self, authenticated_client):
        """Launch mode should return correct map for surfing"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "surfing"
        })
        assert response.status_code == 200
        
        data = response.json()
        assert data["mode_id"] == "surfing"
        assert data["map"] == "Venice_Beach_Surf"
    
    def test_launch_mode_returns_404_for_invalid_mode(self, authenticated_client):
        """Launch mode should return 404 for invalid mode"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "invalid_mode_xyz"
        })
        assert response.status_code == 404
        assert "Mode not found" in response.json().get("detail", "")
    
    def test_launch_mode_returns_404_for_shop_mode(self, authenticated_client):
        """Launch mode should return 404 for non-playable modes like market_browse"""
        response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
            "mode_id": "market_browse"
        })
        assert response.status_code == 404
    
    def test_launch_mode_all_ue_modes(self, authenticated_client):
        """Each registered UE mode maps to the correct Unreal map token"""
        mode_map_pairs = [
            ("basketball_h2h", "Venice_Beach_Court"),
            ("basketball_dunk", "Venice_Beach_Court"),
            ("basketball_3v3", "Venice_Beach_Court"),
            ("karate_h2h", "Zen_Dojo"),
            ("karate_endless", "Zen_Dojo"),
            ("baseball", "Baseball_Park"),
            ("football", "Gridiron_Stadium"),
            ("soccer", "Soccer_Stadium"),
            ("golf", "Links_Course"),
            ("tennis", "Tennis_Court"),
            ("volleyball", "Sand_Court"),
            ("gymnastics", "Training_Floor"),
            ("surfing", "Venice_Beach_Surf"),
            ("skateboarding", "Skate_Park"),
            ("snowboarding", "Mountain_Slope"),
            ("brain_brawl", "Neuro_Arena"),
        ]
        
        for mode_id, expected_map in mode_map_pairs:
            response = authenticated_client.post(f"{BASE_URL}/api/streaming/launch-mode", json={
                "mode_id": mode_id
            })
            assert response.status_code == 200, f"Failed for mode: {mode_id}"
            data = response.json()
            assert data["map"] == expected_map, f"Wrong map for {mode_id}: expected {expected_map}, got {data['map']}"


class TestPreviousFeaturesStillWorking:
    """Verify previous iteration features still work"""
    
    def test_game_modes_endpoint(self, api_client):
        """Game modes should still return 19 registered modes"""
        response = api_client.get(f"{BASE_URL}/api/games/modes")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 19
    
    def test_creator_cards_endpoint(self, api_client):
        """Creator cards should still return cards"""
        response = api_client.get(f"{BASE_URL}/api/cards")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 3
    
    def test_streaks_endpoint(self, authenticated_client):
        """Streaks endpoint should still work"""
        response = authenticated_client.get(f"{BASE_URL}/api/streaks")
        assert response.status_code == 200
    
    def test_social_athletes_endpoint(self, api_client):
        """Social athletes endpoint should still work"""
        response = api_client.get(f"{BASE_URL}/api/social/athletes")
        assert response.status_code == 200
    
    def test_tournaments_endpoint(self, api_client):
        """Tournaments endpoint should still work"""
        response = api_client.get(f"{BASE_URL}/api/tournaments")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 4
    
    def test_leaderboard_endpoint(self, api_client):
        """Leaderboard endpoint should still work"""
        response = api_client.get(f"{BASE_URL}/api/leaderboard")
        assert response.status_code == 200
    
    def test_education_courses_endpoint(self, api_client):
        """Education courses should still return courses"""
        response = api_client.get(f"{BASE_URL}/api/education/courses")
        assert response.status_code == 200
        data = response.json()
        assert len(data) >= 5
    
    def test_health_endpoint(self, api_client):
        """Health endpoint should return healthy"""
        response = api_client.get(f"{BASE_URL}/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
