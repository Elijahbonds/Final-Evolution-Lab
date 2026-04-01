// Copyright (c) Final Evolution Lab.
// Mode-specific "Mastery Score" for session_results.json / Swift Vault (NEURO_MECHANIC_BRIDGE).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELReadinessTypes.h"

namespace FELSportMastery
{
	/** Computes 0–100 mastery and a stable metric id (e.g. accuracy, impact) for Swift `masteryMetric`. */
	inline void ComputeMasteryScoreAndMetric(const FString& ModeIdString, const FFELReadinessSnapshot& Snap, const int32 Score, double& OutMastery, FString& OutMetricId)
	{
		const EFELArenaMode M = FELArenaModeFromIdString(ModeIdString);
		OutMastery = 0.0;
		OutMetricId = TEXT("composite");

		switch (M)
		{
		case EFELArenaMode::Golf:
			OutMetricId = TEXT("accuracy");
			OutMastery = FMath::Clamp(Snap.EfficiencyScore * 0.55 + Snap.PRQScore * 0.45, 0.0, 100.0);
			break;
		case EFELArenaMode::Karate:
			OutMetricId = TEXT("impact");
			OutMastery = FMath::Clamp(Snap.PopForce * 0.5 + Snap.PRQScore * 0.5, 0.0, 100.0);
			break;
		case EFELArenaMode::Baseball:
			OutMetricId = TEXT("timing");
			OutMastery = FMath::Clamp(Snap.PRQScore * 0.65 + Snap.EfficiencyScore * 0.35, 0.0, 100.0);
			break;
		case EFELArenaMode::Soccer:
			OutMetricId = TEXT("placement");
			OutMastery = FMath::Clamp(Snap.NeuralDrive * 0.55 + Snap.PRQScore * 0.45, 0.0, 100.0);
			break;
		case EFELArenaMode::Football:
			OutMetricId = TEXT("burst");
			OutMastery = FMath::Clamp(Snap.PopForce * 0.45 + Snap.NeuralDrive * 0.55, 0.0, 100.0);
			break;
		case EFELArenaMode::Tennis:
		case EFELArenaMode::Volleyball:
			OutMetricId = TEXT("rally");
			OutMastery = FMath::Clamp(Snap.EfficiencyScore * 0.5 + Snap.PRQScore * 0.5, 0.0, 100.0);
			break;
		case EFELArenaMode::Gymnastics:
			OutMetricId = TEXT("tempo");
			OutMastery = FMath::Clamp(Snap.EfficiencyScore * 0.6 + Snap.ReadinessScore * 0.4, 0.0, 100.0);
			break;
		case EFELArenaMode::BrainBrawl:
			OutMetricId = TEXT("cognition");
			OutMastery = FMath::Clamp(Snap.PRQScore * 0.65 + Snap.EfficiencyScore * 0.35, 0.0, 100.0);
			break;
		case EFELArenaMode::BasketballHeadToHead:
		case EFELArenaMode::Basketball3v3:
			OutMetricId = TEXT("drive");
			OutMastery = FMath::Clamp(Snap.NeuralDrive * 0.5 + Snap.PRQScore * 0.5, 0.0, 100.0);
			break;
		case EFELArenaMode::BasketballDunkContest:
			OutMetricId = TEXT("vert_potential");
			OutMastery = FMath::Clamp(Snap.VerticalPotential * 0.5 + Snap.NeuralDrive * 0.5, 0.0, 100.0);
			break;
		default:
			OutMetricId = TEXT("composite");
			OutMastery = FMath::Clamp(Snap.PRQScore * 0.6 + static_cast<double>(Score) * 2.5, 0.0, 100.0);
			break;
		}
	}
}
