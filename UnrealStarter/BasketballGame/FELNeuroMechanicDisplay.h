// Copyright (c) Final Evolution Lab.
// Shared display math: matches AFELBasketballCharacter::ApplyReadiness + FELKineticLeakage (NEURO_MECHANIC_BRIDGE.md).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"
#include "FELKineticLeakage.h"
#include "FELNeuroMechanicPhysics.h"
#include "FELNeuroSkill.h"
#include "FELReadinessTypes.h"

namespace FELNeuroMechanicDisplay
{
	/** Effective JumpZVelocity / MaxWalkSpeed after neuro clamps (uu/s and cm/s per character movement). */
	inline void ComputeEffectiveJumpAndWalk(const FFELReadinessSnapshot& S, float& OutJumpZ, float& OutWalkSpeed)
	{
		const float V = FMath::Clamp(static_cast<float>(S.VerticalPotential), 0.f, 100.f);
		const float VIn = FMath::Clamp(static_cast<float>(S.VerticalEstimateInches), 0.f, 72.f);
		const float N = FMath::Clamp(static_cast<float>(S.NeuralDrive), 0.f, 100.f);
		const float P = FMath::Clamp(static_cast<float>(S.PRQScore), 0.f, 100.f);
		const float Eff = FMath::Clamp(static_cast<float>(S.EfficiencyScore), 0.f, 100.f);
		const float Potential = FELNeuroMechanicPhysics::PotentialJumpZFromVerticalInches(VIn);
		const float Drive = FELNeuroMechanicPhysics::NeuralDriveRealizationFactor(N);
		const float EffScale = FELNeuroMechanicPhysics::EfficiencyHeightScale(Eff);
		const float Train = FELNeuroMechanicPhysics::VerticalTrainingBonus(V);
		const float BaseJump = Potential * Drive * EffScale + P * 0.14f + Train;
		OutJumpZ = FELKineticLeakage::ApplyNeuroMechanicJump(BaseJump, S);
		const float BaseSpeed = 380.f + N * 1.8f + P * 0.25f;
		OutWalkSpeed = FELKineticLeakage::ApplyNeuroMechanicWalkSpeed(BaseSpeed, S);
	}

	/** Third HUD line: sport-specific label/value (Kick Power, Swing Speed, Perfect Window ms, etc.). */
	inline void GetSportHudMetric3(const FFELReadinessSnapshot& S, const FFELArenaRules& R, FString& OutLabel, FString& OutValue)
	{
		float Jz = 0.f;
		float Ws = 0.f;
		ComputeEffectiveJumpAndWalk(S, Jz, Ws);
		(void)Jz;
		const EFELArenaMode Mode = FELArenaModeFromSwiftId(S.ActiveArenaMode);
		const FFELSportNeuroConstants& N = R.SportNeuro;

		switch (Mode)
		{
		case EFELArenaMode::Soccer:
			OutLabel = TEXT("Kick Power");
			OutValue = FString::Printf(TEXT("%.0f uu/s (x%.2f)"), Ws * N.SoccerKickPower, N.SoccerKickPower);
			break;
		case EFELArenaMode::Baseball:
			OutLabel = TEXT("Perfect Window (ms)");
			OutValue = FString::Printf(TEXT("%.0f"), FELNeuroSkill::PerfectHitWindowMsFromPRQ(Mode, static_cast<float>(S.PRQScore), N));
			break;
		case EFELArenaMode::Golf:
			OutLabel = TEXT("Slice Control");
			OutValue = FString::Printf(TEXT("x%.2f"), N.GolfSliceMultiplier);
			break;
		case EFELArenaMode::Tennis:
			OutLabel = TEXT("Lateral Cut");
			OutValue = FString::Printf(TEXT("ND ≥%.0f vs cut"), N.LateralNeuralDriveRequired);
			break;
		case EFELArenaMode::Football:
			OutLabel = TEXT("Cut Stability");
			OutValue = FString::Printf(TEXT("thresh %.0f%%"), N.FootballLateralStrainThreshold * 100.f);
			break;
		case EFELArenaMode::Karate:
			OutLabel = TEXT("Perfect Window (ms)");
			OutValue = FString::Printf(TEXT("%.0f"), FELNeuroSkill::PerfectHitWindowMsFromPRQ(Mode, static_cast<float>(S.PRQScore), N));
			break;
		case EFELArenaMode::Volleyball:
			OutLabel = TEXT("Reaction (ms)");
			OutValue = FString::Printf(TEXT("%.0f"), N.VolleyballReactionWindowMs);
			break;
		case EFELArenaMode::Gymnastics:
			OutLabel = TEXT("Tempo");
			OutValue = FString::Printf(TEXT("x%.2f"), N.GymnasticsTempoScale);
			break;
		case EFELArenaMode::BrainBrawl:
			OutLabel = TEXT("Cognition");
			OutValue = FString::Printf(TEXT("x%.2f"), N.BrainBrawlCognitionWeight);
			break;
		case EFELArenaMode::BasketballHeadToHead:
		case EFELArenaMode::Basketball3v3:
			OutLabel = TEXT("Neural Drive");
			OutValue = FString::Printf(TEXT("%.0f (x%.2f)"), S.NeuralDrive, N.BasketballDriveExplosionScale);
			break;
		case EFELArenaMode::BasketballDunkContest:
			OutLabel = TEXT("Explosion");
			OutValue = FString::Printf(TEXT("x%.2f"), N.BasketballDriveExplosionScale);
			break;
		default:
			OutLabel = TEXT("Walk Speed");
			OutValue = FString::Printf(TEXT("%.0f"), Ws);
			break;
		}
	}
}
