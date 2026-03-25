// Copyright (c) Final Evolution Lab.
// Neuro-Skill buffer: PRQ widens "Perfect" timing windows for strike sports (Baseball, Karate).

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELArenaRulesTypes.h"

namespace FELNeuroSkill
{
	/** Millisecond window for a perfect swing/strike; higher PRQ widens the band (see FFELSportNeuroConstants). */
	inline float PerfectHitWindowMsFromPRQ(const EFELArenaMode Mode, const float PRQ0to100, const FFELSportNeuroConstants& C)
	{
		const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
		if (Mode == EFELArenaMode::Baseball)
		{
			return C.BaseballSwingWindowMs + PRQ * 0.01f * C.BaseballPerfectWindowPRQExpandMs;
		}
		if (Mode == EFELArenaMode::Karate)
		{
			return C.KarateStrikeWindowMs + PRQ * 0.01f * C.KaratePerfectWindowPRQExpandMs;
		}
		return 0.f;
	}
}
