# Auth Testing Playbook for Final Evolution Lab

## Test Identity Tracking
After setting up Google Auth, save relevant test identities to `/app/memory/test_credentials.md`:
- Allowed Google test accounts (email)
- Linked app users
- RBAC roles/permissions mapped to each test account

## Step 1: Create Test User & Session
```bash
mongosh --eval "
use('test_database');
var userId = 'test-user-' + Date.now();
var sessionToken = 'test_session_' + Date.now();
db.users.insertOne({
  user_id: userId,
  email: 'test.user.' + Date.now() + '@example.com',
  name: 'Test User',
  picture: 'https://via.placeholder.com/150',
  created_at: new Date(),
  role: 'athlete',
  prq_score: 75.0,
  level: 1,
  xp: 0
});
db.user_sessions.insertOne({
  user_id: userId,
  session_token: sessionToken,
  expires_at: new Date(Date.now() + 7*24*60*60*1000),
  created_at: new Date()
});
db.prq_metrics.insertOne({
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
});
print('Session token: ' + sessionToken);
print('User ID: ' + userId);
"
```

## Step 2: Test Backend API
```bash
# Get backend URL from .env
API_URL=$(grep REACT_APP_BACKEND_URL /app/frontend/.env | cut -d '=' -f2)

# Test auth endpoint
curl -X GET "$API_URL/api/auth/me" \
  -H "Authorization: Bearer YOUR_SESSION_TOKEN"

# Test PRQ metrics
curl -X GET "$API_URL/api/prq/metrics" \
  -H "Authorization: Bearer YOUR_SESSION_TOKEN"

# Test game modes
curl -X GET "$API_URL/api/games/modes"

# Test creator cards
curl -X GET "$API_URL/api/cards"

# Test courses
curl -X GET "$API_URL/api/education/courses"
```

## Step 3: Browser Testing
```python
# Set cookie and navigate
await page.context.add_cookies([{
    "name": "session_token",
    "value": "YOUR_SESSION_TOKEN",
    "domain": "readiness-stack.preview.emergentagent.com",
    "path": "/",
    "httpOnly": True,
    "secure": True,
    "sameSite": "None"
}])
await page.goto("https://readiness-stack.preview.emergentagent.com/dashboard")
```

## Quick Debug
```bash
# Check data format
mongosh --eval "
use('test_database');
db.users.find().limit(2).pretty();
db.user_sessions.find().limit(2).pretty();
"

# Clean test data
mongosh --eval "
use('test_database');
db.users.deleteMany({email: /test\.user\./});
db.user_sessions.deleteMany({session_token: /test_session/});
"
```

## Checklist
- [ ] User document has user_id field
- [ ] Session user_id matches user's user_id exactly
- [ ] All queries use `{"_id": 0}` projection
- [ ] Backend queries use user_id (not _id or id)
- [ ] API returns user data with user_id field
- [ ] Browser loads dashboard (not login page)

## Success Indicators
✅ /api/auth/me returns user data
✅ Dashboard loads without redirect
✅ CRUD operations work

## Failure Indicators
❌ "User not found" errors
❌ 401 Unauthorized responses
❌ Redirect to login page
