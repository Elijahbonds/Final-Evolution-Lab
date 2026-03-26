// Copyright (c) Final Evolution Lab.

#include "FELFootballBreakaway.h"
#include "Math/UnrealMathUtility.h"

void FELFootballBreakaway::EnterSuddenDeath(FFELFootballBreakawayRuntime& R, const float CarrierPRQ0to100, const float ClockSeconds)
{
	R.Phase = EFELFootballBreakawayPhase::SuddenDeath;
	const float P = FMath::Clamp(CarrierPRQ0to100, 0.f, 100.f) * 0.01f;
	R.SuddenDeathClockSec = FMath::Max(0.1f, ClockSeconds + FMath::Lerp(0.f, 0.85f, P));
	R.CarrierSpeedMultiplier = FMath::Lerp(1.f, 1.12f, P);
	R.PursuitSpeedMultiplier = FMath::Lerp(1.06f, 1.f, P);
}

void FELFootballBreakaway::Tick(
	FFELFootballBreakawayRuntime& R,
	const float DeltaSeconds,
	const float CarrierPRQ0to100,
	const float PursuerPRQ0to100)
{
	if (R.Phase != EFELFootballBreakawayPhase::SuddenDeath)
	{
		return;
	}
	const float C = FMath::Clamp(CarrierPRQ0to100, 0.f, 100.f) * 0.01f;
	const float Q = FMath::Clamp(PursuerPRQ0to100, 0.f, 100.f) * 0.01f;
	R.YardsToGoalUU = FMath::Max(0.f, R.YardsToGoalUU - DeltaSeconds * FMath::Lerp(220.f, 320.f, C) * R.CarrierSpeedMultiplier);
	R.SuddenDeathClockSec -= DeltaSeconds;
	// Pursuer closes distance faster when their PRQ is high.
	const float CloseRate = FMath::Lerp(180.f, 260.f, Q) * R.PursuitSpeedMultiplier * DeltaSeconds;
	if (R.YardsToGoalUU <= CloseRate * 0.25f && R.SuddenDeathClockSec <= 0.f)
	{
		R.Phase = EFELFootballBreakawayPhase::Resolved;
		return;
	}
	if (R.SuddenDeathClockSec <= 0.f)
	{
		R.Phase = EFELFootballBreakawayPhase::Resolved;
	}
	if (R.YardsToGoalUU <= 0.f)
	{
		R.Phase = EFELFootballBreakawayPhase::Resolved;
	}
}
