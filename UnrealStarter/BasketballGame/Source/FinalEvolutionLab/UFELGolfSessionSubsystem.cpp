// Copyright (c) Final Evolution Lab.

#include "UFELGolfSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "Math/UnrealMathUtility.h"

void UFELGolfSessionSubsystem::ResetForMatch(const bool bGolf)
{
	bSessionActive = bGolf;
	Phase = EGolfPhase::Idle;
	PhaseTimer = 0.f;
	CurrentHole = 1;
	StrokeCount = 0;
	TotalStrokes = 0;
	ParTarget = 36;
	DistanceToPin = 0.f;
	SwingPower01 = 0.f;
	PlaneStability01 = 0.f;
	LastResultLine.Empty();
}

float UFELGolfSessionSubsystem::ComputeHoleDistance(const int32 Hole) const
{
	const float Base = 150.f + static_cast<float>(Hole) * 25.f;
	return FMath::Clamp(Base + FMath::FRandRange(-20.f, 30.f), 120.f, 420.f);
}

int32 UFELGolfSessionSubsystem::ComputeHolePar(const int32 Hole) const
{
	if (Hole <= 3) return 3;
	if (Hole <= 6) return 4;
	return 5;
}

void UFELGolfSessionSubsystem::BeginNextHole(AFELBasketballGameMode* GameMode, AFELBasketballGameState* /*GameState*/)
{
	StrokeCount = 0;
	DistanceToPin = ComputeHoleDistance(CurrentHole);
	Phase = EGolfPhase::Setup;
	PhaseTimer = 0.f;

	const float PRQ = GameMode ? static_cast<float>(GameMode->GetNeuroPRQScoreFloat()) : 75.f;
	const float Leakage = GameMode ? GameMode->GetNeuroKineticLeakageMultiplierFloat() : 1.f;
	PlaneStability01 = FELTwelvePillarArenaGameplay::GolfSwingPlaneStability(PRQ, Leakage);
}

void UFELGolfSessionSubsystem::CommitSwing(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	StrokeCount++;
	TotalStrokes++;

	const float PRQ = GameMode ? static_cast<float>(GameMode->GetNeuroPRQScoreFloat()) : 75.f;
	const float Leakage = GameMode ? GameMode->GetNeuroKineticLeakageMultiplierFloat() : 1.f;
	PlaneStability01 = FELTwelvePillarArenaGameplay::GolfSwingPlaneStability(PRQ, Leakage);

	SwingPower01 = FMath::Clamp(PlaneStability01 * FMath::FRandRange(0.85f, 1.1f), 0.f, 1.f);
	const float ShotDistance = DistanceToPin * SwingPower01;
	DistanceToPin = FMath::Max(0.f, DistanceToPin - ShotDistance);

	if (DistanceToPin < 5.f)
	{
		const int32 HolePar = ComputeHolePar(CurrentHole);
		const int32 RelativePar = StrokeCount - HolePar;
		FString ScoreLabel;
		if (RelativePar <= -2) ScoreLabel = TEXT("Eagle");
		else if (RelativePar == -1) ScoreLabel = TEXT("Birdie");
		else if (RelativePar == 0) ScoreLabel = TEXT("Par");
		else if (RelativePar == 1) ScoreLabel = TEXT("Bogey");
		else ScoreLabel = FString::Printf(TEXT("+%d"), RelativePar);

		LastResultLine = FString::Printf(TEXT("Hole %d: %s (%d strokes, par %d)"), CurrentHole, *ScoreLabel, StrokeCount, HolePar);

		if (GameState && GameState->IsScoringEnabled())
		{
			const int32 Points = FMath::Max(1, HolePar - StrokeCount + 3);
			GameState->AddScore(Points);
		}

		CurrentHole++;
		if (CurrentHole > TotalHoles)
		{
			if (GameState && !GameState->HasMatchEnded())
			{
				const FString Banner = FString::Printf(TEXT("Round complete — %d strokes (par %d)"), TotalStrokes, ParTarget);
				GameState->EndMatch(Banner, TEXT("Full round finished."));
			}
			Phase = EGolfPhase::Idle;
			return;
		}
		EnterCooldown(LastResultLine);
	}
	else
	{
		LastResultLine = FString::Printf(TEXT("Shot %d: %.0f yds remaining · Stability %.0f%%"),
			StrokeCount, DistanceToPin, PlaneStability01 * 100.f);
		Phase = EGolfPhase::Setup;
		PhaseTimer = 0.f;
	}
}

void UFELGolfSessionSubsystem::EnterCooldown(const FString& ResultText)
{
	Phase = EGolfPhase::Cooldown;
	PhaseTimer = 0.f;
	LastResultLine = ResultText;
}

void UFELGolfSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Golf)
	{
		return;
	}

	PhaseTimer += DeltaSeconds;

	switch (Phase)
	{
	case EGolfPhase::Idle:
		BeginNextHole(GameMode, GameState);
		break;
	case EGolfPhase::Setup:
		if (PhaseTimer > 1.5f)
		{
			Phase = EGolfPhase::Backswing;
			PhaseTimer = 0.f;
		}
		break;
	case EGolfPhase::Backswing:
		if (PhaseTimer > 0.8f)
		{
			Phase = EGolfPhase::Downswing;
			PhaseTimer = 0.f;
		}
		break;
	case EGolfPhase::Downswing:
		if (PhaseTimer > 0.35f)
		{
			CommitSwing(GameMode, GameState);
		}
		break;
	case EGolfPhase::Flight:
	case EGolfPhase::Landed:
		break;
	case EGolfPhase::Cooldown:
		if (PhaseTimer > 2.0f)
		{
			BeginNextHole(GameMode, GameState);
		}
		break;
	}
}

FString UFELGolfSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Golf · Hole %d/%d · Strokes %d · Dist %.0f yds · Stability %.0f%% · %s"),
		CurrentHole, TotalHoles, StrokeCount, DistanceToPin,
		PlaneStability01 * 100.f, *LastResultLine);
}
