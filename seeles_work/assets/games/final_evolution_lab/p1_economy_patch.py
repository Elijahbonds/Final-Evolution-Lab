## P1 Economy Patch — backend/server.py
## Branch: anti-gravity-fel
## Replaces the two helper functions and create_game_session endpoint
## Apply with: cd Final-Evolution-Lab && git apply p1_economy.patch

# ─────────────────────────────────────────────────────────────────────────────
# REPLACE block 1 of 2:
#   Find:   "## ── PRQ Mode Weights & Economy Constants"  (line ~389)
#   Replace the two helper functions with the versions below.
# ─────────────────────────────────────────────────────────────────────────────

## ── PRQ Mode Weights & Economy Constants ───────────────────────────────────
PRQ_MODE_WEIGHTS = {
    "basketball_h2h": 1.2, "basketball_dunk": 1.0, "basketball_3v3": 1.3,
    "karate_h2h": 1.4,     "karate_endless": 1.4,
    "baseball": 1.0,       "football": 1.5,       "soccer": 1.1,
    "golf": 0.9,           "tennis": 1.1,          "volleyball": 1.2,
    "surfing": 1.05,       "skateboarding": 1.0,   "snowboarding": 1.0,
    "gymnastics": 1.0,     "brain_brawl": 0.8,
    "who_scene_it": 0.7,   "court_carnival": 0.9,
}

SHARD_WIN, SHARD_DRAW, SHARD_LOSS = 50, 25, 15
SHARD_COMBO_MULTIPLIER, SHARD_CRITICAL_BONUS = 5, 10
XP_CAP_PER_SESSION = 500                    # Hard cap — never award more than 500 XP per session

# PRQ outcome base scores (v2.0 spec §6.1)
PRQ_OUTCOME_BASE = {"win": 2.0, "draw": 0.5, "loss": 0.2}


def _compute_prq_delta(
    mode_id: str,
    score: int,
    duration: int,
    completed: bool,
    outcome: str = "loss",
    combo_count: int = 0,
    critical_count: int = 0,
    mri_score: float = 50.0,
) -> float:
    """
    PRQ delta per v2.0 Architecture §6.1:
        prq_delta = min(100,
            prq_base * mode_weight
            + combo_bonus      (capped 1.0)
            + critical_bonus   (capped 0.5)
            + dominance_bonus  (capped 0.5, win-only)
            + mri_bonus        (capped 0.5 from MRI/100 * 0.5)
        )
    """
    weight          = PRQ_MODE_WEIGHTS.get(mode_id, 1.0)
    prq_base        = PRQ_OUTCOME_BASE.get(outcome, 0.2)

    combo_bonus     = min(1.0,  combo_count    * 0.05)
    critical_bonus  = min(0.5,  critical_count * 0.1)
    dominance_bonus = min(0.5,  score * 0.05) if outcome == "win" else 0.0
    mri_bonus       = (mri_score / 100.0) * 0.5

    delta = prq_base * weight + combo_bonus + critical_bonus + dominance_bonus + mri_bonus
    return round(min(100.0, delta), 2)


def _compute_shard_reward(
    outcome: str,
    combo_count: int  = 0,
    critical_count: int = 0,
    pacing_score: int = 0,
) -> int:
    """
    Shard rewards per v2.0 Architecture §6.2:
        base        = 50 (win) | 25 (draw) | 15 (loss)
        combo_bonus = (combo_count - 3) * 5  if combo_count > 3 else 0
        crit_bonus  = critical_count * 10
        pacing_bonus = ceil(total * 0.05)  if pacing_score >= 75
    """
    import math
    base         = {"win": SHARD_WIN, "draw": SHARD_DRAW, "loss": SHARD_LOSS}.get(outcome, SHARD_LOSS)
    combo_bonus  = max(0, combo_count - 3) * SHARD_COMBO_MULTIPLIER if combo_count > 3 else 0
    crit_bonus   = critical_count * SHARD_CRITICAL_BONUS
    subtotal     = base + combo_bonus + crit_bonus
    pacing_bonus = math.ceil(subtotal * 0.05) if pacing_score >= 75 else 0
    return subtotal + pacing_bonus


# ─────────────────────────────────────────────────────────────────────────────
# REPLACE block 2 of 2:
#   Find:   "@api_router.post(\"/games/session\")"
#   Replace the entire create_game_session function with the version below.
# ─────────────────────────────────────────────────────────────────────────────

