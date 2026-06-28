# NEXUS_TEAM — Code Standards
**Final Evolution Lab (FEL)**  
Branch: `claude/nexus-engine-setup-2qgkik`  
Last Updated: 2026-06-28  
Authority: Nexus Project Manager

These standards apply to ALL agents working on the FEL codebase. Violations block merges.

---

## Swift Standards

### Concurrency & State Management
```swift
// REQUIRED: @Observable for all model types
@Observable
final class AvatarStateMachine {
    var currentState: AvatarState = .idle
    var prqScore: Double = 0.0
}

// REQUIRED: @MainActor for ViewModels and UI-bound classes
@MainActor
final class TrainingViewModel: ObservableObject {
    var programs: [TrainingProgram] = []
}

// REQUIRED: async/await for all async operations (no callbacks)
func fetchLeaderboard(scope: LeaderboardScope) async throws -> [LeaderboardEntry] {
    let snapshot = try await firestoreCollection.getDocuments()
    return snapshot.documents.compactMap { LeaderboardEntry(from: $0) }
}

// FORBIDDEN: completion handlers
// func fetchData(completion: @escaping (Result<Data, Error>) -> Void) { ... }  // NO
```

### Logging
```swift
// REQUIRED: OSLog for all logging
import OSLog
private let logger = Logger(subsystem: "com.antigravity.finalevolutionlab", category: "Physics")
logger.info("Physics tick: \(deltaTime, format: .fixed(precision: 4))s")

// FORBIDDEN: print statements
// print("Physics tick: \(deltaTime)")  // NO — removed by compiler in release but wrong pattern
```

### Safety
```swift
// REQUIRED: Safe unwrapping only
guard let userProfile = currentUser?.profile else {
    logger.warning("No user profile available")
    return
}

// FORBIDDEN: Force unwraps
// let profile = currentUser!.profile  // NO — crashes in production
// let value = dictionary["key"]!      // NO
// let typed = object as! TargetType   // NO — use as? with guard
```

### Naming Conventions
```swift
// Types: UpperCamelCase
struct MovementEfficiencyScore { ... }
enum PRQTier { case elite, primed, ready, recovering, depleted }

// Properties/methods: lowerCamelCase
var speedMultiplier: Double
func calculateComboBonus(chain: ComboChain) -> Double

// Constants: lowerCamelCase static lets in caseless enums
enum PhysicsConstants {
    static let gravity: Double = 9.81
    static let maxVelocity: Double = 50.0
    static let bounceCoefficient: Double = 0.65
}
```

### File Structure
```swift
// Each file: one primary type (struct/class/enum) + its extensions
// Import only what you need (no wildcard imports)
import Foundation          // for Date, UUID, etc.
import OSLog               // for Logger
// import UIKit            // only when UIImage/UIViewController actually used
// import SwiftUI          // only for @Observable, View conformance

// Mark sections clearly
// MARK: - Properties
// MARK: - Computed Properties
// MARK: - Methods
// MARK: - Private Helpers
```

### Test Standards (Swift Testing Framework)
```swift
import Testing

@Suite("ShardEconomy Tests")
struct ShardEconomyTests {
    @Test("matchWin earns 50 shards")
    func matchWinReward() {
        let rule = ShardEarningRule.matchWin
        #expect(rule.shardReward == 50)  // NOT XCTAssertEqual
    }

    @Test("ComboChain caps at 5x multiplier")
    func comboChainMaxMultiplier() {
        var chain = ComboChain()
        for _ in 0..<10 { chain.recordTrick(score: 100) }
        #expect(chain.multiplier <= 5.0)
    }
}
```

---

## Python (Backend) Standards

### FastAPI Patterns
```python
# REQUIRED: Follow core.py patterns
from core import get_current_user, db
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from motor.motor_asyncio import AsyncIOMotorClient  # async Motor only

router = APIRouter(prefix="/api/education", tags=["education"])

# REQUIRED: Pydantic models for all request/response bodies
class LessonSubmitRequest(BaseModel):
    lesson_id: str
    answers: list[int]
    time_spent_seconds: int

class LessonSubmitResponse(BaseModel):
    score: float
    passed: bool
    xp_earned: int
    correct_answers: list[int]

# REQUIRED: async/await on all endpoints and DB calls
@router.post("/tracks/{track_id}/lesson/{lesson_id}/submit")
async def submit_lesson(
    track_id: str,
    lesson_id: str,
    body: LessonSubmitRequest,
    user: dict = Depends(get_current_user)
) -> LessonSubmitResponse:
    # REQUIRED: async Motor for all DB operations
    result = await db.education_progress.find_one({"user_id": user["_id"]})
    ...
```

