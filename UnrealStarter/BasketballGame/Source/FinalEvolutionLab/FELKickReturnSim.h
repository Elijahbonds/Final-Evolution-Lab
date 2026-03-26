// Copyright (c) Final Evolution Lab.
// Continuous kick return vs escalating waves; you vs ghost opponent alternate possessions. PRQ → speed & durability; Creator → performance.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELKickReturnSim.generated.h"

USTRUCT(BlueprintType)
struct FFELKickReturnRuntime
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	bool bPlayerTurn = true;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	int32 WaveIndex = 1;

	/** Field position 0–100 (TD at 100). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	float YardsOnField = 25.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	float PlayerDurability01 = 1.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	float OpponentDurability01 = 1.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	float TackleGauge01 = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	int32 PlayerTouchdowns = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|KickReturn")
	int32 OpponentTouchdowns = 0;
};

namespace FELKickReturnSim
{
	FINALEVOLUTIONLAB_API void Reset(FFELKickReturnRuntime& R);

	/**
	 * @param PlayerCreatorArena sqrt-style composite from Creator Card (performance lane).
	 */
	FINALEVOLUTIONLAB_API void Tick(
		FFELKickReturnRuntime& R,
		float DeltaSeconds,
		float PlayerPRQ0to100,
		float PlayerCreatorArena,
		float GhostOpponentPRQ0to100,
		const FFELSportNeuroConstants& N);
}
