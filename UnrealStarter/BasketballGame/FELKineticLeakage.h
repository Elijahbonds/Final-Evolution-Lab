// Copyright (c) Final Evolution Lab.
// Neuro-Mechanic: scan-driven reduction of explosive vertical when joints are MODERATE/LEAKING vs PRIMED.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"
#include "FELJumpTimingTypes.h"
#include "FELReadinessTypes.h"

namespace FELKineticLeakage
{
	/** Applies joint-scan KineticLeakageMultiplier and HangTimeScale to a base jump velocity (cm/s). */
	float ApplyNeuroMechanicJump(float BaseJumpZ, const FFELReadinessSnapshot& Snap);

	/** Optional sprint cap modifier (same leakage curve). */
	float ApplyNeuroMechanicWalkSpeed(float BaseSpeed, const FFELReadinessSnapshot& Snap);

	/**
	 * Dynamic Bonds Bounce timing: maps seconds spent in a fast approach (gather) into [~0.5, 1.0] realized impulse.
	 * Gaussian ideal ~0.28s; early/late tails are "Leaky" bands for animation / feel (not a flat multiplier).
	 */
	float ComputeBondsBounceTimingLeakage(float SecondsInApproachRun, EFELJumpTimingBand& OutBand);

	/**
	 * Lateral kinetic leakage (Tennis / Soccer / Football): hard cuts with low neural drive → speed penalty.
	 * Returns a multiplier in ~[0.5, 1] applied to MaxWalkSpeed on top of scan leakage.
	 */
	float ApplyLateralCutWalkMultiplier(
		float NeuralDrive0to100,
		float KineticLeakageMultiplier,
		float LateralStrain01,
		EFELArenaMode Mode,
		const FFELSportNeuroConstants& Sport);
}
