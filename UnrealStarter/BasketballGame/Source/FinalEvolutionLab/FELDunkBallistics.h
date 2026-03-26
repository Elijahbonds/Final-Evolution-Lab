// Copyright (c) Final Evolution Lab.
// Dunk / basketball — ballistic arc sampling and rim torus collision for release QA and AI aim assist.

#pragma once

#include "CoreMinimal.h"

namespace FELDunkBallistics
{
	/**
	 * Integrate constant gravity; each step tests segment vs rim circle (XY) and Z band.
	 * @param RimPlaneZ Band center (hoop height).
	 * @param RimRadiusXY Outer radius of rim collision in XY.
	 * @param RimHalfThicknessZ Half thickness in Z for a thin torus slab.
	 */
	FINALEVOLUTIONLAB_API bool SampleArcUntilRimContact(
		const FVector& StartWorld,
		const FVector& StartVelocityCmPerSec,
		float GravityZCmPerSec2,
		const FVector& RimCenterWorld,
		float RimPlaneZ,
		float RimRadiusXY,
		float RimHalfThicknessZ,
		float BallRadiusUU,
		float DeltaT,
		int32 MaxSteps,
		float& OutTimeSec,
		FVector& OutContactLocation,
		FVector& OutVelocityAtContact);
}
