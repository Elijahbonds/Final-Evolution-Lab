// Copyright (c) Final Evolution Lab.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"
#include "FELStreetJamArcade.h"
#include "FELJumpTimingTypes.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UFELCreatorCard.h"
#include "UFELStreetJamSessionSubsystem.generated.h"

class AFELBasketballGameMode;
class AFELBasketballGameState;

/** Street / Vol.2-style juice for basketball H2H and 3v3 (not dunk contest). */
UCLASS()
class FINALEVOLUTIONLAB_API UFELStreetJamSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** Binds stood `UFELCreatorCard` from profile when Street Jam is active (H2H / 3v3). */
	void ResetForMatch(bool bStreetJamArcade, const FFELReadinessSnapshot* OptionalProfile = nullptr);

	UFUNCTION(BlueprintPure, Category = "FEL|StreetJam")
	UFELCreatorCard* GetBoundCreatorCard() const { return BoundCreatorCard; }

	void ProgressSession(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, float DeltaSeconds);

	void NotifyJumpGather(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState, EFELJumpTimingBand Band);

	/** Call after base bucket points are applied; returns flat gamebreaker bonus to add. */
	int32 NotifyBucketScored(AFELBasketballGameMode* GameMode, AFELBasketballGameState* GameState);

	FFELStreetJamArcadeRuntime& GetRuntime() { return Runtime; }

protected:
	bool bSessionActive = false;
	FFELStreetJamArcadeRuntime Runtime;

	UPROPERTY(Transient)
	TObjectPtr<UFELCreatorCard> BoundCreatorCard = nullptr;
};
