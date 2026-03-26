// Copyright (c) Final Evolution Lab.
// Shared display math: matches ApplyReadiness + leakage + PRQ engine multipliers (NEURO_MECHANIC_BRIDGE.md).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"
#include "FELDojoNeuralTempest.h"
#include "FELKaratePRQBoost.h"
#include "FELKineticLeakage.h"
#include "FELNeuroMechanicPhysics.h"
#include "FELPRQInfluence.h"
#include "FELNeuroSkill.h"
#include "FELReadinessTypes.h"
#include "FELCreatorCardResolver.h"
#include "FELSwitchSportsGameplay.h"

class UFELCreatorCard;

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
		const FFELPRQInfluenceMultipliers PrqEngine = FELPRQInfluence::ComputeMultipliersFromPRQ(P);
		OutJumpZ *= PrqEngine.JumpHeightMultiplier;
		OutWalkSpeed *= PrqEngine.SprintSpeedMultiplier;
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
			OutLabel = TEXT("Shot shaping");
			OutValue = FString::Printf(TEXT("x%.2f"), N.GolfSliceMultiplier);
			break;
		case EFELArenaMode::Tennis:
		{
			float CE = 1.f;
			float CS = 1.f;
			UFELCreatorCard* CreatorCard = FFELCreatorCardResolver::ResolveFromReadiness(S);
			FELDojoNeuralTempest::ResolveCreatorCardComposites(S, CreatorCard, CE, CS);
			const float Style = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
			const float P = FMath::Clamp(static_cast<float>(S.PRQScore), 0.f, 100.f);
			const float Cone = FELSwitchSportsGameplay::TennisSwitchAceConeHalfAngleDeg(P, Style, N);
			OutLabel = TEXT("Tennis · serve window");
			OutValue = FString::Printf(TEXT("ace cone %.1f° · lateral drive ≥%.0f"), Cone, N.LateralNeuralDriveRequired);
			break;
		}
		case EFELArenaMode::Football:
		{
			const float P = FMath::Clamp(static_cast<float>(S.PRQScore), 0.f, 100.f);
			const float P01 = P * 0.01f;
			OutLabel = TEXT("Kick return · readiness");
			OutValue = FString::Printf(
				TEXT("speed +%.0f%% · stamina +%.0f%% · opponent %.0f"),
				P01 * N.KickReturnPRQSpeedCoef * 100.f,
				P01 * N.KickReturnPRQDurabilityCoef * 100.f,
				N.KickReturnGhostOpponentPRQ);
			break;
		}
		case EFELArenaMode::Karate:
		{
			FFELKaratePRQCombatBoost KB;
			FELKaratePRQBoost::ComputeCombatBoost(static_cast<float>(S.PRQScore), KB);
			if (R.KarateLabMode == EFELKarateLabMode::EndlessAgentWaves)
			{
				OutLabel = TEXT("Karate · wave drill");
				OutValue = FString::Printf(
					TEXT("readiness Str×%.2f Spd×%.2f Perf×%.2f"),
					KB.StrengthMultiplier,
					KB.SpeedMultiplier,
					KB.PerformanceMultiplier);
			}
			else
			{
				OutLabel = TEXT("Karate · duel");
				OutValue = FString::Printf(
					TEXT("readiness Str×%.2f Spd×%.2f Perf×%.2f"),
					KB.StrengthMultiplier,
					KB.SpeedMultiplier,
					KB.PerformanceMultiplier);
			}
			break;
		}
		case EFELArenaMode::Volleyball:
		{
			float CE = 1.f;
			float CS = 1.f;
			UFELCreatorCard* CreatorCard = FFELCreatorCardResolver::ResolveFromReadiness(S);
			FELDojoNeuralTempest::ResolveCreatorCardComposites(S, CreatorCard, CE, CS);
			const float Style = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
			const float P = FMath::Clamp(static_cast<float>(S.PRQScore), 0.f, 100.f);
			const float Spike = FELSwitchSportsGameplay::VolleyballSwitchSpikeMarginMs(P, Style, N);
			OutLabel = TEXT("Volleyball · spike window");
			OutValue = FString::Printf(TEXT("spike ±%.0fms · react %.0fms"), Spike, N.VolleyballReactionWindowMs);
			break;
		}
		case EFELArenaMode::Gymnastics:
			OutLabel = TEXT("Tempo");
			OutValue = FString::Printf(TEXT("x%.2f"), N.GymnasticsTempoScale);
			break;
		case EFELArenaMode::BrainBrawl:
			OutLabel = TEXT("Academy quiz");
			OutValue = FString::Printf(TEXT("cognition x%.2f · timed round"), N.BrainBrawlCognitionWeight);
			break;
		case EFELArenaMode::BasketballHeadToHead:
		case EFELArenaMode::Basketball3v3:
			if (R.bStreetJamArcade)
			{
				const float PRQB = FMath::Clamp(static_cast<float>(S.PRQScore), 0.f, 100.f);
				UFELCreatorCard* Cr = FFELCreatorCardResolver::ResolveFromReadiness(S);
				float CE = 1.f;
				float CS = 1.f;
				FELDojoNeuralTempest::ResolveCreatorCardComposites(S, Cr, CE, CS);
				const float Style = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
				const float CapS = FMath::Clamp(
					N.StreetJamMultiplierCapBase + PRQB * N.StreetJamMultiplierCapPerPRQPoint,
					1.35f,
					5.25f);
				OutLabel = TEXT("Street · readiness + card");
				OutValue = FString::Printf(
					TEXT("%.0f · style x%.2f · score cap x%.2f · finisher +%.0f"),
					PRQB,
					Style,
					CapS,
					N.StreetJamGamebreakerBonusPoints);
			}
			else
			{
				OutLabel = TEXT("Drive");
				OutValue = FString::Printf(TEXT("%.0f (x%.2f)"), S.NeuralDrive, N.BasketballDriveExplosionScale);
			}
			break;
		case EFELArenaMode::BasketballDunkContest:
		{
			const float PRQ = FMath::Clamp(static_cast<float>(S.PRQScore), 0.f, 100.f);
			UFELCreatorCard* Cr = FFELCreatorCardResolver::ResolveFromReadiness(S);
			float CE = 1.f;
			float CS = 1.f;
			FELDojoNeuralTempest::ResolveCreatorCardComposites(S, Cr, CE, CS);
			const float Style = FMath::Clamp(FMath::Sqrt(CE * CS), 0.75f, 1.42f);
			const float Cap = FMath::Clamp(
				N.DunkContestMultiplierCapBase + PRQ * N.DunkContestMultiplierCapPerPRQPoint,
				1.5f,
				6.5f);
			OutLabel = TEXT("Dunk · PRQ + Creator Card");
			OutValue = FString::Printf(
				TEXT("PRQ %.0f · style x%.2f · explosion x%.2f · cap x%.2f · decay %.2f/s"),
				PRQ,
				Style,
				N.BasketballDriveExplosionScale,
				Cap,
				N.DunkContestStyleDecayPerSecond);
			break;
		}
		default:
			OutLabel = TEXT("Walk Speed");
			OutValue = FString::Printf(TEXT("%.0f"), Ws);
			break;
		}
	}
}
