// Copyright (c) Final Evolution Lab.

#include "FELSurfingGameplayActor.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FinalEvolutionLab.h"
#include "Math/UnrealMathUtility.h"

AFELSurfingGameplayActor::AFELSurfingGameplayActor()
{
	PrimaryActorTick.bCanEverTick = true;
}

void AFELSurfingGameplayActor::BeginPlay()
{
	Super::BeginPlay();
}

void AFELSurfingGameplayActor::InitSurfSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	CachedGameMode = GameMode;
	CachedGameState = GameState;
	ScoreCard = FFELSurfScoreCard();
	CurrentPhase = EFELSurfWavePhase::Paddling;
	WaveTimer = 0.f;
	CurrentWaveScore = 0.f;
	Balance01 = 1.f;
	SwellIntensity = 0.5f;
	ComboCount = 0;
	ComboTimer = 0.f;
}

float AFELSurfingGameplayActor::GetPRQ() const
{
	if (CachedGameMode.IsValid()) return CachedGameMode->GetNeuroPRQScoreFloat();
	return 75.f;
}

float AFELSurfingGameplayActor::GetLeakage() const
{
	if (CachedGameMode.IsValid()) return CachedGameMode->GetNeuroKineticLeakageMultiplierFloat();
	return 1.f;
}

void AFELSurfingGameplayActor::TransitionToPhase(EFELSurfWavePhase NewPhase)
{
	CurrentPhase = NewPhase;
	WaveTimer = 0.f;
}

void AFELSurfingGameplayActor::HandlePaddleInput()
{
	if (CurrentPhase == EFELSurfWavePhase::Paddling)
	{
		const float PRQ01 = GetPRQ() * 0.01f;
		if (WaveTimer > FMath::Lerp(3.f, 1.5f, PRQ01))
		{
			TransitionToPhase(EFELSurfWavePhase::Takeoff);
		}
	}
}

void AFELSurfingGameplayActor::HandleTrickInput(int32 TrickIndex)
{
	if (CurrentPhase != EFELSurfWavePhase::Riding && CurrentPhase != EFELSurfWavePhase::TubeRide)
		return;

	const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);
	const float SuccessChance = FMath::Lerp(0.55f, 0.95f, PRQ01) * Balance01;

	if (FMath::FRand() < SuccessChance)
	{
		const float TrickScore = FMath::Lerp(5.f, 15.f, PRQ01) * (1.f + ComboCount * 0.15f);
		CurrentWaveScore += TrickScore;
		ComboCount++;
		ComboTimer = 3.f;

		if (TrickIndex >= 3) // aerial trick
		{
			TransitionToPhase(EFELSurfWavePhase::Aerial);
			ScoreCard.AerialsLanded++;
			CurrentWaveScore += 8.f;
		}
		ScoreCard.StyleMeter = FMath::Clamp(ScoreCard.StyleMeter + TrickScore * 0.8f, 0.f, 100.f);
	}
	else
	{
		if (Balance01 < 0.3f)
			TriggerWipeout();
		else
			Balance01 -= 0.15f;
	}
}

void AFELSurfingGameplayActor::HandleCutbackInput(float Direction)
{
	if (CurrentPhase == EFELSurfWavePhase::Riding)
	{
		TransitionToPhase(EFELSurfWavePhase::Cutback);
		const float PRQ01 = GetPRQ() * 0.01f;
		CurrentWaveScore += FMath::Lerp(3.f, 8.f, PRQ01);
		Balance01 = FMath::Clamp(Balance01 + 0.1f, 0.f, 1.f);
	}
}

void AFELSurfingGameplayActor::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!CachedGameMode.IsValid() || !CachedGameState.IsValid()) return;
	if (CachedGameState->HasMatchEnded()) return;

	WaveTimer += DeltaSeconds;

	if (ComboTimer > 0.f)
	{
		ComboTimer -= DeltaSeconds;
		if (ComboTimer <= 0.f) ComboCount = 0;
	}

	ScoreCard.StyleMeter = FMath::Max(0.f, ScoreCard.StyleMeter - 0.38f * DeltaSeconds);

	switch (CurrentPhase)
	{
	case EFELSurfWavePhase::Paddling:
		ProgressPaddling(DeltaSeconds);
		break;
	case EFELSurfWavePhase::Takeoff:
		if (WaveTimer > 0.8f) TransitionToPhase(EFELSurfWavePhase::Riding);
		break;
	case EFELSurfWavePhase::Riding:
	case EFELSurfWavePhase::Cutback:
		ProgressRiding(DeltaSeconds);
		break;
	case EFELSurfWavePhase::TubeRide:
		ProgressTubeRide(DeltaSeconds);
		break;
	case EFELSurfWavePhase::Aerial:
		if (WaveTimer > 1.2f)
		{
			if (Balance01 > 0.4f)
				TransitionToPhase(EFELSurfWavePhase::Riding);
			else
				TriggerWipeout();
		}
		break;
	case EFELSurfWavePhase::Wipeout:
		if (WaveTimer > 2.f) TransitionToPhase(EFELSurfWavePhase::Paddling);
		break;
	}
}

