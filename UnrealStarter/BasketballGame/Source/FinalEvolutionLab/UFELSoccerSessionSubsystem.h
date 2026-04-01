// Copyright (c) Final Evolution Lab.
// Soccer arena — possession/shot/save cycle; PRQ stabilizes shot curve, Creator Card scales speed.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELSoccerSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELSoccerSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bSoccer);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FString BuildHudLine() const;

private:
	enum class ESoccerPhase : uint8
	{
		Idle,
		KickOff,
		Midfield,
		Attack,
		Shot,
		Save,
		GoalScored,
		Cooldown
	};

	bool bSessionActive = false;
	ESoccerPhase Phase = ESoccerPhase::Idle;
	float PhaseTimer = 0.f;
	bool bPlayerPossession = true;
	int32 PlayerGoals = 0;
	int32 OpponentGoals = 0;
	int32 HalfNumber = 1;
	float MatchClock = 0.f;
	float HalfDuration = 90.f;
	float ShotCurveStability = 0.8f;
	FString LastResultLine;

	void BeginKickOff(AFELBasketballGameMode* GameMode);
	void AttemptShot(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void CheckHalfTime(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
};
