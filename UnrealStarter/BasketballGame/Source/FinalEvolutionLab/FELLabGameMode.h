// Copyright (c) Final Evolution Lab.
// Design-doc name: A_EFELLabGameMode — authoritative lab game mode: PRQ influence + twelve-pillar simulation tick.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELFootballBreakaway.h"
#include "FELPRQInfluence.h"
#include "GameFramework/GameModeBase.h"
#include "FELLabGameMode.generated.h"

class AFELBasketballCharacter;

UCLASS(Blueprintable)
class FINALEVOLUTIONLAB_API AFELLabGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	AFELLabGameMode();

	/**
	 * Athlete profile PRQ (0–100). Same field populated from Supabase-backed readiness on device:
	 * External services or local files write `readiness_snapshot.json`; Unreal ingests via UFELNeuroMechanicBridgeSubsystem.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|PRQ")
	void RefreshPRQInfluenceFromAthleteProfile(float PRQ0to100);

	UFUNCTION(BlueprintPure, Category = "FEL|PRQ")
	float GetPRQJumpHeightMultiplier() const { return PRQInfluenceMultipliers.JumpHeightMultiplier; }

	UFUNCTION(BlueprintPure, Category = "FEL|PRQ")
	float GetPRQSprintSpeedMultiplier() const { return PRQInfluenceMultipliers.SprintSpeedMultiplier; }

	UFUNCTION(BlueprintPure, Category = "FEL|PRQ")
	float GetPRQReactionTimeScale() const { return PRQInfluenceMultipliers.ReactionTimeScale; }

	/** Stadium Field — begin sudden-death kick return chase (call from mode activation or Blueprint). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Football")
	void TriggerFootballSuddenDeathBreakaway(float ClockSeconds = 4.5f);

	UFUNCTION(BlueprintPure, Category = "FEL|Football")
	const FFELFootballBreakawayRuntime& GetFootballBreakawayRuntime() const { return FootballBreakawayRuntime; }

	/**
	 * Central tick for sport-specific state machines (football breakaway, future possession clocks).
	 * Invoked from AFELBasketballGameMode::Tick with the active EFELArenaMode.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Arena")
	void TickLaboratoryArenaModes(float DeltaSeconds, EFELArenaMode ActiveMode, AFELBasketballCharacter* PrimaryAthlete);

protected:
	UPROPERTY(BlueprintReadOnly, Category = "FEL|PRQ")
	FFELPRQInfluenceMultipliers PRQInfluenceMultipliers;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Arena")
	float CachedPRQ0to100ForArena = 75.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Football")
	FFELFootballBreakawayRuntime FootballBreakawayRuntime;
};
