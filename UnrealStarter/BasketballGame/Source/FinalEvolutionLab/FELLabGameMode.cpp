// Copyright (c) Final Evolution Lab.

#include "FELLabGameMode.h"
#include "FELBasketballCharacter.h"
#include "FELFootballBreakaway.h"
#include "FELPRQInfluence.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Math/UnrealMathUtility.h"

AFELLabGameMode::AFELLabGameMode()
{
	PrimaryActorTick.bCanEverTick = false;
	PRQInfluenceMultipliers = FELPRQInfluence::ComputeMultipliersFromPRQ(CachedPRQ0to100ForArena);
}

void AFELLabGameMode::RefreshPRQInfluenceFromAthleteProfile(const float PRQ0to100)
{
	CachedPRQ0to100ForArena = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	PRQInfluenceMultipliers = FELPRQInfluence::ComputeMultipliersFromPRQ(CachedPRQ0to100ForArena);
}

void AFELLabGameMode::TriggerFootballSuddenDeathBreakaway(const float ClockSeconds)
{
	FELFootballBreakaway::EnterSuddenDeath(FootballBreakawayRuntime, CachedPRQ0to100ForArena, ClockSeconds);
}

void AFELLabGameMode::TickLaboratoryArenaModes(
	const float DeltaSeconds,
	const EFELArenaMode ActiveMode,
	AFELBasketballCharacter* PrimaryAthlete)
{
	const float PRQ = CachedPRQ0to100ForArena;
	switch (ActiveMode)
	{
	case EFELArenaMode::Football:
		FELFootballBreakaway::Tick(FootballBreakawayRuntime, DeltaSeconds, PRQ, PRQ * 0.92f);
		if (PrimaryAthlete && FootballBreakawayRuntime.Phase == EFELFootballBreakawayPhase::SuddenDeath)
		{
			if (UCharacterMovementComponent* M = PrimaryAthlete->GetCharacterMovement())
			{
				const float Base = FMath::Max(1.f, PrimaryAthlete->FELGetNeuroBaselineWalkSpeed());
				M->MaxWalkSpeed = Base * FootballBreakawayRuntime.CarrierSpeedMultiplier;
			}
		}
		break;
	default:
		break;
	}
	(void)ActiveMode;
}
