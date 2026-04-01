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
	case EFELArenaMode::Soccer:
		if (PrimaryAthlete)
		{
			if (UCharacterMovementComponent* M = PrimaryAthlete->GetCharacterMovement())
			{
				const float P01 = FMath::Clamp(PRQ * 0.01f, 0.f, 1.f);
				const float Base = FMath::Max(1.f, PrimaryAthlete->FELGetNeuroBaselineWalkSpeed());
				M->MaxWalkSpeed = Base * FMath::Lerp(0.95f, 1.12f, P01);
			}
		}
		break;
	case EFELArenaMode::Tennis:
	case EFELArenaMode::Volleyball:
		if (PrimaryAthlete)
		{
			if (UCharacterMovementComponent* M = PrimaryAthlete->GetCharacterMovement())
			{
				const float P01 = FMath::Clamp(PRQ * 0.01f, 0.f, 1.f);
				const float Base = FMath::Max(1.f, PrimaryAthlete->FELGetNeuroBaselineWalkSpeed());
				M->MaxWalkSpeed = Base * FMath::Lerp(0.92f, 1.08f, P01);
			}
		}
		break;
	case EFELArenaMode::Golf:
	case EFELArenaMode::Baseball:
	case EFELArenaMode::Gymnastics:
	case EFELArenaMode::Karate:
	case EFELArenaMode::BasketballHeadToHead:
	case EFELArenaMode::BasketballDunkContest:
	case EFELArenaMode::Basketball3v3:
	case EFELArenaMode::BrainBrawl:
	case EFELArenaMode::MarketBrowse:
	case EFELArenaMode::Unknown:
	default:
		break;
	case EFELArenaMode::Surfing:
	case EFELArenaMode::Skateboarding:
	case EFELArenaMode::Snowboarding:
		if (PrimaryAthlete)
		{
			if (UCharacterMovementComponent* M = PrimaryAthlete->GetCharacterMovement())
			{
				const float P01 = FMath::Clamp(PRQ * 0.01f, 0.f, 1.f);
				const float Base = FMath::Max(1.f, PrimaryAthlete->FELGetNeuroBaselineWalkSpeed());
				M->MaxWalkSpeed = Base * FMath::Lerp(0.96f, 1.14f, P01);
			}
		}
		break;
	}
}
