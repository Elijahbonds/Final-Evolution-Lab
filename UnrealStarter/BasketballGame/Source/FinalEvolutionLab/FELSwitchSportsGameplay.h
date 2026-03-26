// Copyright (c) Final Evolution Lab.
// Tennis / Volleyball — Switch Sports–style forgiving timing; PRQ widens windows, Creator Card scales timing + court speed.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELReadinessTypes.h"

class UFELCreatorCard;

namespace FELSwitchSportsGameplay
{
	/** ~1.0 at Creator composite 0.75, ~Creator cap at 1.42. */
	FINALEVOLUTIONLAB_API float CreatorTimingBlend(float CreatorStyleComposite, const FFELSportNeuroConstants& N);

	FINALEVOLUTIONLAB_API float TennisSwitchAceConeHalfAngleDeg(
		float PRQ0to100,
		float CreatorStyleComposite,
		const FFELSportNeuroConstants& N);

	FINALEVOLUTIONLAB_API float VolleyballSwitchSpikeMarginMs(
		float PRQ0to100,
		float CreatorStyleComposite,
		const FFELSportNeuroConstants& N);

	/** Multiplier for MaxWalkSpeed on tennis/volleyball (1.0 = no change). */
	FINALEVOLUTIONLAB_API float ComputeCourtWalkSpeedMultiplier(
		const FFELReadinessSnapshot& Snap,
		const FFELSportNeuroConstants& N,
		UFELCreatorCard* ActiveCard = nullptr);
}
