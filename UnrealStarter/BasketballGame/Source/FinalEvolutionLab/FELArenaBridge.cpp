// Copyright (c) Final Evolution Lab.

#include "FELArenaBridge.h"

namespace
{
	FString NormalizeModeId(const FString& Id)
	{
		return Id.TrimStartAndEnd().ToLower();
	}

	double ModeScaleForDisplay(const FString& NormalizedId)
	{
		// Tunable: slightly different curves per mode (parity with Swift PRQ presentation).
		if (NormalizedId == TEXT("basketball_h2h") || NormalizedId == TEXT("basketball_3v3"))
		{
			return 0.85;
		}
		if (NormalizedId == TEXT("basketball_dunk"))
		{
			return 0.90;
		}
		if (NormalizedId == TEXT("karate") || NormalizedId == TEXT("karate_h2h") || NormalizedId == TEXT("karate_endless"))
		{
			return 0.88;
		}
		if (NormalizedId == TEXT("baseball") || NormalizedId == TEXT("football") || NormalizedId == TEXT("soccer"))
		{
			return 0.87;
		}
		if (NormalizedId == TEXT("golf") || NormalizedId == TEXT("tennis") || NormalizedId == TEXT("volleyball"))
		{
			return 0.86;
		}
		if (NormalizedId == TEXT("gymnastics"))
		{
			return 0.89;
		}
		if (NormalizedId == TEXT("brain_brawl"))
		{
			return 0.84;
		}
		if (NormalizedId == TEXT("surfing") || NormalizedId == TEXT("skateboarding") || NormalizedId == TEXT("snowboarding"))
		{
			return 0.88;
		}
		if (NormalizedId == TEXT("market_browse"))
		{
			return 0.82;
		}
		return 0.85;
	}
}

FString FELArenaBridge::AttributeLabelForGameModeId(const FString& Id)
{
	const FString N = NormalizeModeId(Id);

	if (N == TEXT("basketball_h2h"))
	{
		return TEXT("Court IQ");
	}
	if (N == TEXT("basketball_3v3"))
	{
		return TEXT("Spacing IQ");
	}
	if (N == TEXT("basketball_dunk"))
	{
		return TEXT("Hang Time");
	}
	if (N == TEXT("karate"))
	{
		return TEXT("Discipline");
	}
	if (N == TEXT("karate_h2h"))
	{
		return TEXT("Strike Tempo");
	}
	if (N == TEXT("karate_endless"))
	{
		return TEXT("Endurance");
	}
	if (N == TEXT("baseball"))
	{
		return TEXT("Barrel Control");
	}
	if (N == TEXT("football"))
	{
		return TEXT("Field Vision");
	}
	if (N == TEXT("soccer"))
	{
		return TEXT("First Touch");
	}
	if (N == TEXT("golf"))
	{
		return TEXT("Tempo");
	}
	if (N == TEXT("tennis"))
	{
		return TEXT("Court Coverage");
	}
	if (N == TEXT("volleyball"))
	{
		return TEXT("Read & React");
	}
	if (N == TEXT("gymnastics"))
	{
		return TEXT("Body Line");
	}
	if (N == TEXT("brain_brawl"))
	{
		return TEXT("Cognitive Load");
	}
	if (N == TEXT("surfing"))
	{
		return TEXT("Line IQ");
	}
	if (N == TEXT("skateboarding"))
	{
		return TEXT("Edge Grip");
	}
	if (N == TEXT("snowboarding"))
	{
		return TEXT("Carve Control");
	}
	if (N == TEXT("market_browse"))
	{
		return TEXT("Fit & Presence");
	}
	return TEXT("Arena");
}

double FELArenaBridge::AttributeDisplay01To100(double PRQ, const FString& GameModeId)
{
	const double Safe = FMath::IsFinite(PRQ) ? PRQ : 75.0;
	const double N = FMath::Clamp(Safe / 100.0, 0.0, 1.0);
	const double ModeScale = ModeScaleForDisplay(NormalizeModeId(GameModeId));
	return FMath::RoundToDouble(ModeScale * N * 100.0) / 100.0;
}

double FELArenaBridge::ModeWeightForGameModeId(const FString& Id)
{
	const FString N = NormalizeModeId(Id);

	if (N == TEXT("basketball_h2h"))
	{
		return 1.2;
	}
	if (N == TEXT("basketball_dunk"))
	{
		return 1.0;
	}
	if (N == TEXT("basketball_3v3"))
	{
		return 1.3;
	}
	if (N == TEXT("karate") || N == TEXT("karate_h2h"))
	{
		return 1.1;
	}
	if (N == TEXT("karate_endless"))
	{
		return 0.95;
	}
	if (N == TEXT("baseball") || N == TEXT("football") || N == TEXT("soccer"))
	{
		return 1.05;
	}
	if (N == TEXT("golf") || N == TEXT("tennis") || N == TEXT("volleyball"))
	{
		return 1.0;
	}
	if (N == TEXT("gymnastics"))
	{
		return 1.0;
	}
	if (N == TEXT("brain_brawl"))
	{
		return 0.9;
	}
	if (N == TEXT("surfing") || N == TEXT("skateboarding") || N == TEXT("snowboarding"))
	{
		return 1.0;
	}
	if (N == TEXT("market_browse"))
	{
		return 0.85;
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
