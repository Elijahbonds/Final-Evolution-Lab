// Copyright (c) Final Evolution Lab.
// Golf arena — downswing plane stability, PRQ-scaled landing accuracy, Creator Card swing power.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELGolfSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELGolfSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bGolf);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FString BuildHudLine() const;

private:
	enum class EGolfPhase : uint8
	{
		Idle,
		Setup,
		Backswing,
		Downswing,
		Flight,
		Landed,
		Cooldown
	};

	bool bSessionActive = false;
	EGolfPhase Phase = EGolfPhase::Idle;
	float PhaseTimer = 0.f;
	int32 CurrentHole = 1;
	int32 TotalHoles = 9;
	int32 StrokeCount = 0;
	int32 TotalStrokes = 0;
	int32 ParTarget = 36;
	float DistanceToPin = 0.f;
	float SwingPower01 = 0.f;
	float PlaneStability01 = 0.f;
	FString LastResultLine;

	void BeginNextHole(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void CommitSwing(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);
	void EnterCooldown(const FString& ResultText);
	float ComputeHoleDistance(int32 Hole) const;
	int32 ComputeHolePar(int32 Hole) const;
};