### Error Handling
```python
# REQUIRED: HTTPException for all error responses
from fastapi import HTTPException, status

if not track:
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Track '{track_id}' not found"
    )

# REQUIRED: 4xx for client errors, 5xx for server errors
# 400: Bad request (validation failure)
# 401: Unauthorized (missing/invalid auth)
# 403: Forbidden (auth valid but access denied)
# 404: Not found
# 409: Conflict (e.g., duplicate cert)
# 500: Internal server error (unexpected)
```

### Testing (pytest)
```python
# REQUIRED: pytest with descriptive test function names
import pytest
import json
import os

def test_all_19_modes_present_in_mode_manager():
    """All 19 game mode IDs must exist in FEL_ModeManager.production.json"""
    REQUIRED_MODES = [
        "basketball_h2h", "basketball_dunk", "basketball_3v3",
        "karate_h2h", "karate_endless", "baseball", "football",
        "soccer", "golf", "tennis", "volleyball", "surfing",
        "skateboarding", "snowboarding", "gymnastics",
        "brain_brawl", "who_scene_it", "court_carnival", "market_browse"
    ]
    registry_path = os.path.join(os.path.dirname(__file__), "../../backend/FEL_ModeManager.production.json")
    with open(registry_path) as f:
        data = json.load(f)
    mode_ids = [m["id"] for m in data.get("modes", data if isinstance(data, list) else [])]
    for mode_id in REQUIRED_MODES:
        assert mode_id in mode_ids, f"Missing mode: {mode_id}"

# REQUIRED: No hardcoded localhost in tests (use relative paths or env vars)
# FORBIDDEN: time.sleep() in tests (use mocking)
```

### Code Organization
```python
# Router files follow this structure:
# 1. Imports
# 2. Router declaration with prefix + tags
# 3. Pydantic models (request/response)
# 4. Helper functions (private: prefixed with _)
# 5. Route handlers (grouped by resource)

# Constants go at module top or in a constants.py
XP_CAP_PER_SESSION = 500  # NEVER change without economy review
PRQ_MODE_WEIGHTS = {
    "basketball_h2h": 1.2,
    # ... all 12 production modes
}
```

---

## React (Frontend) Standards

### Component Patterns
```jsx
// REQUIRED: Functional components only
const NexusConsole = ({ bootComplete, onComplete }) => {
    const [phase, setPhase] = useState('initializing');

    return (
        <div className="bg-black text-green-400 font-mono p-4">
            {/* REQUIRED: data-testid on ALL interactive elements */}
            <button
                data-testid="nexus-console-start-btn"
                onClick={() => setPhase('scanning')}
                className="px-4 py-2 bg-green-600 text-black font-bold"
            >
                Initialize
            </button>
        </div>
    );
};

// FORBIDDEN: Class components
// class NexusConsole extends React.Component { ... }  // NO

// FORBIDDEN: Default exports without named export for testing
// export default NexusConsole;  // Only OK if also named export
```

### Styling
```jsx
// REQUIRED: Tailwind CSS only
// CORRECT:
<div className="flex flex-col gap-4 p-6 bg-gray-900 rounded-xl border border-green-500/30">

// FORBIDDEN: Inline styles
// <div style={{ display: 'flex', flexDirection: 'column' }}>  // NO

// FORBIDDEN: CSS modules or styled-components
// import styles from './NexusConsole.module.css';  // NO

// FORBIDDEN: Hardcoded color hex values in JSX
// <div className="text-[#00ff41]">  // NO — use Tailwind palette
```

