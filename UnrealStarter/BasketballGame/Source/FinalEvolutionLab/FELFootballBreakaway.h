// Copyright (c) Final Evolution Lab.
// Stadium Field — sudden-death kick return: carrier vs pursuit, PRQ biases burst windows.

#pragma once

#include "CoreMinimal.h"
#include "FELFootballBreakaway.generated.h"

UENUM(BlueprintType)
enum class EFELFootballBreakawayPhase : uint8
{
	Neutral UMETA(DisplayName = "Neutral"),
	SuddenDeath UMETA(DisplayName = "Sudden Death Breakaway"),
	Resolved UMETA(DisplayName = "Resolved")
};

USTRUCT(BlueprintType)
struct FFELFootballBreakawayRuntime
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Football")
	EFELFootballBreakawayPhase Phase = EFELFootballBreakawayPhase::Neutral;

	/** Yards remaining to pay dirt (game units / 52.8 ≈ yards if 1uu=cm). */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Football")
	float YardsToGoalUU = 7200.f;

	/** Seconds left in sudden death before auto tackle resolution. */
	UPROPERTY(BlueprintReadOnly, Category = "FEL|Football")
	float SuddenDeathClockSec = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Football")
	float CarrierSpeedMultiplier = 1.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Football")
	float PursuitSpeedMultiplier = 1.f;
};

namespace FELFootballBreakaway
{
	/** Start or refresh sudden-death window; PRQ carrier widens escape margin. */
	FINALEVOLUTIONLAB_API void EnterSuddenDeath(FFELFootballBreakawayRuntime& R, float CarrierPRQ0to100, float ClockSeconds);

	FINALEVOLUTIONLAB_API void Tick(FFELFootballBreakawayRuntime& R, float DeltaSeconds, float CarrierPRQ0to100, float PursuerPRQ0to100);
}
