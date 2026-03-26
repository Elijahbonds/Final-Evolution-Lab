// Copyright (c) Final Evolution Lab.
// Performance Readiness Quotient (0–100) as an explicit facility multiplier layer on top of scan / leakage curves.

#pragma once

#include "CoreMinimal.h"
#include "FELPRQInfluence.generated.h"

/**
 * Athlete profile → arena feel. Populated from the same readiness payload the host fills from Supabase / System Scan
 * (serialized as readiness_snapshot.json or live bridge). Composes with FELKineticLeakage — does not replace it.
 */
USTRUCT(BlueprintType)
struct FFELPRQInfluenceMultipliers
{
	GENERATED_BODY()

	/** Applied to CharacterMovement JumpZ after neuro + leakage pipeline. */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|PRQ")
	float JumpHeightMultiplier = 1.f;

	/** Applied to MaxWalkSpeed / sprint caps after neuro + leakage. */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|PRQ")
	float SprintSpeedMultiplier = 1.f;

	/**
	 * Reaction / timing scaler: lower = snappier perfect windows (multiply opponent lockouts or divide your windows in BP).
	 * 1.0 @ PRQ 50 baseline.
	 */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|PRQ")
	float ReactionTimeScale = 1.f;
};

namespace FELPRQInfluence
{
	/** Facility-grade PRQ → multipliers (tunable curves). */
	FINALEVOLUTIONLAB_API FFELPRQInfluenceMultipliers ComputeMultipliersFromPRQ(float PRQ0to100);
}
