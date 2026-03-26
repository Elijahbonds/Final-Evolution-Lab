// Copyright (c) Final Evolution Lab.
// Neuro-Mechanic: "Efficiency = Height" — vertical scan sets potential; neural drive + efficiency realize it (see NEURO_MECHANIC_BRIDGE.md).

#pragma once

#include "CoreMinimal.h"

namespace FELNeuroMechanicPhysics
{
	/** Bonds Bounce Blueprint potential cap from scan inches (Swift `verticalEstimateInches`). */
	inline float PotentialJumpZFromVerticalInches(const float Inches)
	{
		const float ClampIn = FMath::Clamp(Inches, 0.f, 72.f);
		return FMath::Lerp(320.f, 760.f, ClampIn / 72.f);
	}

	/** How much of that potential becomes realized impulse (0–100 neural drive). */
	inline float NeuralDriveRealizationFactor(const float NeuralDrive0to100)
	{
		const float N = FMath::Clamp(NeuralDrive0to100, 0.f, 100.f);
		return FMath::Lerp(0.48f, 1.f, N / 100.f);
	}

	/** Efficiency directly scales realized height (training / motor efficiency). */
	inline float EfficiencyHeightScale(const float Efficiency0to100)
	{
		const float E = FMath::Clamp(Efficiency0to100, 0.f, 100.f);
		return FMath::Lerp(0.88f, 1.14f, E / 100.f);
	}

	/** Small additive from long-term vertical training metric (Swift `verticalPotential`). */
	inline float VerticalTrainingBonus(const float VerticalPotential0to100)
	{
		return FMath::Clamp(VerticalPotential0to100, 0.f, 100.f) * 0.28f;
	}
}
