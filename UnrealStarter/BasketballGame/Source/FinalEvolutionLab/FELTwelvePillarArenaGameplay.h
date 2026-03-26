// Copyright (c) Final Evolution Lab.
// Remaining arena pillars — deterministic gameplay formulas (PRQ-influenced). Wire from AFELLabGameMode tick / mode actors.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"

namespace FELTwelvePillarArenaGameplay
{
	/** Soccer — curve carry multiplier for driven shots (PRQ steadies lateral hook). */
	FINALEVOLUTIONLAB_API float SoccerShotCurveStabilityFromPRQ(float PRQ0to100, float LateralInput01);

	/** Baseball — recognition window ms (pairs with FELNeuroSkill baseball path). */
	FINALEVOLUTIONLAB_API float BaseballPitchRecognitionWindowMs(float PRQ0to100);

	/** Brain Brawl — lockout after wrong answer shrinks with high PRQ. */
	FINALEVOLUTIONLAB_API float BrainBrawlWrongAnswerLockoutSec(float PRQ0to100, float BaseLockoutSec);

	/** Golf — downswing plane stability 0–1. */
	FINALEVOLUTIONLAB_API float GolfSwingPlaneStability(float PRQ0to100, float KineticLeakageMultiplier);

	/** Tennis — serve ace half-angle degrees (wider cone at high PRQ). */
	FINALEVOLUTIONLAB_API float TennisServeAceConeHalfAngleDeg(float PRQ0to100);

	/** Volleyball — spike timing margin ms. */
	FINALEVOLUTIONLAB_API float VolleyballSpikeTimingMarginMs(float PRQ0to100);

	/** Gymnastics — stamina drain scaler (lower drain when PRQ high). */
	FINALEVOLUTIONLAB_API float GymnasticsStaminaDrainScale(float PRQ0to100);

	/** Market browse — no sim; returns 1.f (keeps switch exhaustive in builds). */
	FINALEVOLUTIONLAB_API float NeutralMultiplierForNonSportMode(EFELArenaMode Mode);
}
