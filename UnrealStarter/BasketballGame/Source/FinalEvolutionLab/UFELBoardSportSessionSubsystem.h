// Copyright (c) Final Evolution Lab.
// Surf / skate / snow line sessions — PRQ scales line rate, trick fill, and balance mitigation (SportNeuro BoardSport*).

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELBoardSportSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELBoardSportSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bBoardSportActive);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FString BuildHudLine() const;

private:
	bool bSessionActive = false;
	float LineScore = 0.f;
	float TrickGauge0to100 = 0.f;
	float Balance01 = 1.f;
	int32 LastFlooredLineScore = 0;
	int32 WipeoutCount = 0;
	FString LastLine;
};