@api_router.post("/games/session")
async def create_game_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """
    P1 Economy Integration — complete session receipt.
    Commits XP (hard-capped at 500), shards (base + combo + crit + pacing 5%),
    and PRQ delta (outcome-based × mode weight + bonuses) before returning JSON.
    """
    mode_id        = data.get("mode_id",         "basketball_h2h")
    score          = int(data.get("score",        0))
    duration       = int(data.get("duration_seconds", 0))
    completed      = bool(data.get("completed",   False))
    outcome        = data.get("outcome",          "loss")   # "win" | "draw" | "loss"
    combo_count    = int(data.get("combo_count",  0))
    critical_count = int(data.get("critical_count", 0))
    pacing_score   = int(data.get("pacing_score",  0))      # 0-100; ≥75 triggers 5% shard bonus
    mri_score      = float(data.get("mri_score",  50.0))    # 0-100 from MentalResiliencyEngine

    # ── Core session record ────────────────────────────────────────────────
    s = {
        "id":               str(uuid.uuid4()),
        "user_id":          user.user_id,
        "mode_id":          mode_id,
        "score":            score,
        "duration_seconds": duration,
        "completed":        completed,
        "outcome":          outcome,
        "combo_count":      combo_count,
        "critical_count":   critical_count,
        "pacing_score":     pacing_score,
        "mri_score":        mri_score,
        "created_at":       datetime.now(timezone.utc).isoformat(),
    }

    # ── PRQ delta (outcome × mode weight + bonuses) ────────────────────────
    prq_delta = _compute_prq_delta(
        mode_id, score, duration, completed,
        outcome=outcome,
        combo_count=combo_count,
        critical_count=critical_count,
        mri_score=mri_score,
    )
    s["prq_delta"] = prq_delta

    # ── Shard reward (base + combo + crit + 5% pacing bonus) ──────────────
    shards_earned = _compute_shard_reward(outcome, combo_count, critical_count, pacing_score)
    s["shards_earned"] = shards_earned
    s["pacing_bonus_applied"] = pacing_score >= 75

    # ── XP with hard 500/session cap ──────────────────────────────────────
    raw_xp = max(10, score // 5)
    xp     = min(raw_xp, XP_CAP_PER_SESSION)   # HARD CAP: never exceeds 500
    s["xp_earned"] = xp
    s["xp_capped"] = raw_xp > XP_CAP_PER_SESSION

    # ── Persist session receipt ────────────────────────────────────────────
    await db.game_sessions.insert_one(s)

    # ── Commit XP + PRQ + shards to user document ─────────────────────────
    await db.users.update_one(
        {"user_id": user.user_id},
        {"$inc": {"xp": xp, "prq_rating": prq_delta, "shards": shards_earned}},
    )

    # ── Shard ledger entry ────────────────────────────────────────────────
    await db.shard_ledger.insert_one({
        "user_id":        user.user_id,
        "session_id":     s["id"],
        "mode_id":        mode_id,
        "shards":         shards_earned,
        "outcome":        outcome,
        "base":           {"win": SHARD_WIN, "draw": SHARD_DRAW, "loss": SHARD_LOSS}.get(outcome, SHARD_LOSS),
        "combo_count":    combo_count,
        "critical_count": critical_count,
        "pacing_score":   pacing_score,
        "pacing_bonus_applied": pacing_score >= 75,
        "created_at":     s["created_at"],
    })

    # ── Activity feed ─────────────────────────────────────────────────────
    await db.activity_feed.insert_one({
        "user_id":       user.user_id,
        "type":          "game",
        "detail":        mode_id,
        "score":         score,
        "outcome":       outcome,
        "prq_delta":     prq_delta,
        "shards_earned": shards_earned,
        "xp_earned":     xp,
        "created_at":    s["created_at"],
    })

    # ── Full session receipt returned to client ───────────────────────────
    receipt = {k: v for k, v in s.items() if k != "_id"}
    return {
        "session":         receipt,
        "xp_earned":       xp,
        "xp_capped":       raw_xp > XP_CAP_PER_SESSION,
        "xp_cap":          XP_CAP_PER_SESSION,
        "shards_earned":   shards_earned,
        "pacing_bonus":    pacing_score >= 75,
        "prq_delta":       prq_delta,
        "prq_mode_weight": PRQ_MODE_WEIGHTS.get(mode_id, 1.0),
        "prq_outcome_base": PRQ_OUTCOME_BASE.get(outcome, 0.2),
        "economy_version": "p1_v2.0",
    }
