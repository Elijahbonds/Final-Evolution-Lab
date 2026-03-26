// Copyright (c) Final Evolution Lab.

#include "UFELStreetJamSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELCreatorCardResolver.h"
#include "FELDojoNeuralTempest.h"
#include "UFELCreatorCard.h"
#include "Math/UnrealMathUtility.h"

void UFELStreetJamSessionSubsystem::ResetForMatch(const bool bStreetJamArcade, const FFELReadinessSnapshot* OptionalProfile)
{
	bSessionActive = bStreetJamArcade;
	Runtime = FFELStreetJamArcadeRuntime();
	BoundCreatorCard = nullptr;
	if (bStreetJamArcade && OptionalProfile)
	{
		BoundCreatorCard = FFELCreatorCardResolver::ResolveFromReadiness(*OptionalProfile);
	}
}

void UFELStreetJamSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || !GameState->IsStreetJamArcadeActive())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::BasketballHeadToHead
		&& GameMode->CurrentMode != EFELArenaMode::Basketball3v3)
	{
		return;
	}
	if (!GameState->IsScoringEnabled())
	{
		return;
	}
	const float PRQ = static_cast<float>(FMath::Clamp(GameState->GetReadinessSnapshot().PRQScore, 0.0, 100.0));
	FELStreetJamArcade::TickRuntime(Runtime, DeltaSeconds, PRQ, GameMode->CurrentArenaRules.SportNeuro);
	GameState->SetStreetJamHud(
		Runtime.TrickMeter,
		Runtime.ScoreMultiplier,
		Runtime.BucketComboCount,
		Runtime.GatherChainCount,
		Runtime.bGamebreakerBanked);
}

void UFELStreetJamSessionSubsystem::NotifyJumpGather(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const EFELJumpTimingBand Band)
{
	if (!bSessionActive || !GameMode || !GameState || !GameState->IsStreetJamArcadeActive())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::BasketballHeadToHead
		&& GameMode->CurrentMode != EFELArenaMode::Basketball3v3)
	{
		return;
	}
	if (!GameState->IsScoringEnabled())
	{
		return;
	}
	const FFELReadinessSnapshot& Snap = GameState->GetReadinessSnapshot();
	const float PRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	float CE = 1.f;
	float CS = 1.f;
	const UFELCreatorCard* Card = BoundCreatorCard;
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, Card, CE, CS);
	const float CreatorStyle = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
	FELStreetJamArcade::ApplyGatherBand(Runtime, Band, PRQ, CreatorStyle, GameMode->CurrentArenaRules.SportNeuro);
	GameState->SetStreetJamHud(
		Runtime.TrickMeter,
		Runtime.ScoreMultiplier,
		Runtime.BucketComboCount,
		Runtime.GatherChainCount,
		Runtime.bGamebreakerBanked);
}

int32 UFELStreetJamSessionSubsystem::NotifyBucketScored(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState)
{
	if (!bSessionActive || !GameMode || !GameState || !GameState->IsStreetJamArcadeActive())
	{
		return 0;
	}
	if (GameMode->CurrentMode != EFELArenaMode::BasketballHeadToHead
		&& GameMode->CurrentMode != EFELArenaMode::Basketball3v3)
	{
		return 0;
	}
	if (!GameState->IsScoringEnabled())
	{
		return 0;
	}
	const FFELReadinessSnapshot& Snap = GameState->GetReadinessSnapshot();
	const float PRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	float CE = 1.f;
	float CS = 1.f;
	const UFELCreatorCard* Card = BoundCreatorCard;
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, Card, CE, CS);
	const float CreatorStyle = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
	const int32 Bonus = FELStreetJamArcade::OnBucketScored(Runtime, PRQ, CreatorStyle, GameMode->CurrentArenaRules.SportNeuro);
	GameState->SetStreetJamHud(
		Runtime.TrickMeter,
		Runtime.ScoreMultiplier,
		Runtime.BucketComboCount,
		Runtime.GatherChainCount,
		Runtime.bGamebreakerBanked);
	return Bonus;
}
