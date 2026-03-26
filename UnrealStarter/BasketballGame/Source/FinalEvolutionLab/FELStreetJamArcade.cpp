// Copyright (c) Final Evolution Lab.

#include "FELStreetJamArcade.h"
#include "Math/UnrealMathUtility.h"

void FELStreetJamArcade::ApplyGatherBand(
	FFELStreetJamArcadeRuntime& R,
	const EFELJumpTimingBand Band,
	const float PRQ0to100,
	const float CreatorStyleComposite,
	const FFELSportNeuroConstants& N)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float P01 = PRQ * 0.01f;
	const float Card = FMath::Clamp(CreatorStyleComposite, 0.75f, 1.45f);
	const float PrqFill = 1.f + P01 * N.StreetJamPRQTrickFillBonus;

	switch (Band)
	{
	case EFELJumpTimingBand::Perfect:
		R.GatherChainCount = FMath::Min(R.GatherChainCount + 1, 99);
		R.GatherChainGraceSeconds = FMath::Max(R.GatherChainGraceSeconds, N.StreetJamGatherChainGraceSeconds);
		R.TrickMeter = FMath::Clamp(
			R.TrickMeter + N.StreetJamTrickGainGatherPerfect * PrqFill * Card,
			0.f,
			1000.f);
		break;
	case EFELJumpTimingBand::Good:
		R.GatherChainGraceSeconds = FMath::Max(R.GatherChainGraceSeconds, N.StreetJamGatherChainGraceSeconds * 0.82f);
		R.TrickMeter = FMath::Clamp(
			R.TrickMeter + N.StreetJamTrickGainGatherGood * PrqFill * Card,
			0.f,
			1000.f);
		break;
	case EFELJumpTimingBand::Early:
	case EFELJumpTimingBand::Late:
		R.GatherChainCount = FMath::Max(0, R.GatherChainCount - 1);
		R.TrickMeter = FMath::Max(0.f, R.TrickMeter - N.StreetJamTrickLeakPenalty * Card);
		R.GatherChainGraceSeconds = FMath::Min(R.GatherChainGraceSeconds, N.StreetJamGatherChainGraceSeconds * 0.3f);
		break;
	default:
		break;
	}
	R.ScoreMultiplier = ComputeScoreMultiplier(R, PRQ0to100, N);
}

void FELStreetJamArcade::TickRuntime(
	FFELStreetJamArcadeRuntime& R,
	const float DeltaSeconds,
	const float PRQ0to100,
	const FFELSportNeuroConstants& N)
{
	R.GatherChainGraceSeconds = FMath::Max(0.f, R.GatherChainGraceSeconds - DeltaSeconds);
	if (R.GatherChainGraceSeconds <= KINDA_SMALL_NUMBER)
	{
		R.GatherChainCount = 0;
	}
	R.BucketChainGraceSeconds = FMath::Max(0.f, R.BucketChainGraceSeconds - DeltaSeconds);
	if (R.BucketChainGraceSeconds <= KINDA_SMALL_NUMBER)
	{
		R.BucketComboCount = 0;
	}

	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float Decay = N.StreetJamTrickDecayPerSecond
		* FMath::Lerp(1.1f, 0.9f, PRQ * 0.01f);
	R.TrickMeter = FMath::Max(0.f, R.TrickMeter - Decay * DeltaSeconds);
	R.ScoreMultiplier = ComputeScoreMultiplier(R, PRQ0to100, N);
}

int32 FELStreetJamArcade::OnBucketScored(
	FFELStreetJamArcadeRuntime& R,
	const float PRQ0to100,
	const float CreatorStyleComposite,
	const FFELSportNeuroConstants& N)
{
	int32 Bonus = 0;
	if (R.bGamebreakerBanked)
	{
		Bonus = FMath::Max(0, FMath::RoundToInt(N.StreetJamGamebreakerBonusPoints));
		R.bGamebreakerBanked = false;
	}

	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float P01 = PRQ * 0.01f;
	const float Card = FMath::Clamp(CreatorStyleComposite, 0.75f, 1.45f);
	const float PrqFill = 1.f + P01 * N.StreetJamPRQTrickFillBonus;

	R.TrickMeter = FMath::Clamp(
		R.TrickMeter + N.StreetJamTrickGainOnBucket * PrqFill * Card,
		0.f,
		1000.f);

	while (R.TrickMeter >= 100.f)
	{
		R.TrickMeter -= 100.f;
		R.bGamebreakerBanked = true;
	}

	R.BucketComboCount = FMath::Min(R.BucketComboCount + 1, 99);
	R.BucketChainGraceSeconds = FMath::Max(R.BucketChainGraceSeconds, N.StreetJamBucketChainGraceSeconds);
	R.ScoreMultiplier = ComputeScoreMultiplier(R, PRQ0to100, N);
	return Bonus;
}

float FELStreetJamArcade::ComputeScoreMultiplier(
	const FFELStreetJamArcadeRuntime& R,
	const float PRQ0to100,
	const FFELSportNeuroConstants& N)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float Cap = FMath::Clamp(
		N.StreetJamMultiplierCapBase + PRQ * N.StreetJamMultiplierCapPerPRQPoint,
		1.35f,
		5.25f);
	const float Trick01 = FMath::Clamp(R.TrickMeter * 0.01f, 0.f, 1.f);
	float M = 1.f + Trick01 * (Cap - 1.f) * 0.8f;
	const float ComboFromBuckets = 1.f + 0.045f * static_cast<float>(FMath::Min(R.BucketComboCount, 16));
	const float ComboFromGather = 1.f + 0.03f * static_cast<float>(FMath::Min(R.GatherChainCount, 12));
	M *= ComboFromBuckets * ComboFromGather;
	return FMath::Clamp(M, 1.f, Cap);
}
