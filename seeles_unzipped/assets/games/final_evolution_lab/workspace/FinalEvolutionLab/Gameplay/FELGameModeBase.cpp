// FELGameModeBase.cpp
// Phase 7 — Constructor implementations for all 19 FEL game mode subclasses.
// Production subclasses (14) rely on default UE ctor chain via their parent AFELGameModeBase.
// The 5 expansion subclasses below explicitly set bScoringEnabled and DefaultMatchDuration.

#include "FELGameModeBase.h"

// ─────────────────────────────────────────────────────────────────────────────
// AFELGameModeBase — root constructor (sets safe defaults for all subclasses)
// ─────────────────────────────────────────────────────────────────────────────
AFELGameModeBase::AFELGameModeBase()
{
    PrimaryActorTick.bCanEverTick = true;
    bScoringEnabled     = true;
    DefaultMatchDuration = 180.f;
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 7 Expansion — 5 remaining mode constructors
// ─────────────────────────────────────────────────────────────────────────────

AFELGameMode_Skateboarding::AFELGameMode_Skateboarding()
{
    bScoringEnabled      = true;
    DefaultMatchDuration = 180.f;   // 3-minute run
}

AFELGameMode_Snowboarding::AFELGameMode_Snowboarding()
{
    bScoringEnabled      = true;
    DefaultMatchDuration = 180.f;   // 3-minute slope run
}

AFELGameMode_WhoSceneIt::AFELGameMode_WhoSceneIt()
{
    bScoringEnabled      = false;   // Staged trivia mode — no P1 economy payout yet
    DefaultMatchDuration = 120.f;   // 2-minute quiz round
}

AFELGameMode_CourtCarnival::AFELGameMode_CourtCarnival()
{
    bScoringEnabled      = false;   // Party/board mode — route-based, not timed
    DefaultMatchDuration = 0.f;     // Untimed — completes on route finish
}

AFELGameMode_MarketBrowse::AFELGameMode_MarketBrowse()
{
    bScoringEnabled      = false;   // Non-game module — 3D shop/library surface
    DefaultMatchDuration = 0.f;     // No match concept
}
