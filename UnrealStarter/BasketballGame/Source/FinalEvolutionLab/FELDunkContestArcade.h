// Copyright (c) Final Evolution Lab.
// Dunk Contest — THPS-style style meter + chain grace; NBA Live-style “in the zone” fill from PRQ; buckets scale with multiplier.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELJumpTimingTypes.h"

struct FFELDunkContestArcadeRuntime
{
	float StyleMeter = 0.f;
	float ChainGraceSeconds = 0.f;
	int32 ChainCount = 0;
	float ScoreMultiplier = 1.f;
};

namespace FELDunkContestArcade
{
	/** Perfect / Good / leaky approach — updates meter, chain, grace (Creator composite from card asset or stood id hash). */
	FINALEVOLUTIONLAB_API void ApplyApproachBand(
		FFELDunkContestArcadeRuntime& R,
		EFELJumpTimingBand Band,
		float PRQ0to100,
		float CreatorStyleComposite,
		const FFELSportNeuroConstants& N);

	FINALEVOLUTIONLAB_API void TickRuntime(FFELDunkContestArcadeRuntime& R, float DeltaSeconds, float PRQ0to100, const FFELSportNeuroConstants& N);

	FINALEVOLUTIONLAB_API float ComputeScoreMultiplier(const FFELDunkContestArcadeRuntime& R, float PRQ0to100, const FFELSportNeuroConstants& N);
}
