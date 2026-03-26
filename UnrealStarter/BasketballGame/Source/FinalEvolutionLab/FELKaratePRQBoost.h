// Copyright (c) Final Evolution Lab.
// High PRQ → stronger strikes, faster movement feel, higher performance ceiling in Karate lab modes.

#pragma once

#include "CoreMinimal.h"
#include "FELKaratePRQBoost.generated.h"

USTRUCT(BlueprintType)
struct FFELKaratePRQCombatBoost
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Karate")
	float StrengthMultiplier = 1.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Karate")
	float SpeedMultiplier = 1.f;

	/** Blended regen / pressure mitigation. */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Karate")
	float PerformanceMultiplier = 1.f;
};

namespace FELKaratePRQBoost
{
	/** PRQ 0–100 → multipliers (~0.88–1.22 strength, ~0.90–1.16 speed). */
	FINALEVOLUTIONLAB_API void ComputeCombatBoost(float PRQ0to100, FFELKaratePRQCombatBoost& Out);
}
