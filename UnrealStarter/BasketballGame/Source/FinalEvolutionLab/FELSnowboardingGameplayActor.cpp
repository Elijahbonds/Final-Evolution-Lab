// Copyright (c) Final Evolution Lab.

#include "FELSnowboardingGameplayActor.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FinalEvolutionLab.h"
#include "Math/UnrealMathUtility.h"

AFELSnowboardingGameplayActor::AFELSnowboardingGameplayActor()
{
	PrimaryActorTick.bCanEverTick = true;
}

void AFELSnowboardingGameplayActor::BeginPlay() { Super::BeginPlay(); }

void AFELSnowboardingGameplayActor::InitSnowSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	CachedGameMode = GameMode;
	CachedGameState = GameState;
	ScoreCard = FFELSnowScoreCard();
	CurrentPhase = EFELSnowPhase::Carving;
	PhaseTimer = 0.f;
	ComboTrickCount = 0;
	ComboGraceTimer = 0.f;
	SlopeGrade = 0.5f;
}

float AFELSnowboardingGameplayActor::GetPRQ() const
{
	return CachedGameMode.IsValid() ? CachedGameMode->GetNeuroPRQScoreFloat() : 75.f;
}

float AFELSnowboardingGameplayActor::GetLeakage() const
{
	return CachedGameMode.IsValid() ? CachedGameMode->GetNeuroKineticLeakageMultiplierFloat() : 1.f;
}

void AFELSnowboardingGameplayActor::TransitionToPhase(EFELSnowPhase NewPhase)
{
	CurrentPhase = NewPhase;
	PhaseTimer = 0.f;
}

void AFELSnowboardingGameplayActor::HandleCarveInput(float Direction)
{
	if (CurrentPhase == EFELSnowPhase::Carving)
	{
		const float PRQ01 = GetPRQ() * 0.01f;
		ScoreCard.EdgeGrip01 = FMath::Clamp(ScoreCard.EdgeGrip01 + FMath::Lerp(0.05f, 0.15f, PRQ01), 0.f, 1.f);
		ScoreCard.Speed01 = FMath::Clamp(ScoreCard.Speed01 + 0.03f * ScoreCard.EdgeGrip01, 0.f, 1.f);
		ScoreCard.CurrentRunScore += FMath::Lerp(2.f, 5.f, PRQ01) * ScoreCard.EdgeGrip01;
	}
}

void AFELSnowboardingGameplayActor::HandleJumpInput()
{
	if (CurrentPhase == EFELSnowPhase::Carving || CurrentPhase == EFELSnowPhase::Rail)
	{
		TransitionToPhase(EFELSnowPhase::Jump);
	}
}

void AFELSnowboardingGameplayActor::HandleTrickInput(int32 TrickId)
{
	if (CurrentPhase != EFELSnowPhase::Jump && CurrentPhase != EFELSnowPhase::AirTrick)
		return;

	TransitionToPhase(EFELSnowPhase::AirTrick);
	const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);
	const float LandChance = FMath::Lerp(0.55f, 0.95f, PRQ01) * ScoreCard.EdgeGrip01;

	if (FMath::FRand() < LandChance)
	{
		float TrickValue = FMath::Lerp(60.f, 250.f, FMath::Clamp(TrickId * 0.12f, 0.f, 1.f));
		TrickValue *= (1.f + PRQ01 * 0.35f);
		ScoreCard.CurrentRunScore += TrickValue;
		ComboTrickCount++;
		ScoreCard.ComboMultiplier = 1.f + ComboTrickCount * 0.3f;
		ComboGraceTimer = FMath::Lerp(2.f, 3.5f, PRQ01);
		ScoreCard.TricksLanded++;
	}
	else
	{
		TriggerCrash();
	}
}

void AFELSnowboardingGameplayActor::HandleRailInput()
{
	if (CurrentPhase == EFELSnowPhase::Jump || CurrentPhase == EFELSnowPhase::Carving)
	{
		TransitionToPhase(EFELSnowPhase::Rail);
		ScoreCard.RailsCompleted++;
		ComboTrickCount++;
		ScoreCard.ComboMultiplier = 1.f + ComboTrickCount * 0.3f;
		ScoreCard.CurrentRunScore += 50.f;
		ComboGraceTimer = 2.5f;
	}
}

