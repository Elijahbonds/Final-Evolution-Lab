"""
Final Evolution Lab - Comprehensive Backend API Tests
Tests all 22 features: Game Modes, Creator Cards, Coach Hub, AI Coach, Education, 
Brain Brawl, Leaderboard, Pixel Streaming, Profile, Auth, Workouts
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


# ===================== HEALTH & ROOT =====================
class TestHealthEndpoints:
    """Basic health and root endpoint tests"""
    
    def test_root_endpoint(self, api_client):
        """Test API root returns version info"""
        response = api_client.get(f"{BASE_URL}/api/")
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "Final Evolution Lab" in data["message"]
        print(f"Root endpoint OK: {data}")
    
    def test_health_endpoint(self, api_client):
        """Test health check returns healthy status"""
        response = api_client.get(f"{BASE_URL}/api/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        print(f"Health endpoint OK: {data}")


# ===================== AUTH PROTECTION =====================
class TestAuthProtection:
    """Test that protected endpoints return 401 without token"""
    
    def test_auth_me_requires_token(self, api_client):
        """Test /auth/me returns 401 without token"""
        # Remove auth header if present
        headers = {"Content-Type": "application/json"}
        response = requests.get(f"{BASE_URL}/api/auth/me", headers=headers)
        assert response.status_code == 401
        print("Auth protection working: /auth/me returns 401")
    
    def test_profile_requires_token(self, api_client):
        """Test /profile requires authentication"""
        headers = {"Content-Type": "application/json"}
        response = requests.put(f"{BASE_URL}/api/profile", headers=headers, json={"bio": "test"})
        assert response.status_code == 401
        print("Auth protection working: /profile returns 401")
    
    def test_prq_metrics_requires_token(self, api_client):
        """Test /prq/metrics requires authentication"""
        headers = {"Content-Type": "application/json"}
        response = requests.get(f"{BASE_URL}/api/prq/metrics", headers=headers)
        assert response.status_code == 401
        print("Auth protection working: /prq/metrics returns 401")


# ===================== GAME MODES (17 modes) =====================
class TestGameModes:
    """Test all 17 game modes API"""
    
    def test_get_all_game_modes(self, api_client):
        """Test /games/modes returns all 17 playable modes"""
        response = api_client.get(f"{BASE_URL}/api/games/modes")
        assert response.status_code == 200
        modes = response.json()
        assert isinstance(modes, list)
        assert len(modes) == 20, f"Expected 20 game modes, got {len(modes)}"
        
        # Verify all modes have required fields
        for mode in modes:
            assert "id" in mode
            assert "name" in mode
            assert "display_name" in mode
            assert "category" in mode
            assert "playable" in mode
            assert "game_type" in mode
        
        # Count playable modes
        playable = [m for m in modes if m["playable"]]
        print(f"Game modes: {len(modes)} total, {len(playable)} playable")
    
    def test_get_single_game_mode(self, api_client):
        """Test getting a specific game mode by ID"""
        response = api_client.get(f"{BASE_URL}/api/games/modes/basketball_h2h")
        assert response.status_code == 200
        mode = response.json()
        assert mode["id"] == "basketball_h2h"
        assert mode["name"] == "Street 1v1"
        assert mode["playable"] == True
        print(f"Single game mode OK: {mode['display_name']}")
    
    def test_game_mode_not_found(self, api_client):
        """Test 404 for non-existent game mode"""
        response = api_client.get(f"{BASE_URL}/api/games/modes/invalid_mode")
        assert response.status_code == 404
        print("Game mode 404 handling OK")


# ===================== CREATOR CARDS =====================
class TestCreatorCards:
    """Test creator cards API - 3 featured cards"""
    
    def test_get_all_cards(self, api_client):
        """Test /cards returns 3 creator cards"""
        response = api_client.get(f"{BASE_URL}/api/cards")
        assert response.status_code == 200
        cards = response.json()
        assert isinstance(cards, list)
        assert len(cards) == 3, f"Expected 3 creator cards, got {len(cards)}"
        
        # Verify card structure
        for card in cards:
            assert "id" in card
            assert "name" in card
            assert "title" in card
            assert "sport" in card
            assert "signature_moves" in card
            assert "challenges" in card
            assert "price" in card
        
        # Verify specific creators
        names = [c["name"] for c in cards]
        assert "Elijah Bonds" in names
        assert "Amir Smith" in names
        assert "Eric Nash" in names
        print(f"Creator cards OK: {names}")
    
    def test_get_single_card(self, api_client):
        """Test getting a specific card by ID"""
        response = api_client.get(f"{BASE_URL}/api/cards/card_elijah")
        assert response.status_code == 200
        card = response.json()
        assert card["name"] == "Elijah Bonds"
        assert card["sport"] == "basketball"
        assert len(card["signature_moves"]) > 0
        print(f"Single card OK: {card['name']} - {card['title']}")


# ===================== COACH HUB =====================
class TestCoachHub:
    """Test coach availability and sessions"""
    
    def test_get_available_coaches(self, api_client):
        """Test /coach/available returns 4 coaches with rates"""
        response = api_client.get(f"{BASE_URL}/api/coach/available")
        assert response.status_code == 200
        coaches = response.json()
        assert isinstance(coaches, list)
        assert len(coaches) == 4, f"Expected 4 coaches, got {len(coaches)}"
        
        # Verify coach structure
        for coach in coaches:
            assert "name" in coach
            assert "rate" in coach
            assert isinstance(coach["rate"], (int, float))
        
        print(f"Available coaches: {[c['name'] for c in coaches]}")


# ===================== EDUCATION =====================
class TestEducation:
    """Test education courses API - 5 courses"""
    
    def test_get_all_courses(self, api_client):
        """Test /education/courses returns 5 courses"""
        response = api_client.get(f"{BASE_URL}/api/education/courses")
        assert response.status_code == 200
        courses = response.json()
        assert isinstance(courses, list)
        assert len(courses) == 5, f"Expected 5 courses, got {len(courses)}"
        
        # Verify course structure
        for course in courses:
            assert "id" in course
            assert "title" in course
            assert "category" in course
            assert "modules" in course
            assert "instructor" in course
        
        print(f"Education courses: {[c['title'] for c in courses]}")
    
    def test_filter_courses_by_category(self, api_client):
        """Test filtering courses by category"""
        response = api_client.get(f"{BASE_URL}/api/education/courses?category=brain_brawl")
        assert response.status_code == 200
        courses = response.json()
        assert len(courses) == 2  # Brain Brawl Fundamentals + Advanced Tactics
        for course in courses:
            assert course["category"] == "brain_brawl"
        print(f"Filtered courses OK: {len(courses)} brain_brawl courses")


# ===================== BRAIN BRAWL =====================
class TestBrainBrawl:
    """Test Brain Brawl questions API"""
    
    def test_get_questions(self, api_client):
        """Test /brain-brawl/questions returns questions"""
        response = api_client.get(f"{BASE_URL}/api/brain-brawl/questions")
        assert response.status_code == 200
        questions = response.json()
        assert isinstance(questions, list)
        assert len(questions) > 0
        
        # Verify question structure
        for q in questions:
            assert "id" in q
            assert "question" in q
            assert "options" in q
            assert "correct" not in q
            assert len(q["options"]) == 4
        
        print(f"Brain Brawl questions: {len(questions)} returned")
    
    def test_get_questions_by_category(self, api_client):
        """Test filtering questions by category"""
        response = api_client.get(f"{BASE_URL}/api/brain-brawl/questions?category=kinesiology&count=5")
        assert response.status_code == 200
        questions = response.json()
        assert len(questions) <= 5
        for q in questions:
            assert q["category"] == "kinesiology"
        print(f"Filtered questions OK: {len(questions)} kinesiology questions")


# ===================== LEADERBOARD =====================
class TestLeaderboard:
    """Test leaderboard API"""
    
    def test_get_leaderboard(self, api_client):
        """Test /leaderboard returns ranked athletes"""
        response = api_client.get(f"{BASE_URL}/api/leaderboard")
        assert response.status_code == 200
        leaders = response.json()
        assert isinstance(leaders, list)
        assert len(leaders) > 0
        
        # Verify leaderboard structure
        for leader in leaders:
            assert "rank" in leader
            assert "name" in leader
            assert "prq_score" in leader
            assert "level" in leader
        
        # Verify ranking order
        for i, leader in enumerate(leaders):
            assert leader["rank"] == i + 1
        
        print(f"Leaderboard: {len(leaders)} athletes, top: {leaders[0]['name']} ({leaders[0]['prq_score']})")


# ===================== PIXEL STREAMING =====================
class TestPixelStreaming:
    """Test Pixel Streaming status endpoint"""
    
    def test_streaming_status(self, api_client):
        """Test /streaming/status returns connection info"""
        response = api_client.get(f"{BASE_URL}/api/streaming/status")
        assert response.status_code == 200
        status = response.json()
        assert "available" in status
        assert "message" in status
        assert "supported_modes" in status
        assert isinstance(status["supported_modes"], list)
        print(f"Streaming status: available={status['available']}, modes={status['supported_modes']}")


# ===================== AUTHENTICATED ENDPOINTS =====================
class TestAuthenticatedEndpoints:
    """Test endpoints that require authentication"""
    
    def test_auth_me(self, auth_client):
        """Test /auth/me returns user data"""
        response = auth_client.get(f"{BASE_URL}/api/auth/me")
        assert response.status_code == 200
        user = response.json()
        assert "user_id" in user
        assert "email" in user
        assert "name" in user
        assert "prq_score" in user
        print(f"Auth me OK: {user['name']} (Level {user.get('level', 1)})")
    
    def test_prq_metrics(self, auth_client):
        """Test /prq/metrics returns PRQ data"""
        response = auth_client.get(f"{BASE_URL}/api/prq/metrics")
        assert response.status_code == 200
        prq = response.json()
        assert "overall_score" in prq
        assert "strength" in prq
        assert "speed" in prq
        assert "endurance" in prq
        print(f"PRQ metrics OK: overall={prq['overall_score']}")
    
    def test_profile_progress(self, auth_client):
        """Test /profile/progress returns progress stats"""
        response = auth_client.get(f"{BASE_URL}/api/profile/progress")
        assert response.status_code == 200
        progress = response.json()
        assert "total_workouts" in progress
        assert "total_games" in progress
        assert "level" in progress
        assert "xp" in progress
        print(f"Profile progress OK: workouts={progress['total_workouts']}, xp={progress['xp']}")
    
    def test_stats_overview(self, auth_client):
        """Test /stats/overview returns stats"""
        response = auth_client.get(f"{BASE_URL}/api/stats/overview")
        assert response.status_code == 200
        stats = response.json()
        assert "total_workouts" in stats
        assert "prq_score" in stats
        print(f"Stats overview OK: {stats}")


# ===================== AI ENDPOINTS =====================
class TestAIEndpoints:
    """Test AI Coach and Chat endpoints"""
    
    def test_ai_chat_endpoint(self, auth_client):
        """Test /ai/chat endpoint works"""
        response = auth_client.post(f"{BASE_URL}/api/ai/chat", json={
            "message": "Hello, what can you help me with?",
            "model": "gpt-5.2"
        })
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "model" in data
        assert "conversation_id" in data
        print(f"AI Chat OK: model={data['model']}, response_length={len(data['response'])}")
    
    def test_ai_coach_endpoint(self, auth_client):
        """Test /ai/coach endpoint works"""
        response = auth_client.post(f"{BASE_URL}/api/ai/coach", json={
            "type": "workout",
            "context": "I need a quick warm-up routine"
        })
        assert response.status_code == 200
        data = response.json()
        assert "response" in data
        assert "type" in data
        print(f"AI Coach OK: type={data['type']}, response_length={len(data['response'])}")


# ===================== PROFILE UPDATE =====================
class TestProfileUpdate:
    """Test profile update functionality"""
    
    def test_update_profile(self, auth_client):
        """Test PUT /profile updates user data"""
        response = auth_client.put(f"{BASE_URL}/api/profile", json={
            "bio": "Test athlete bio",
            "sport": "karate"
        })
        assert response.status_code == 200
        updated = response.json()
        assert updated.get("bio") == "Test athlete bio"
        assert updated.get("sport") == "karate"
        print(f"Profile update OK: bio={updated.get('bio')}, sport={updated.get('sport')}")


# ===================== WORKOUTS =====================
class TestWorkouts:
    """Test workout endpoints"""
    
    def test_recommended_workouts(self, auth_client):
        """Test /workouts/recommended returns workout plans"""
        response = auth_client.get(f"{BASE_URL}/api/workouts/recommended")
        assert response.status_code == 200
        workouts = response.json()
        assert isinstance(workouts, list)
        assert len(workouts) >= 4
        
        for workout in workouts:
            assert "id" in workout
            assert "name" in workout
            assert "exercises" in workout
            assert len(workout["exercises"]) > 0
        
        print(f"Recommended workouts: {[w['name'] for w in workouts]}")
    
    def test_log_workout(self, auth_client):
        """Test POST /workouts/log creates workout log"""
        response = auth_client.post(f"{BASE_URL}/api/workouts/log", json={
            "workout_id": "rec_1",
            "workout_name": "Power Development",
            "duration_minutes": 30,
            "calories_burned": 250,
            "exercises_completed": ["Box Jumps", "Medicine Ball Slams"]
        })
        assert response.status_code == 200
        log = response.json()
        assert "id" in log
        assert log["workout_name"] == "Power Development"
        print(f"Workout log OK: {log['workout_name']}, duration={log['duration_minutes']}min")


# ===================== GAME SESSION =====================
class TestGameSession:
    """Test game session creation"""
    
    def test_create_game_session(self, auth_client):
        """Test POST /games/session creates game session"""
        response = auth_client.post(f"{BASE_URL}/api/games/session", json={
            "mode_id": "basketball_h2h",
            "score": 500,
            "duration_seconds": 30,
            "completed": True,
            "stats": {"hits": 20, "misses": 5}
        })
        assert response.status_code == 200
        data = response.json()
        assert "session" in data
        assert "xp_earned" in data
        assert data["session"]["score"] == 500
        print(f"Game session OK: score={data['session']['score']}, xp_earned={data['xp_earned']}")


# ===================== BRAIN BRAWL SUBMIT =====================
class TestBrainBrawlSubmit:
    """Test Brain Brawl submission"""
    
    def test_submit_brain_brawl(self, auth_client):
        """Test modern Brain Brawl session workflow: start then submit"""
        # 1. Start a quiz session
        start_resp = auth_client.post(f"{BASE_URL}/api/brain-brawl/session/start", json={
            "category": "sports_iq",
            "count": 5
        })
        assert start_resp.status_code == 200
        start_data = start_resp.json()
        assert "session_id" in start_data
        assert "questions" in start_data
        
        session_id = start_data["session_id"]
        questions = start_data["questions"]
        assert len(questions) == 5
        
        # 2. Submit answers (dummy array of 0s)
        submit_resp = auth_client.post(f"{BASE_URL}/api/brain-brawl/session/submit", json={
            "session_id": session_id,
            "answers": [0] * len(questions)
        })
        assert submit_resp.status_code == 200
        submit_data = submit_resp.json()
        assert "session_id" in submit_data
        assert "questions_total" in submit_data
        assert "questions_correct" in submit_data
        assert "xp_earned" in submit_data
        print(f"Modern Brain Brawl session OK: correct={submit_data['questions_correct']}, xp={submit_data['xp_earned']}")


# ===================== TRIVIA ARENA =====================
class TestTriviaArena:
    """Test Trivia Arena endpoint and question banks"""
    
    def test_get_trivia_questions_all(self, api_client):
        """Test getting all trivia questions returns default of 5"""
        response = api_client.get(f"{BASE_URL}/api/trivia/questions")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 5
        for q in data:
            assert "question" in q
            assert "options" in q
            assert "category" in q
            assert "correct" in q
            
    def test_get_trivia_questions_by_category(self, api_client):
        """Test getting trivia questions filtered by category"""
        response = api_client.get(f"{BASE_URL}/api/trivia/questions?category=science&count=3")
        assert response.status_code == 200
        data = response.json()
        assert len(data) == 3
        for q in data:
            assert q["category"] == "science"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