### State & Effects
```jsx
// REQUIRED: useState for local state, proper dependency arrays
const [data, setData] = useState(null);
const [loading, setLoading] = useState(false);

useEffect(() => {
    let cancelled = false;
    const load = async () => {
        setLoading(true);
        try {
            const result = await fetchArenaData();
            if (!cancelled) setData(result);
        } catch (err) {
            if (!cancelled) console.error('Arena fetch failed:', err);
        } finally {
            if (!cancelled) setLoading(false);
        }
    };
    load();
    return () => { cancelled = true; };
}, []);  // REQUIRED: explicit dependency array

// FORBIDDEN: Missing cleanup (memory leaks)
// useEffect(() => { fetchData().then(setData); });  // NO — no cleanup, no dep array
```

### Data Test IDs (Required)
```jsx
// ALL interactive elements MUST have data-testid
// Pattern: component-name-element-description
<button data-testid="arena-hub-mode-selector-basketball">Basketball</button>
<input data-testid="matchmaking-prq-input" />
<select data-testid="leaderboard-scope-dropdown" />
<div data-testid="fel-os-dashboard-scan-quadrant">...</div>

// Non-interactive display elements: optional but encouraged
<div data-testid="prq-score-display">{prqScore}</div>
```

---

## Git Commit Standards

### Conventional Commits Format
```
<type>(<scope>): <description>

Types: feat | fix | test | refactor | docs | chore | ci
Scope: physics | avatar | economy | academy | registry | multiplayer | training | qa | ci | social | pm

Examples:
feat(physics): delta-time, combo chains, physics constants, defense breakdown
feat(economy): shard ledger, vault slots, card rarity + bundles
test: 15+ Swift tests, 20+ backend tests, enhanced smoke test coverage
fix(registry): add missing market_browse entry in ArenaSettings
ci: nexus-ci workflow with registry validation and backend tests
```

### Git Workflow (Each Specialist)
```bash
# 1. Ensure on correct branch
git checkout claude/nexus-engine-setup-2qgkik

# 2. Pull latest before working
git pull --rebase origin claude/nexus-engine-setup-2qgkik

# 3. Read your files, make changes

# 4. Stage ONLY your owned files (never git add -A or git add .)
git add FinalEvolutionLab/Models/GoldenEraEngine.swift
git add FinalEvolutionLab/Models/MatrixPhysicsEngine.swift
git add FinalEvolutionLab/Models/ArcadePhysics.swift
git add FinalEvolutionLab/Models/DefensivePhysics.swift

# 5. Commit with conventional message
git commit -m "feat(physics): delta-time, combo chains, physics constants, defense breakdown"

# 6. Pull --rebase before push to pick up concurrent changes
git pull --rebase origin claude/nexus-engine-setup-2qgkik

# 7. Push with retry (exponential backoff on conflict)
# Attempt 1: immediate
git push origin claude/nexus-engine-setup-2qgkik
# If rejected (non-fast-forward): wait 5s, pull --rebase, push again
# If still rejected: wait 15s, pull --rebase, push again
# If still rejected: wait 30s, pull --rebase, push again
```

### Prohibited Actions
- `git push --force` or `git push -f` — NEVER
- `git add -A` or `git add .` — NEVER (stage only your files)
- `git commit --amend` on pushed commits — NEVER
- Touching files outside your assigned scope — NEVER
- Committing `.env` files or secrets — NEVER
- Skipping `git pull --rebase` before push — NEVER

---

## Registry Standards

### JSON Formatting
```json
{
    "id": "basketball_h2h",
    "map": "/Game/FEL/Venues/VeniceBeach/VeniceBeach",
    "gamemode_class": "BP_BasketballH2H",
    "status": "production",
    "max_players": 2,
    "min_players": 2,
    "session_timeout_seconds": 600,
    "prq_weight": 1.2
}
```
- 4-space indentation (no tabs)
- String values in double quotes
- No trailing commas
- Validate after every edit: `python3 -m json.tool FILE > /dev/null`

### Registry Consistency Rules
1. Mode IDs must be identical across ALL 6 registries
2. Map paths format: `/Game/FEL/Venues/{VenueName}/{VenueName}` (no `/Maps/` prefix)
3. `market_browse`: NO prq_weight, NO session_timeout_seconds, NO economy fields
4. Staging modes (`skateboarding`, `snowboarding`, `gymnastics`, `brain_brawl`): `prq_weight: 0` (economy disabled)
5. Preview modes (`who_scene_it`, `court_carnival`): `status: "preview"`, no economy until promoted
6. All 6 registries MUST be updated in the same commit when adding/modifying any mode
