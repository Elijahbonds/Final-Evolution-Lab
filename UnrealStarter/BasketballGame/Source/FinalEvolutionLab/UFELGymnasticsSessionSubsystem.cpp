// Copyright (c) Final Evolution Lab.

#include "UFELGymnasticsSessionSubsystem.h"
#include "FELArenaModeDefinitions.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballGameState.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "Math/UnrealMathUtility.h"

void UFELGymnasticsSessionSubsystem::ResetForMatch(const bool bGymnastics)
{
	bSessionActive = bGymnastics;
	Phase = ERoutinePhase::Idle;
	PhaseTimer = 0.f;
	Stamina01 = 1.f;
	DrainScale = 1.f;
	FlairMultiplier = 1.f;
	SkillsCompleted = 0;
	TotalSkills = 8;
	TotalScore = 0.f;
	ExecutionScore = 0.f;
	DifficultyScore = 0.f;
	RoutineNumber = 1;
	LastResultLine.Empty();
}

void UFELGymnasticsSessionSubsystem::BeginRoutine(AFELBasketballGameMode* GameMode)
{
	Phase = ERoutinePhase::Performing;
	PhaseTimer = 0.f;
	Stamina01 = 1.f;
	SkillsCompleted = 0;
	ExecutionScore = 0.f;
	DifficultyScore = 0.f;

	const float PRQ = GameMode ? GameMode->GetNeuroPRQScoreFloat() : 75.f;
	DrainScale = FELTwelvePillarArenaGameplay::GymnasticsStaminaDrainScale(PRQ);
	FlairMultiplier = FMath::Lerp(0.9f, 1.2f, FMath::Clamp(PRQ * 0.01f, 0.f, 1.f));
}

void UFELGymnasticsSessionSubsystem::AttemptSkill(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState)
{
	const float BaseDrain = 0.12f;
	Stamina01 = FMath::Max(0.f, Stamina01 - BaseDrain * DrainScale);

	const float PRQ01 = GameMode ? GameMode->GetNeuroPRQScoreFloat() * 0.01f : 0.75f;
	const float LandingQuality = FMath::Clamp(PRQ01 * Stamina01 * FMath::FRandRange(0.8f, 1.15f), 0.f, 1.f);

	const float SkillDifficulty = 0.3f + static_cast<float>(SkillsCompleted) * 0.08f;
	DifficultyScore += SkillDifficulty;

	const float ExecutionMark = LandingQuality * 10.f * FlairMultiplier;
	ExecutionScore += ExecutionMark;
	SkillsCompleted++;

	const bool bStuck = LandingQuality > 0.85f;
	LastResultLine = FString::Printf(TEXT("Skill %d: %.1f exec · %s · Stamina %.0f%%"),
		SkillsCompleted, ExecutionMark,
		bStuck ? TEXT("Stuck!") : TEXT("Step"),
		Stamina01 * 100.f);

	if (Stamina01 <= 0.f || SkillsCompleted >= TotalSkills)
	{
		ScoreRoutine(GameMode, GameState);
		return;
	}

	Phase = ERoutinePhase::Performing;
	PhaseTimer = 0.f;
}

void UFELGymnasticsSessionSubsystem::ScoreRoutine(AFELBasketballGameMode* /*GameMode*/, AFELBasketballGameState* GameState)
{
	const float RoutineTotal = ExecutionScore + DifficultyScore;
	TotalScore += RoutineTotal;

	if (GameState && GameState->IsScoringEnabled())
	{
		GameState->AddScore(FMath::RoundToInt(RoutineTotal));
	}

	LastResultLine = FString::Printf(TEXT("Routine %d: Exec %.1f + Diff %.1f = %.1f"),
		RoutineNumber, ExecutionScore, DifficultyScore, RoutineTotal);

	RoutineNumber++;
	const int32 MaxRoutines = 3;
	if (RoutineNumber > MaxRoutines)
	{
		if (GameState && !GameState->HasMatchEnded())
		{
			GameState->EndMatch(
				FString::Printf(TEXT("Gymnastics complete — Total: %.1f"), TotalScore),
				FString::Printf(TEXT("%d routines, %d skills"), MaxRoutines, MaxRoutines * TotalSkills));
		}
		Phase = ERoutinePhase::Idle;
		return;
	}

	Phase = ERoutinePhase::Cooldown;
	PhaseTimer = 0.f;
}

void UFELGymnasticsSessionSubsystem::ProgressSession(
	AFELBasketballGameMode* GameMode,
	AFELBasketballGameState* GameState,
	const float DeltaSeconds)
{
	if (!bSessionActive || !GameMode || !GameState || GameState->HasMatchEnded())
	{
		return;
	}
	if (GameMode->CurrentMode != EFELArenaMode::Gymnastics)
	{
		return;
	}

	PhaseTimer += DeltaSeconds;

	switch (Phase)
	{
	case ERoutinePhase::Idle:
		BeginRoutine(GameMode);
		break;
	case ERoutinePhase::Performing:
		if (PhaseTimer > 0.9f)
		{
			Phase = ERoutinePhase::Skill;
			PhaseTimer = 0.f;
		}
		break;
	case ERoutinePhase::Skill:
		if (PhaseTimer > 0.5f)
		{
			AttemptSkill(GameMode, GameState);
		}
		break;
	case ERoutinePhase::Landing:
	case ERoutinePhase::Scored:
	case ERoutinePhase::Cooldown:
		if (PhaseTimer > 2.0f)
		{
			BeginRoutine(GameMode);
		}
		break;
	}
}

FString UFELGymnasticsSessionSubsystem::BuildHudLine() const
{
	if (!bSessionActive)
	{
		return FString();
	}
	return FString::Printf(
		TEXT("Gymnastics · Routine %d · Skills %d/%d · Stamina %.0f%% · Drain %.2fx · Total %.1f · %s"),
		RoutineNumber, SkillsCompleted, TotalSkills,
		Stamina01 * 100.f, DrainScale, TotalScore, *LastResultLine);
}
