// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELDunkContestArcade.h"
#include "FELJumpTimingTypes.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELDunkContestSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

/**
 * Dunk Contest session — style meter, chain, and bucket score multiplier (PRQ + Creator Card via readiness snapshot).
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELDunkContestSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	void ResetForMatch(bool bDunkContestArcade);

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	void NotifyJumpApproach(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, EFELJumpTimingBand Band);

	FFELDunkContestArcadeRuntime& GetRuntime() { return Runtime; }

protected:
	bool bSessionActive = false;
	FFELDunkContestArcadeRuntime Runtime;
};
