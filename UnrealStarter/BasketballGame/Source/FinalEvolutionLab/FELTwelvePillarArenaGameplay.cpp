// Copyright (c) Final Evolution Lab.

#include "FELTwelvePillarArenaGameplay.h"
#include "Math/UnrealMathUtility.h"

float FELTwelvePillarArenaGameplay::SoccerShotCurveStabilityFromPRQ(const float PRQ0to100, const float LateralInput01)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	const float L = FMath::Clamp(LateralInput01, 0.f, 1.f);
	return FMath::Lerp(0.65f, 1.f, P) * FMath::Lerp(1.f, 0.82f, L);
}

float FELTwelvePillarArenaGameplay::BaseballPitchRecognitionWindowMs(const float PRQ0to100)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	return FMath::Lerp(95.f, 165.f, P);
}

float FELTwelvePillarArenaGameplay::BrainBrawlWrongAnswerLockoutSec(const float PRQ0to100, const float BaseLockoutSec)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	return FMath::Max(0.15f, BaseLockoutSec * FMath::Lerp(1.2f, 0.55f, P));
}

float FELTwelvePillarArenaGameplay::GolfSwingPlaneStability(const float PRQ0to100, const float KineticLeakageMultiplier)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	const float K = FMath::Clamp(KineticLeakageMultiplier, 0.45f, 1.f);
	return FMath::Clamp(FMath::Lerp(0.5f, 1.f, P) * K, 0.2f, 1.f);
}

float FELTwelvePillarArenaGameplay::TennisServeAceConeHalfAngleDeg(const float PRQ0to100)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	return FMath::Lerp(2.1f, 4.6f, P);
}

float FELTwelvePillarArenaGameplay::VolleyballSpikeTimingMarginMs(const float PRQ0to100)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	return FMath::Lerp(22.f, 38.f, P);
}

float FELTwelvePillarArenaGameplay::GymnasticsStaminaDrainScale(const float PRQ0to100)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	return FMath::Lerp(1.15f, 0.78f, P);
}

float FELTwelvePillarArenaGameplay::NeutralMultiplierForNonSportMode(const EFELArenaMode Mode)
{
	if (Mode == EFELArenaMode::MarketBrowse || Mode == EFELArenaMode::Unknown)
	{
		return 1.f;
	}
	return 1.f;
}