void AFELSnowboardingGameplayActor::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!CachedGameMode.IsValid() || !CachedGameState.IsValid()) return;
	if (CachedGameState->HasMatchEnded()) return;

	PhaseTimer += DeltaSeconds;
	const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);

	// Combo grace
	if (ComboGraceTimer > 0.f)
	{
		ComboGraceTimer -= DeltaSeconds;
		if (ComboGraceTimer <= 0.f && ComboTrickCount > 0) CommitRunScore();
	}

	// Distance
	ScoreCard.DistanceMeters += ScoreCard.Speed01 * 15.f * DeltaSeconds;

	switch (CurrentPhase)
	{
	case EFELSnowPhase::Carving:
		{
			const float GripLoss = FMath::Max(0.02f, 0.08f - PRQ01 * 0.04f);
			ScoreCard.EdgeGrip01 = FMath::Clamp(ScoreCard.EdgeGrip01 - GripLoss * DeltaSeconds, 0.f, 1.f);
			ScoreCard.Speed01 = FMath::Clamp(ScoreCard.Speed01 + SlopeGrade * 0.05f * DeltaSeconds, 0.f, 1.f);
			ScoreCard.CurrentRunScore += ScoreCard.Speed01 * 2.f * DeltaSeconds;
			if (ScoreCard.EdgeGrip01 < 0.08f && ScoreCard.Speed01 > 0.7f) TriggerCrash();
		}
		break;
	case EFELSnowPhase::Jump:
		if (PhaseTimer > 0.5f) TransitionToPhase(EFELSnowPhase::AirTrick);
		break;
	case EFELSnowPhase::AirTrick:
		if (PhaseTimer > FMath::Lerp(1.f, 2.2f, ScoreCard.Speed01))
			TransitionToPhase(EFELSnowPhase::Landing);
		break;
	case EFELSnowPhase::Rail:
		{
			const float RailDrain = FMath::Max(0.04f, 0.14f - PRQ01 * 0.08f);
			ScoreCard.EdgeGrip01 = FMath::Clamp(ScoreCard.EdgeGrip01 - RailDrain * DeltaSeconds, 0.f, 1.f);
			ScoreCard.CurrentRunScore += 25.f * DeltaSeconds;
			ComboGraceTimer = 2.5f;
			if (ScoreCard.EdgeGrip01 < 0.1f) TriggerCrash();
			if (PhaseTimer > FMath::Lerp(1.5f, 3.5f, PRQ01))
				TransitionToPhase(EFELSnowPhase::Landing);
		}
		break;
	case EFELSnowPhase::Landing:
		{
			ScoreCard.EdgeGrip01 = FMath::Clamp(ScoreCard.EdgeGrip01 + 0.25f, 0.f, 1.f);
			if (PhaseTimer > 0.5f) TransitionToPhase(EFELSnowPhase::Carving);
		}
		break;
	case EFELSnowPhase::Crash:
		if (PhaseTimer > 2.f)
		{
			ScoreCard.EdgeGrip01 = 0.8f;
			ScoreCard.Speed01 = 0.3f;
			TransitionToPhase(EFELSnowPhase::Carving);
		}
		break;
	case EFELSnowPhase::FinishLine:
		break;
	}
}

void AFELSnowboardingGameplayActor::CommitRunScore()
{
	const float FinalScore = ScoreCard.CurrentRunScore * ScoreCard.ComboMultiplier;
	ScoreCard.TotalScore += FinalScore;
	if (FinalScore > ScoreCard.BestTrickScore)
		ScoreCard.BestTrickScore = FinalScore;

	if (CachedGameState.IsValid() && CachedGameState->IsScoringEnabled())
		CachedGameState->AddScore(FMath::FloorToInt(FinalScore * 0.01f));

	ScoreCard.CurrentRunScore = 0.f;
	ScoreCard.ComboMultiplier = 1.f;
	ComboTrickCount = 0;
}

void AFELSnowboardingGameplayActor::TriggerCrash()
{
	ScoreCard.Crashes++;
	ScoreCard.CurrentRunScore *= 0.3f;
	CommitRunScore();
	ComboGraceTimer = 0.f;
	TransitionToPhase(EFELSnowPhase::Crash);
}

FString AFELSnowboardingGameplayActor::BuildHudLine() const
{
	const TCHAR* PhaseName = TEXT("Idle");
	switch (CurrentPhase)
	{
	case EFELSnowPhase::Carving: PhaseName = TEXT("Carving"); break;
	case EFELSnowPhase::Jump: PhaseName = TEXT("Jump!"); break;
	case EFELSnowPhase::AirTrick: PhaseName = TEXT("AIR!"); break;
	case EFELSnowPhase::Rail: PhaseName = TEXT("RAIL"); break;
	case EFELSnowPhase::Landing: PhaseName = TEXT("Landing"); break;
	case EFELSnowPhase::Crash: PhaseName = TEXT("CRASH"); break;
	case EFELSnowPhase::FinishLine: PhaseName = TEXT("FINISH"); break;
	}
	return FString::Printf(
		TEXT("Snow · %s · run %.0f × %.1f · total %.0f · dist %.0fm · grip %.0f%%"),
		PhaseName, ScoreCard.CurrentRunScore, ScoreCard.ComboMultiplier,
		ScoreCard.TotalScore, ScoreCard.DistanceMeters, ScoreCard.EdgeGrip01 * 100.f);
}
