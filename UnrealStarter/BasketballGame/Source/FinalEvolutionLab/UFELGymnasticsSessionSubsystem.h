// Copyright (c) Final Evolution Lab.
// Gymnastics arena — stamina-drain floor routine; PRQ reduces drain, Creator Card adds flair multiplier.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELGymnasticsSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELGymnasticsSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bGymnastics);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FString BuildHudLine() const;

private:
	enum class ERoutinePhase : uint8
	{
		Idle,
		Performing,
		Skill,
		Landing,
		Scored,
		Cooldown
	};

	bool bSessionActive = false;
	ERoutinePhase Phase = ERoutinePhase::Idle;
	float PhaseTimer = 0.f;
	float Stamina01 = 1.f;
	float DrainScale = 1.f;
	float FlairMultiplier = 1.f;
	int32 SkillsCompleted = 0;
	int32 TotalSkills = 8;
	float TotalScore = 0.f;
	float ExecutionScore = 0.f;
	float DifficultyScore = 0.f;
	int32 RoutineNumber = 1;
	FString LastResultLine;

	void BeginRoutine(AFELBasketballGameMode* GameMode);
	void AttemptSkill(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void ScoreRoutine(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
};
