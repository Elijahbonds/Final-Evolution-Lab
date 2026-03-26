// Copyright (c) Final Evolution Lab.

#include "FELKaratePRQBoost.h"
#include "Math/UnrealMathUtility.h"

void FELKaratePRQBoost::ComputeCombatBoost(const float PRQ0to100, FFELKaratePRQCombatBoost& Out)
{
	const float T = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	Out.StrengthMultiplier = FMath::Lerp(0.88f, 1.22f, T);
	Out.SpeedMultiplier = FMath::Lerp(0.9f, 1.16f, T);
	Out.PerformanceMultiplier = FMath::Lerp(0.86f, 1.15f, T);
}
