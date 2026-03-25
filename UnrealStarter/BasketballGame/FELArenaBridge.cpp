// Copyright (c) Final Evolution Lab.

#include "FELArenaBridge.h"

static double ModeScaleForBasketball(const FString& Id)
{
	if (Id == TEXT("basketball_h2h") || Id == TEXT("basketball_3v3"))
	{
		return 0.85;
	}
	if (Id == TEXT("basketball_dunk"))
	{
		return 0.90;
	}
	return 0.85;
}

FString FELArenaBridge::AttributeLabelForGameModeId(const FString& Id)
{
	if (Id == TEXT("basketball_h2h") || Id == TEXT("basketball_3v3"))
	{
		return TEXT("Court IQ");
	}
	if (Id == TEXT("basketball_dunk"))
	{
		return TEXT("Hang Time");
	}
	return TEXT("Arena");
}

double FELArenaBridge::AttributeDisplay01To100(double PRQ, const FString& GameModeId)
{
	const double Safe = FMath::IsFinite(PRQ) ? PRQ : 75.0;
	const double N = FMath::Clamp(Safe / 100.0, 0.0, 1.0);
	const double ModeScale = ModeScaleForBasketball(GameModeId);
	return FMath::RoundToDouble(ModeScale * N * 100.0) / 100.0;
}

double FELArenaBridge::ModeWeightForGameModeId(const FString& Id)
{
	if (Id == TEXT("basketball_h2h"))
	{
		return 1.2;
	}
	if (Id == TEXT("basketball_dunk"))
	{
		return 1.0;
	}
	if (Id == TEXT("basketball_3v3"))
	{
		return 1.3;
	}
	return 1.0;
}

int32 FELArenaBridge::ComputeShardsEarned(int32 ScoreBuckets, double PRQ, const FString& GameModeId, bool bEconomyEnabled)
{
	if (!bEconomyEnabled)
	{
		return 0;
	}
	const double SafePRQ = FMath::IsFinite(PRQ) ? FMath::Clamp(PRQ, 0.0, 100.0) : 75.0;
	const double W = ModeWeightForGameModeId(GameModeId);
	const double Raw = 5.0 + static_cast<double>(FMath::Max(0, ScoreBuckets)) * 3.0 * W * (SafePRQ / 100.0);
	return FMath::Max(1, FMath::RoundToInt(Raw));
}

double FELArenaBridge::ComputePRQBonus(int32 ScoreBuckets, double PRQ, bool bEconomyEnabled)
{
	if (!bEconomyEnabled)
	{
		return 0.0;
	}
	if (ScoreBuckets <= 0)
	{
		return 0.0;
	}
	const double SafePRQ = FMath::IsFinite(PRQ) ? FMath::Clamp(PRQ, 0.0, 100.0) : 75.0;
	const double Raw = 0.05 * static_cast<double>(ScoreBuckets) * (SafePRQ / 100.0);
	return FMath::Clamp(Raw, 0.1, 5.0);
}
