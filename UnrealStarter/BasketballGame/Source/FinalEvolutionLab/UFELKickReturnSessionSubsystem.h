// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELKickReturnSim.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELKickReturnSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

UCLASS()
class FINALEVOLUTIONLAB_API UFELKickReturnSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bFootballKickReturn);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	FFELKickReturnRuntime& GetRuntime() { return Runtime; }

	FString BuildHudLine() const;

protected:
	bool bSessionActive = false;
	FFELKickReturnRuntime Runtime;
};
