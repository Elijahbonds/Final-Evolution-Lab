"""
Final Evolution Lab - Iteration 3 Feature Tests
Tests new features: Streaks, PayPal, Social, Tournaments, Avatar Builder, Video Critique
"""
import pytest
import requests
import os

BASE_URL = os.environ.get('REACT_APP_BACKEND_URL', '').rstrip('/')
SESSION_TOKEN = os.environ.get('TEST_SESSION_TOKEN', '')

@pytest.fixture(scope="module")
def api_client():
    """Shared requests session"""
    session = requests.Session()
    session.headers.update({"Content-Type": "application/json"})
    return session

@pytest.fixture(scope="module")
def auth_client(api_client):
    """Authenticated session with Bearer token"""
    api_client.headers.update({"Authorization": f"Bearer {SESSION_TOKEN}"})
    return api_client


# ===================== STREAKS API =====================
class TestStreaksAPI:
    """Test daily training streaks feature"""
    
    def test_get_streak_data(self, auth_client):
        """Test GET /streaks returns streak data"""
        response = auth_client.get(f"{BASE_URL}/api/streaks")
        assert response.status_code == 200
        data = response.json()
        assert "user_id" in data
        assert "current_streak" in data
        assert "longest_streak" in data
        assert "daily_log" in data
        print(f"Streaks GET OK: current={data['current_streak']}, longest={data['longest_streak']}")
    
    def test_streak_checkin(self, auth_client):
        """Test POST /streaks/checkin performs daily check-in"""
        response = auth_client.post(f"{BASE_URL}/api/streaks/checkin")
        assert response.status_code == 200
        data = response.json()
        assert "current_streak" in data
        assert "xp_earned" in data or "message" in data  # Either new checkin or already checked in
        print(f"Streaks checkin OK: {data}")
    
    def test_streak_rewards(self, auth_client):
        """Test GET /streaks/rewards returns milestones"""
        response = auth_client.get(f"{BASE_URL}/api/streaks/rewards")
        assert response.status_code == 200
        data = response.json()
        assert "current_streak" in data
        assert "milestones" in data
        assert isinstance(data["milestones"], list)
        assert len(data["milestones"]) >= 4  # 3, 7, 14, 30 day milestones
        for m in data["milestones"]:
            assert "days" in m
            assert "reward" in m
            assert "unlocked" in m
        print(f"Streaks rewards OK: {len(data['milestones'])} milestones")


# ===================== PAYPAL API =====================
class TestPayPalAPI:
    """Test PayPal payment integration"""
    
    def test_create_payment_order(self, auth_client):
        """Test POST /payments/create-order creates a payment order"""
        response = auth_client.post(f"{BASE_URL}/api/payments/create-order", json={
            "item_type": "card",
            "item_id": "card_elijah",
            "amount": 99.99,
            "return_url": "https://example.com/success",
            "cancel_url": "https://example.com/cancel"
        })
        assert response.status_code == 200
        data = response.json()
        assert "order_id" in data
        assert "approval_url" in data
        assert "status" in data
        assert data["status"] == "created"
        print(f"PayPal create-order OK: order_id={data['order_id']}, has_approval_url={bool(data['approval_url'])}")
    
    def test_create_payment_invalid_amount(self, auth_client):
        """Test payment creation fails with invalid amount"""
        response = auth_client.post(f"{BASE_URL}/api/payments/create-order", json={
            "item_type": "card",
            "item_id": "card_elijah",
            "amount": 0
        })
        assert response.status_code == 400
        print("PayPal invalid amount validation OK")
    
    def test_payment_history(self, auth_client):
        """Test GET /payments/history returns order history"""
        response = auth_client.get(f"{BASE_URL}/api/payments/history")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        print(f"PayPal history OK: {len(data)} orders")


