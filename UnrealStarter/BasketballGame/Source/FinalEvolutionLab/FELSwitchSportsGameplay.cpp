// Copyright (c) Final Evolution Lab.

#include "FELSwitchSportsGameplay.h"
#include "FELDojoNeuralTempest.h"
#include "FELTwelvePillarArenaGameplay.h"
#include "UFELCreatorCard.h"
#include "Math/UnrealMathUtility.h"

float FELSwitchSportsGameplay::CreatorTimingBlend(const float CreatorStyleComposite, const FFELSportNeuroConstants& N)
{
	const float C = FMath::Clamp(CreatorStyleComposite, 0.75f, 1.42f);
	const float T = FMath::Clamp((C - 0.75f) / (1.42f - 0.75f + KINDA_SMALL_NUMBER), 0.f, 1.f);
	return FMath::Lerp(N.SwitchCreatorTimingMin, N.SwitchCreatorTimingMax, T);
}

float FELSwitchSportsGameplay::TennisSwitchAceConeHalfAngleDeg(
	const float PRQ0to100,
	const float CreatorStyleComposite,
	const FFELSportNeuroConstants& N)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float Base = FELTwelvePillarArenaGameplay::TennisServeAceConeHalfAngleDeg(PRQ);
	const float Blend = CreatorTimingBlend(CreatorStyleComposite, N);
	return (Base + N.SwitchTennisExtraConeDeg + PRQ * N.SwitchTennisConeBonusPerPRQDeg) * Blend;
}

float FELSwitchSportsGameplay::VolleyballSwitchSpikeMarginMs(
	const float PRQ0to100,
	const float CreatorStyleComposite,
	const FFELSportNeuroConstants& N)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float Base = FELTwelvePillarArenaGameplay::VolleyballSpikeTimingMarginMs(PRQ);
	const float Blend = CreatorTimingBlend(CreatorStyleComposite, N);
	return (Base + N.SwitchVolleyballExtraSpikeMarginMs + PRQ * N.SwitchVolleyballSpikeMarginPerPRQMs) * Blend;
}

float FELSwitchSportsGameplay::ComputeCourtWalkSpeedMultiplier(
	const FFELReadinessSnapshot& Snap,
	const FFELSportNeuroConstants& N,
	UFELCreatorCard* ActiveCard)
{
	const float P01 = FMath::Clamp(static_cast<float>(Snap.PRQScore), 0.f, 100.f) * 0.01f;
	float CE = 1.f;
	float CS = 1.f;
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, ActiveCard, CE, CS);
	const float Creator = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
	const float Blend = CreatorTimingBlend(Creator, N);
	return 1.f + N.SwitchCourtWalkBonusMax * P01 * FMath::Clamp(Blend, 0.85f, 1.18f);
}
