// Copyright (c) Final Evolution Lab.
// PRQ-driven blend between "Fatigued" and "Primed" animation layers (Vertical Velocity / CNS Freeway syllabus).

#pragma once

#include "CoreMinimal.h"

/** Used by AnimBP Layered blend nodes + `IFELNeuroAnimLayerInterface` implementations. */
namespace FELNeuroAnimLayerBlend
{
	/** 0 = heavy / leaky (low PRQ), 1 = explosive full extension (high PRQ). */
	inline float PrimedLayerAlphaFromPRQ(float PRQ0to100)
	{
		return FMath::Clamp((PRQ0to100 - 42.f) / 53.f, 0.f, 1.f);
	}

	/** Scales hip extension / stride length in "fatigued" layer when kinetic leakage is high. */
	inline float HipExtensionScaleFromLeakage(float KineticLeakageMultiplier01)
	{
		return FMath::Lerp(0.82f, 1.f, FMath::Clamp(KineticLeakageMultiplier01, 0.f, 1.f));
	}

	/** Combined alpha for AnimBP: PRQ + readiness leakage (System Scan → Slings / Correctives). */
	inline float CombinedPrimedAlpha(float PRQ0to100, float KineticLeakageMultiplier01)
	{
		const float A = PrimedLayerAlphaFromPRQ(PRQ0to100);
		const float L = FMath::Clamp(KineticLeakageMultiplier01, 0.35f, 1.f);
		return FMath::Clamp(A * L, 0.f, 1.f);
	}
}
