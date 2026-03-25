// Copyright (c) Final Evolution Lab.

#include "FELKineticLeakage.h"
#include "FELArenaModeDefinitions.h"

namespace
{
	float GetLateralStrainThresholdForMode(const EFELArenaMode Mode, const FFELSportNeuroConstants& C)
	{
		switch (Mode)
		{
		case EFELArenaMode::Tennis:
			return C.TennisLateralStrainThreshold;
		case EFELArenaMode::Soccer:
			return C.SoccerLateralStrainThreshold;
		case EFELArenaMode::Football:
			return C.FootballLateralStrainThreshold;
		default:
			return 1.f;
		}
	}
}

float FELKineticLeakage::ApplyLateralCutWalkMultiplier(
	const float NeuralDrive0to100,
	const float KineticLeakageMultiplier,
	const float LateralStrain01,
	const EFELArenaMode Mode,
	const FFELSportNeuroConstants& Sport)
{
	if (Mode != EFELArenaMode::Tennis && Mode != EFELArenaMode::Soccer && Mode != EFELArenaMode::Football)
	{
		return 1.f;
	}
	const float Thresh = GetLateralStrainThresholdForMode(Mode, Sport);
	if (LateralStrain01 < Thresh)
	{
		return 1.f;
	}
	if (NeuralDrive0to100 >= Sport.LateralNeuralDriveRequired)
	{
		return 1.f;
	}
	const float Leak = FMath::Clamp(KineticLeakageMultiplier, 0.45f, 1.f);
	const float Penalty = FMath::Lerp(Sport.LateralWalkPenaltyMin, 1.f, NeuralDrive0to100 / 100.f);
	return FMath::Clamp(Penalty * Leak, 0.45f, 1.f);
}

float FELKineticLeakage::ComputeBondsBounceTimingLeakage(float SecondsInApproachRun, EFELJumpTimingBand& OutBand)
{
	OutBand = EFELJumpTimingBand::None;
	const float T = FMath::Max(0.f, SecondsInApproachRun);
	// Ideal gather commit (~180–320 ms sprint into jump); sigma defines tolerance.
	static constexpr float IdealSec = 0.28f;
	static constexpr float SigmaSec = 0.15f;
	const float X = (T - IdealSec) / FMath::Max(1e-3f, SigmaSec);
	const float G = FMath::Exp(-0.5f * X * X);
	// Realized fraction: floor 0.48 at worst timing, 1.0 at ideal.
	const float Leak = FMath::Lerp(0.48f, 1.f, G);

	if (G >= 0.88f)
	{
		OutBand = EFELJumpTimingBand::Perfect;
	}
	else if (G >= 0.48f)
	{
		OutBand = EFELJumpTimingBand::Good;
	}
	else
	{
		OutBand = (T < IdealSec) ? EFELJumpTimingBand::Early : EFELJumpTimingBand::Late;
	}
	return FMath::Clamp(Leak, 0.45f, 1.f);
}

float FELKineticLeakage::ApplyNeuroMechanicJump(float BaseJumpZ, const FFELReadinessSnapshot& Snap)
{
	const float Leak = FMath::Clamp(static_cast<float>(Snap.KineticLeakageMultiplier), 0.55f, 1.f);
	const float Hang = FMath::Clamp(static_cast<float>(Snap.HangTimeScale), 0.75f, 1.15f);
	return BaseJumpZ * Leak * Hang;
}

float FELKineticLeakage::ApplyNeuroMechanicWalkSpeed(float BaseSpeed, const FFELReadinessSnapshot& Snap)
{
	const float Leak = FMath::Clamp(static_cast<float>(Snap.KineticLeakageMultiplier), 0.55f, 1.f);
	return BaseSpeed * FMath::Lerp(0.92f, 1.f, Leak);
}