void AFELSurfingGameplayActor::ProgressPaddling(float DeltaSeconds)
{
	SwellIntensity = FMath::Clamp(SwellIntensity + DeltaSeconds * 0.08f, 0.3f, 1.f);
	// Auto-advance for AI opponent
	if (WaveTimer > 5.f)
	{
		TransitionToPhase(EFELSurfWavePhase::Takeoff);
	}
}

void AFELSurfingGameplayActor::ProgressRiding(float DeltaSeconds)
{
	const float PRQ01 = FMath::Clamp(GetPRQ() * 0.01f, 0.f, 1.f);
	const float Leak = GetLeakage();

	// Balance drain — mitigated by PRQ
	const float BalanceDrain = FMath::Max(0.02f, 0.12f - PRQ01 * 0.08f) * (2.f - Leak);
	Balance01 = FMath::Clamp(Balance01 - BalanceDrain * DeltaSeconds, 0.f, 1.f);

	// Passive line score
	CurrentWaveScore += (1.5f + PRQ01 * 2.f) * Balance01 * DeltaSeconds;

	// Random tube entry opportunity
	if (WaveTimer > 4.f && SwellIntensity > 0.7f && FMath::FRand() < DeltaSeconds * 0.15f)
	{
		TransitionToPhase(EFELSurfWavePhase::TubeRide);
	}

	// Wave ends
	if (WaveTimer > FMath::Lerp(12.f, 18.f, SwellIntensity))
	{
		CommitWaveScore();
		TransitionToPhase(EFELSurfWavePhase::Paddling);
	}

	if (Balance01 < 0.08f) TriggerWipeout();
}

void AFELSurfingGameplayActor::ProgressTubeRide(float DeltaSeconds)
{
	const float PRQ01 = GetPRQ() * 0.01f;
	const float TubeDrain = FMath::Max(0.05f, 0.18f - PRQ01 * 0.1f);
	Balance01 = FMath::Clamp(Balance01 - TubeDrain * DeltaSeconds, 0.f, 1.f);
	CurrentWaveScore += 4.f * DeltaSeconds;

	if (WaveTimer > FMath::Lerp(2.f, 5.f, PRQ01))
	{
		ScoreCard.TubesCompleted++;
		CurrentWaveScore += 12.f;
		TransitionToPhase(EFELSurfWavePhase::Riding);
	}

	if (Balance01 < 0.1f) TriggerWipeout();
}

void AFELSurfingGameplayActor::TriggerWipeout()
{
	ScoreCard.Wipeouts++;
	CurrentWaveScore *= 0.4f; // Penalty
	CommitWaveScore();
	Balance01 = 0.7f;
	ComboCount = 0;
	TransitionToPhase(EFELSurfWavePhase::Wipeout);
}

void AFELSurfingGameplayActor::CommitWaveScore()
{
	if (CurrentWaveScore > 0.f)
	{
		ScoreCard.WavesRidden++;
		ScoreCard.WaveScore += CurrentWaveScore;
		if (CurrentWaveScore > ScoreCard.BestWaveScore)
			ScoreCard.BestWaveScore = CurrentWaveScore;

		if (CachedGameState.IsValid() && CachedGameState->IsScoringEnabled())
		{
			CachedGameState->AddScore(FMath::FloorToInt(CurrentWaveScore));
		}
		CurrentWaveScore = 0.f;
	}
}

FString AFELSurfingGameplayActor::BuildHudLine() const
{
	const TCHAR* PhaseName = TEXT("Idle");
	switch (CurrentPhase)
	{
	case EFELSurfWavePhase::Paddling: PhaseName = TEXT("Paddling"); break;
	case EFELSurfWavePhase::Takeoff: PhaseName = TEXT("Takeoff!"); break;
	case EFELSurfWavePhase::Riding: PhaseName = TEXT("Riding"); break;
	case EFELSurfWavePhase::Cutback: PhaseName = TEXT("Cutback"); break;
	case EFELSurfWavePhase::TubeRide: PhaseName = TEXT("TUBE!"); break;
	case EFELSurfWavePhase::Aerial: PhaseName = TEXT("AIR!"); break;
	case EFELSurfWavePhase::Wipeout: PhaseName = TEXT("Wipeout"); break;
	}
	return FString::Printf(
		TEXT("Surf · %s · wave %.0f · best %.0f · combo x%d · style %.0f"),
		PhaseName, ScoreCard.WaveScore, ScoreCard.BestWaveScore, ComboCount, ScoreCard.StyleMeter);
}