# ===================== SOCIAL API =====================
class TestSocialAPI:
    """Test social features - follow, challenge, feed"""
    
    def test_get_athletes(self, api_client):
        """Test GET /social/athletes returns athlete list"""
        response = api_client.get(f"{BASE_URL}/api/social/athletes")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) >= 1  # At least one athlete (test user or seeded)
        for athlete in data:
            assert "user_id" in athlete
            assert "name" in athlete
            assert "sport" in athlete
        print(f"Social athletes OK: {len(data)} athletes, names={[a['name'] for a in data[:3]]}")
    
    def test_search_athletes(self, api_client):
        """Test athlete search with query"""
        response = api_client.get(f"{BASE_URL}/api/social/athletes?q=Elijah")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        print(f"Social search OK: {len(data)} results for 'Elijah'")
    
    def test_create_challenge(self, auth_client):
        """Test POST /social/challenge creates a challenge"""
        response = auth_client.post(f"{BASE_URL}/api/social/challenge", json={
            "target_id": "u1",
            "game_mode": "basketball_h2h"
        })
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert "challenger_id" in data
        assert "challenged_id" in data
        assert "game_mode" in data
        assert data["status"] == "pending"
        print(f"Social challenge OK: id={data['id']}, mode={data['game_mode']}")
    
    def test_get_challenges(self, auth_client):
        """Test GET /social/challenges returns challenges"""
        response = auth_client.get(f"{BASE_URL}/api/social/challenges")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        print(f"Social challenges OK: {len(data)} challenges")
    
    def test_get_activity_feed(self, auth_client):
        """Test GET /social/feed returns activity feed"""
        response = auth_client.get(f"{BASE_URL}/api/social/feed")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        print(f"Social feed OK: {len(data)} activities")


# ===================== TOURNAMENTS API =====================
class TestTournamentsAPI:
    """Test tournaments with brackets"""
    
    def test_get_tournaments(self, api_client):
        """Test GET /tournaments returns 4 tournaments with brackets"""
        response = api_client.get(f"{BASE_URL}/api/tournaments")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        assert len(data) == 4, f"Expected 4 tournaments, got {len(data)}"
        
        for t in data:
            assert "id" in t
            assert "name" in t
            assert "game_mode" in t
            assert "format" in t
            assert "max_players" in t
            assert "current_players" in t
            assert "prize" in t
            assert "status" in t
            assert "bracket" in t
        
        print(f"Tournaments OK: {[t['name'] for t in data]}")
    
    def test_get_single_tournament(self, api_client):
        """Test GET /tournaments/t1 returns single tournament detail"""
        response = api_client.get(f"{BASE_URL}/api/tournaments/t1")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == "t1"
        assert data["name"] == "Venice Beach Invitational"
        assert "bracket" in data
        assert isinstance(data["bracket"], list)
        print(f"Tournament detail OK: {data['name']}, bracket_matches={len(data['bracket'])}")
    
    def test_tournament_not_found(self, api_client):
        """Test 404 for non-existent tournament"""
        response = api_client.get(f"{BASE_URL}/api/tournaments/invalid_tournament")
        assert response.status_code == 404
        print("Tournament 404 handling OK")
    
    def test_join_tournament(self, auth_client):
        """Test POST /tournaments/{id}/join registers user"""
        response = auth_client.post(f"{BASE_URL}/api/tournaments/t1/join")
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert data["tournament_id"] == "t1"
        print(f"Tournament join OK: {data}")


# ===================== AVATAR API =====================
class TestAvatarAPI:
    """Test avatar builder customization"""
    
    def test_get_avatar_options(self, api_client):
        """Test GET /avatar/options returns customization options"""
        response = api_client.get(f"{BASE_URL}/api/avatar/options")
        assert response.status_code == 200
        data = response.json()
        
        # Verify all option categories exist
        assert "body_types" in data
        assert "skin_tones" in data
        assert "hair_styles" in data
        assert "hair_colors" in data
        assert "jersey_colors" in data
        assert "shorts_colors" in data
        assert "shoe_styles" in data
        assert "shoe_colors" in data
        assert "accessories" in data
        assert "expressions" in data
        
        # Verify options are lists with values
        assert len(data["body_types"]) >= 4
        assert len(data["skin_tones"]) >= 6
        assert len(data["hair_styles"]) >= 8
        assert len(data["jersey_colors"]) >= 7
        assert len(data["accessories"]) >= 6
        
        print(f"Avatar options OK: body_types={data['body_types']}, expressions={data['expressions']}")
    
    def test_get_avatar_config(self, auth_client):
        """Test GET /avatar/config returns user avatar config"""
        response = auth_client.get(f"{BASE_URL}/api/avatar/config")
        assert response.status_code == 200
        data = response.json()
        
        # Verify default config structure
        assert "body_type" in data
        assert "skin_tone" in data
        assert "jersey_color" in data
        assert "shoe_style" in data
        assert "expression" in data
        
        print(f"Avatar config OK: body={data['body_type']}, jersey={data['jersey_color']}")
    
    def test_update_avatar_config(self, auth_client):
        """Test PUT /avatar/config updates avatar"""
        new_config = {
            "body_type": "muscular",
            "skin_tone": "#8D5524",
            "hair_style": "braids",
            "jersey_color": "#FF3366",
            "shorts_color": "#000000",
            "shoe_style": "running",
            "shoe_color": "#FF0000",
            "accessories": ["headband", "wristband"],
            "expression": "aggressive"
        }
        response = auth_client.put(f"{BASE_URL}/api/avatar/config", json=new_config)
        assert response.status_code == 200
        data = response.json()
        assert data["body_type"] == "muscular"
        assert data["jersey_color"] == "#FF3366"
        print(f"Avatar update OK: {data}")


