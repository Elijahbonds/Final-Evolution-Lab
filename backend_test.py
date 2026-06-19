#!/usr/bin/env python3

import requests
import sys
import json
from datetime import datetime
import time

class FinalEvolutionLabTester:
    def __init__(self):
        # Use the public endpoint from frontend .env
        self.base_url = "https://readiness-stack.preview.emergentagent.com/api"
        self.session_token = None
        self.user_id = None
        self.tests_run = 0
        self.tests_passed = 0
        self.test_results = []

    def log_test(self, name, success, details=""):
        """Log test result"""
        self.tests_run += 1
        if success:
            self.tests_passed += 1
            print(f"✅ {name}")
        else:
            print(f"❌ {name} - {details}")
        
        self.test_results.append({
            "test": name,
            "success": success,
            "details": details,
            "timestamp": datetime.now().isoformat()
        })

    def test_api_root(self):
        """Test API root endpoint"""
        try:
            response = requests.get(f"{self.base_url}/")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                details += f", Message: {data.get('message', 'N/A')}"
            self.log_test("API Root Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("API Root Endpoint", False, str(e))
            return False

    def test_health_endpoint(self):
        """Test health endpoint"""
        try:
            response = requests.get(f"{self.base_url}/health")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                details += f", Status: {data.get('status', 'N/A')}"
            self.log_test("Health Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Health Endpoint", False, str(e))
            return False

    def test_game_modes(self):
        """Test game modes endpoint"""
        try:
            response = requests.get(f"{self.base_url}/games/modes")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                mode_count = len(data)
                details += f", Modes: {mode_count}"
                # Check if we have the current 19 game modes as expected
                if mode_count == 19:
                    details += " (Expected 19 ✓)"
                else:
                    details += f" (Expected 19, got {mode_count})"
            self.log_test("Game Modes Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Game Modes Endpoint", False, str(e))
            return False

    def test_creator_cards(self):
        """Test creator cards endpoint"""
        try:
            response = requests.get(f"{self.base_url}/cards")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                card_count = len(data)
                details += f", Cards: {card_count}"
            self.log_test("Creator Cards Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Creator Cards Endpoint", False, str(e))
            return False

    def test_education_courses(self):
        """Test education courses endpoint"""
        try:
            response = requests.get(f"{self.base_url}/education/courses")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                course_count = len(data)
                details += f", Courses: {course_count}"
            self.log_test("Education Courses Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Education Courses Endpoint", False, str(e))
            return False

    def test_brain_brawl_questions(self):
        """Test brain brawl questions endpoint"""
        try:
            response = requests.get(f"{self.base_url}/brain-brawl/questions")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                question_count = len(data)
                details += f", Questions: {question_count}"
            self.log_test("Brain Brawl Questions Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Brain Brawl Questions Endpoint", False, str(e))
            return False

    def test_available_coaches(self):
        """Test available coaches endpoint"""
        try:
            response = requests.get(f"{self.base_url}/coach/available")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                coach_count = len(data)
                details += f", Coaches: {coach_count}"
            self.log_test("Available Coaches Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Available Coaches Endpoint", False, str(e))
            return False

    def test_leaderboard(self):
        """Test leaderboard endpoint"""
        try:
            response = requests.get(f"{self.base_url}/leaderboard")
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                leader_count = len(data)
                details += f", Leaders: {leader_count}"
            self.log_test("Leaderboard Endpoint", success, details)
            return success
        except Exception as e:
            self.log_test("Leaderboard Endpoint", False, str(e))
            return False

    def test_auth_protected_endpoints(self):
        """Test that protected endpoints return 401 without auth"""
        protected_endpoints = [
            "/auth/me",
            "/prq/metrics", 
            "/health/metrics",
            "/workouts",
            "/coach/sessions",
            "/stats/overview"
        ]
        
        all_protected = True
        for endpoint in protected_endpoints:
            try:
                response = requests.get(f"{self.base_url}{endpoint}")
                success = response.status_code == 401
                details = f"Status: {response.status_code}"
                if not success:
                    all_protected = False
                    details += " (Should be 401 without auth)"
                self.log_test(f"Protected Endpoint {endpoint}", success, details)
            except Exception as e:
                self.log_test(f"Protected Endpoint {endpoint}", False, str(e))
                all_protected = False
        
        return all_protected

    def create_test_session(self):
        """Create test session using MongoDB as per auth testing guide"""
        try:
            import subprocess
            import uuid
            
            # Generate unique identifiers
            timestamp = int(time.time() * 1000)
            user_id = f"test-user-{timestamp}"
            session_token = f"test_session_{timestamp}"
            email = f"test.user.{timestamp}@example.com"
            
            # MongoDB script to create test user and session
            mongo_script = f"""
use('test_database');
var userId = '{user_id}';
var sessionToken = '{session_token}';
var email = '{email}';

db.users.insertOne({{
  user_id: userId,
  email: email,
  name: 'Test User',
  picture: 'https://via.placeholder.com/150',
  created_at: new Date(),
  role: 'athlete',
  prq_score: 75.0,
  level: 1,
  xp: 0
}});

db.user_sessions.insertOne({{
  user_id: userId,
  session_token: sessionToken,
  expires_at: new Date(Date.now() + 7*24*60*60*1000),
  created_at: new Date()
}});

db.prq_metrics.insertOne({{
  id: 'prq_' + Date.now(),
  user_id: userId,
  overall_score: 75.0,
  strength: 70.0,
  speed: 75.0,
  endurance: 80.0,
  agility: 72.0,
  power: 68.0,
  flexibility: 78.0,
  recovery: 82.0,
  mental: 76.0,
  recorded_at: new Date()
}});

print('SUCCESS: Session created');
print('Session token: ' + sessionToken);
print('User ID: ' + userId);
"""
            
            # Execute MongoDB script
            result = subprocess.run(
                ["mongosh", "--eval", mongo_script],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0 and "SUCCESS: Session created" in result.stdout:
                self.session_token = session_token
                self.user_id = user_id
                self.log_test("Create Test Session", True, f"User: {user_id}")
                return True
            else:
                self.log_test("Create Test Session", False, f"MongoDB error: {result.stderr}")
                return False
                
        except Exception as e:
            self.log_test("Create Test Session", False, str(e))
            return False

    def test_authenticated_endpoints(self):
        """Test authenticated endpoints with session token"""
        if not self.session_token:
            self.log_test("Authenticated Endpoints", False, "No session token available")
            return False
        
        headers = {"Authorization": f"Bearer {self.session_token}"}
        
        # Test /auth/me
        try:
            response = requests.get(f"{self.base_url}/auth/me", headers=headers)
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                details += f", User: {data.get('name', 'N/A')}"
            self.log_test("Auth Me Endpoint", success, details)
        except Exception as e:
            self.log_test("Auth Me Endpoint", False, str(e))
        
        # Test PRQ metrics
        try:
            response = requests.get(f"{self.base_url}/prq/metrics", headers=headers)
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                details += f", PRQ Score: {data.get('overall_score', 'N/A')}"
            self.log_test("PRQ Metrics Endpoint", success, details)
        except Exception as e:
            self.log_test("PRQ Metrics Endpoint", False, str(e))
        
        # Test stats overview
        try:
            response = requests.get(f"{self.base_url}/stats/overview", headers=headers)
            success = response.status_code == 200
            details = f"Status: {response.status_code}"
            if success:
                data = response.json()
                details += f", Level: {data.get('level', 'N/A')}"
            self.log_test("Stats Overview Endpoint", success, details)
        except Exception as e:
            self.log_test("Stats Overview Endpoint", False, str(e))

    def cleanup_test_data(self):
        """Clean up test data from MongoDB"""
        try:
            import subprocess
            
            mongo_script = """
use('test_database');
db.users.deleteMany({email: /test\.user\./});
db.user_sessions.deleteMany({session_token: /test_session/});
db.prq_metrics.deleteMany({user_id: /test-user-/});
print('Test data cleaned up');
"""
            
            result = subprocess.run(
                ["mongosh", "--eval", mongo_script],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            success = result.returncode == 0
            self.log_test("Cleanup Test Data", success, "Removed test users and sessions")
            
        except Exception as e:
            self.log_test("Cleanup Test Data", False, str(e))

    def run_all_tests(self):
        """Run all backend tests"""
        print("🚀 Starting Final Evolution Lab Backend Tests")
        print(f"📍 Testing API: {self.base_url}")
        print("=" * 60)
        
        # Basic API tests (no auth required)
        print("\n📋 Testing Public Endpoints...")
        self.test_api_root()
        self.test_health_endpoint()
        self.test_game_modes()
        self.test_creator_cards()
        self.test_education_courses()
        self.test_brain_brawl_questions()
        self.test_available_coaches()
        self.test_leaderboard()
        
        # Test auth protection
        print("\n🔒 Testing Auth Protection...")
        self.test_auth_protected_endpoints()
        
        # Test with authentication
        print("\n🔑 Testing Authenticated Endpoints...")
        if self.create_test_session():
            self.test_authenticated_endpoints()
            self.cleanup_test_data()
        
        # Print summary
        print("\n" + "=" * 60)
        print(f"📊 Test Summary: {self.tests_passed}/{self.tests_run} passed")
        success_rate = (self.tests_passed / self.tests_run * 100) if self.tests_run > 0 else 0
        print(f"📈 Success Rate: {success_rate:.1f}%")
        
        if self.tests_passed == self.tests_run:
            print("🎉 All tests passed!")
            return 0
        else:
            print("⚠️  Some tests failed")
            return 1

def main():
    tester = FinalEvolutionLabTester()
    return tester.run_all_tests()

if __name__ == "__main__":
    sys.exit(main())