// Copyright (c) Final Evolution Lab.

#include "FELPRQInfluence.h"
#include "Math/UnrealMathUtility.h"

FFELPRQInfluenceMultipliers FELPRQInfluence::ComputeMultipliersFromPRQ(float PRQ0to100)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	FFELPRQInfluenceMultipliers M;
	// Phase 2 — Neural Drive: PRQ is the facility layer on CharacterMovement (JumpZ / MaxWalkSpeed).
	// @ PRQ 50 → 1.0; low PRQ softens; high PRQ extends range so readiness is felt in-engine.
	M.JumpHeightMultiplier = FMath::Lerp(0.88f, 1.12f, P);
	M.SprintSpeedMultiplier = FMath::Lerp(0.90f, 1.10f, P);
	// High PRQ → faster reactions (scale < 1).
	M.ReactionTimeScale = FMath::Lerp(1.08f, 0.88f, P);
	return M;
}