# ===================== VIDEO CRITIQUE API =====================
class TestVideoCritiqueAPI:
    """Test video upload and critique features"""
    
    def test_get_critiques(self, auth_client):
        """Test GET /coach/critiques returns critique list"""
        response = auth_client.get(f"{BASE_URL}/api/coach/critiques")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)
        print(f"Critiques OK: {len(data)} critiques")
    
    def test_submit_critique_request(self, auth_client):
        """Test POST /coach/critique submits critique request"""
        response = auth_client.post(f"{BASE_URL}/api/coach/critique", json={
            "coach_id": "coach_1",
            "video_id": "test_video_123",
            "sport": "basketball",
            "notes": "Please review my shooting form"
        })
        assert response.status_code == 200
        data = response.json()
        assert "id" in data
        assert "athlete_id" in data
        assert "coach_id" in data
        assert data["status"] == "pending"
        print(f"Critique submit OK: id={data['id']}, status={data['status']}")


# ===================== EXISTING FEATURES REGRESSION =====================
class TestExistingFeaturesRegression:
    """Verify all 19 game modes and other existing features still work"""
    
    def test_all_19_game_modes(self, api_client):
        """Test /games/modes still returns all 19 modes"""
        response = api_client.get(f"{BASE_URL}/api/games/modes")
        assert response.status_code == 200
        modes = response.json()
        assert len(modes) == 19, f"Expected 19 game modes, got {len(modes)}"
        
        # Verify expected modes exist
        mode_ids = [m["id"] for m in modes]
        expected_modes = [
            "basketball_h2h", "basketball_dunk", "basketball_3v3",
            "karate_h2h", "karate_endless", "baseball", "football",
            "soccer", "golf", "tennis", "volleyball", "gymnastics",
            "brain_brawl", "surfing", "skateboarding", "snowboarding",
            "market_browse", "who_scene_it", "court_carnival"
        ]
        for expected in expected_modes:
            assert expected in mode_ids, f"Missing game mode: {expected}"
        
        print(f"All 19 game modes verified: {mode_ids}")
    
    def test_auth_protection_still_works(self, api_client):
        """Test auth protection returns 401 without token"""
        headers = {"Content-Type": "application/json"}
        response = requests.get(f"{BASE_URL}/api/auth/me", headers=headers)
        assert response.status_code == 401
        print("Auth protection still working")
    
    def test_creator_cards_still_work(self, api_client):
        """Test creator cards still return 3 cards"""
        response = api_client.get(f"{BASE_URL}/api/cards")
        assert response.status_code == 200
        cards = response.json()
        assert len(cards) == 3
        print(f"Creator cards OK: {[c['name'] for c in cards]}")
    
    def test_education_courses_still_work(self, api_client):
        """Test education courses still return 5 courses"""
        response = api_client.get(f"{BASE_URL}/api/education/courses")
        assert response.status_code == 200
        courses = response.json()
        assert len(courses) == 5
        print(f"Education courses OK: {len(courses)} courses")
    
    def test_leaderboard_still_works(self, api_client):
        """Test leaderboard still returns ranked athletes"""
        response = api_client.get(f"{BASE_URL}/api/leaderboard")
        assert response.status_code == 200
        leaders = response.json()
        assert len(leaders) > 0
        print(f"Leaderboard OK: {len(leaders)} athletes")


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
