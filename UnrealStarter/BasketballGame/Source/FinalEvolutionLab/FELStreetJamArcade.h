// Copyright (c) Final Evolution Lab.
// Head-to-head / 3v3 — sim-first movement with NBA Street Vol 2–style trick meter, bucket combos, and gamebreaker bonus buckets.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELJumpTimingTypes.h"

struct FFELStreetJamArcadeRuntime
{
	float TrickMeter = 0.f;
	int32 GatherChainCount = 0;
	float GatherChainGraceSeconds = 0.f;
	int32 BucketComboCount = 0;
	float BucketChainGraceSeconds = 0.f;
	bool bGamebreakerBanked = false;
	float ScoreMultiplier = 1.f;
};

namespace FELStreetJamArcade
{
	FINALEVOLUTIONLAB_API void ApplyGatherBand(
		FFELStreetJamArcadeRuntime& R,
		EFELJumpTimingBand Band,
		float PRQ0to100,
		float CreatorStyleComposite,
		const FFELSportNeuroConstants& N);

	FINALEVOLUTIONLAB_API void TickRuntime(FFELStreetJamArcadeRuntime& R, float DeltaSeconds, float PRQ0to100, const FFELSportNeuroConstants& N);

	/** After a made bucket: builds trick, combo, may bank breaker; returns flat bonus points if a banked breaker pays out. */
	FINALEVOLUTIONLAB_API int32 OnBucketScored(
		FFELStreetJamArcadeRuntime& R,
		float PRQ0to100,
		float CreatorStyleComposite,
		const FFELSportNeuroConstants& N);

	FINALEVOLUTIONLAB_API float ComputeScoreMultiplier(const FFELStreetJamArcadeRuntime& R, float PRQ0to100, const FFELSportNeuroConstants& N);
}
