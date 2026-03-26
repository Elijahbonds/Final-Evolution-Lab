// Copyright (c) Final Evolution Lab.

#include "FELDunkContestArcade.h"
#include "Math/UnrealMathUtility.h"

void FELDunkContestArcade::ApplyApproachBand(
	FFELDunkContestArcadeRuntime& R,
	const EFELJumpTimingBand Band,
	const float PRQ0to100,
	const float CreatorStyleComposite,
	const FFELSportNeuroConstants& N)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float P01 = PRQ * 0.01f;
	const float Card = FMath::Clamp(CreatorStyleComposite, 0.75f, 1.45f);
	const float PrqFill = 1.f + P01 * N.DunkContestPRQStyleFillBonus;

	switch (Band)
	{
	case EFELJumpTimingBand::Perfect:
		R.ChainCount = FMath::Min(R.ChainCount + 1, 99);
		R.ChainGraceSeconds = FMath::Max(R.ChainGraceSeconds, N.DunkContestChainGraceSeconds);
		R.StyleMeter = FMath::Clamp(
			R.StyleMeter + N.DunkContestStyleGainPerfect * PrqFill * Card,
			0.f,
			100.f);
		break;
	case EFELJumpTimingBand::Good:
		R.ChainGraceSeconds = FMath::Max(R.ChainGraceSeconds, N.DunkContestChainGraceSeconds * 0.85f);
		R.StyleMeter = FMath::Clamp(
			R.StyleMeter + N.DunkContestStyleGainGood * PrqFill * Card,
			0.f,
			100.f);
		break;
	case EFELJumpTimingBand::Early:
	case EFELJumpTimingBand::Late:
		R.ChainCount = FMath::Max(0, R.ChainCount - 1);
		R.StyleMeter = FMath::Max(0.f, R.StyleMeter - N.DunkContestStyleLeakPenalty * Card);
		R.ChainGraceSeconds = FMath::Min(R.ChainGraceSeconds, N.DunkContestChainGraceSeconds * 0.35f);
		break;
	default:
		break;
	}
	R.ScoreMultiplier = ComputeScoreMultiplier(R, PRQ0to100, N);
}

void FELDunkContestArcade::TickRuntime(
	FFELDunkContestArcadeRuntime& R,
	const float DeltaSeconds,
	const float PRQ0to100,
	const FFELSportNeuroConstants& N)
{
	R.ChainGraceSeconds = FMath::Max(0.f, R.ChainGraceSeconds - DeltaSeconds);
	if (R.ChainGraceSeconds <= KINDA_SMALL_NUMBER)
	{
		R.ChainCount = 0;
	}
	const float Decay = N.DunkContestStyleDecayPerSecond * FMath::Lerp(1.12f, 0.88f, FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f);
	R.StyleMeter = FMath::Max(0.f, R.StyleMeter - Decay * DeltaSeconds);
	R.ScoreMultiplier = ComputeScoreMultiplier(R, PRQ0to100, N);
}

float FELDunkContestArcade::ComputeScoreMultiplier(
	const FFELDunkContestArcadeRuntime& R,
	const float PRQ0to100,
	const FFELSportNeuroConstants& N)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float Cap = FMath::Clamp(
		N.DunkContestMultiplierCapBase + PRQ * N.DunkContestMultiplierCapPerPRQPoint,
		1.5f,
		6.5f);
	const float Style01 = FMath::Clamp(R.StyleMeter / 100.f, 0.f, 1.f);
	float M = 1.f + Style01 * (Cap - 1.f) * 0.82f;
	const float ChainBonus = 1.f + 0.065f * static_cast<float>(FMath::Min(R.ChainCount, 14));
	M *= ChainBonus;
	return FMath::Clamp(M, 1.f, Cap);
}
