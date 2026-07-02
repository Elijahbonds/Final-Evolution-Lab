# Auth Testing Playbook — Final Evolution Lab

## Step 1: Create Test User & Session
```bash
mongosh --eval "
use('test_database');
var userId = 'test-user-' + Date.now();
var sessionToken = 'test_session_' + Date.now();
db.users.insertOne({
  user_id: userId, email: 'test.user.' + Date.now() + '@example.com',
  name: 'Test User', picture: 'https://via.placeholder.com/150',
  created_at: new Date().toISOString(), role: 'athlete', sport: 'basketball',
  prq_score: 75.0, level: 1, xp: 0, streak_days: 0, total_workouts: 0,
  coins: 100, followers: [], following: [], avatar_config: null
});
db.user_sessions.insertOne({
  user_id: userId, session_token: sessionToken,
  expires_at: new Date(Date.now() + 7*24*60*60*1000).toISOString(),
  created_at: new Date().toISOString()
});
print('Session token: ' + sessionToken);
print('User ID: ' + userId);
"
```

## Step 2: Test Backend API (Bearer fallback works on mobile WebViews)
```bash
curl -X GET "$API_URL/api/auth/me" -b "session_token=$TOKEN"
curl -X GET "$API_URL/api/auth/me" -H "Authorization: Bearer $TOKEN"
```

## Critical CORS rules
- `allow_origins=["*"]` + `allow_credentials=True` is a CORS spec violation. Browsers DROP cookies. Use explicit origins or `allow_origin_regex`.
- Production allowlist: `https://finalevolutiongroup.com`, `https://www.finalevolutiongroup.com`
- Preview pattern: `https://*.preview.finalevolutiongroup.com`

## Cookie Attribute Rules (iOS Safari + In-App WebViews)
- `httponly=True` `secure=True` `samesite="none"` `path="/"` `max_age=7*86400`
- The cookie MUST be set on a returned `JSONResponse`, not on a parameter `Response`.
- ALSO return `session_token` in response body. Frontend stores in localStorage and adds `Authorization: Bearer <token>` on every axios request — bulletproof fallback.

## Failure / Loop Indicators
- ❌ Google sign-in → bounces back to `/login` after `/dashboard` loads → cookie dropped. Check CORS.
- ❌ `POST /api/auth/session` 200 then `GET /api/auth/me` 401 → same root cause.
