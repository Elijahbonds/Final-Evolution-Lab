// Copyright (c) Final Evolution Lab.

#include "UFELDunkContestSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELCreatorCardResolver.h"
#include "FELDojoNeuralTempest.h"
#include "Math/UnrealMathUtility.h"

void UFELDunkContestSessionSubsystem::ResetForMatch(const bool bDunkContestArcade)
{
	bSessionActive = bDunkContestArcade;
	Runtime = FFELDunkContestArcadeRuntime();
}

void UFELDunkContestSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || !GameState->IsDunkContestArcadeActive())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::BasketballDunkContest)
	{
		return;
	}
	const float PRQ = static_cast<float>(FMath::Clamp(GameState->GetReadinessSnapshot().PRQScore, 0.0, 100.0));
	FELDunkContestArcade::TickRuntime(Runtime, DeltaSeconds, PRQ, GameMode->CurrentArenaRules.SportNeuro);
	GameState->SetDunkContestStyleHud(Runtime.StyleMeter, Runtime.ScoreMultiplier, Runtime.ChainCount);
}

void UFELDunkContestSessionSubsystem::NotifyJumpApproach(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const EFELJumpTimingBand Band)
{
	if (!bSessionActive || !GameMode || !GameState || !GameState->IsDunkContestArcadeActive())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::BasketballDunkContest)
	{
		return;
	}
	const FFELReadinessSnapshot& Snap = GameState->GetReadinessSnapshot();
	const float PRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	float CE = 1.f;
	float CS = 1.f;
	UFELCreatorCard* Card = FFELCreatorCardResolver::ResolveFromReadiness(Snap);
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, Card, CE, CS);
	const float CreatorStyle = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
	FELDunkContestArcade::ApplyApproachBand(Runtime, Band, PRQ, CreatorStyle, GameMode->CurrentArenaRules.SportNeuro);
	GameState->SetDunkContestStyleHud(Runtime.StyleMeter, Runtime.ScoreMultiplier, Runtime.ChainCount);
}
