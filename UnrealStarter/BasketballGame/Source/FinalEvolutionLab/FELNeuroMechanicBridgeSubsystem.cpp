// Copyright (c) Final Evolution Lab.

#include "FELNeuroMechanicBridgeSubsystem.h"
#include "FELReadinessIO.h"
#include "FELArenaRulesRegistry.h"
#include "FELBasketballGameMode.h"
#include "FELBasketballCharacter.h"
#include "FELBasketballActor.h"
#include "FELGameModeDefinitions.h"
#include "FELNeuroMechanicDisplay.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/Pawn.h"
#include "TimerManager.h"

void UFELNeuroMechanicBridgeSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
#if !UE_BUILD_SHIPPING
	OnReadinessApplied.AddDynamic(this, &UFELNeuroMechanicBridgeSubsystem::OnReadinessAppliedDebugPIE);
#endif
	WorldInitDelegateHandle = FWorldDelegates::OnPostWorldInitialization.AddUObject(
		this, &UFELNeuroMechanicBridgeSubsystem::HandlePostWorldInit);
}

void UFELNeuroMechanicBridgeSubsystem::Deinitialize()
{
#if !UE_BUILD_SHIPPING
	OnReadinessApplied.RemoveDynamic(this, &UFELNeuroMechanicBridgeSubsystem::OnReadinessAppliedDebugPIE);
#endif
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			W->GetTimerManager().ClearTimer(PRQBoostResetTimerHandle);
		}
	}
	PendingPRQBoostTotal = 0.0;
	if (UWorld* W = PendingPostWorldInitWorld.Get())
	{
		W->GetTimerManager().ClearTimer(PostWorldInitApplyTimer);
	}
	PendingPostWorldInitWorld.Reset();

	if (WorldInitDelegateHandle.IsValid())
	{
		FWorldDelegates::OnPostWorldInitialization.Remove(WorldInitDelegateHandle);
		WorldInitDelegateHandle = FDelegateHandle();
	}
	Super::Deinitialize();
}

void UFELNeuroMechanicBridgeSubsystem::HandlePostWorldInit(UWorld* World, FWorldInitializationValues InitValues)
{
	(void)InitValues;
	if (!World)
	{
		return;
	}
	if (World->WorldType != EWorldType::Game && World->WorldType != EWorldType::PIE)
	{
		return;
	}

	PendingPostWorldInitWorld = World;
	World->GetTimerManager().ClearTimer(PostWorldInitApplyTimer);
	World->GetTimerManager().SetTimer(
		PostWorldInitApplyTimer,
		this,
		&UFELNeuroMechanicBridgeSubsystem::ExecuteDelayedPostWorldInitApply,
		0.08f,
		false);
}

void UFELNeuroMechanicBridgeSubsystem::ExecuteDelayedPostWorldInitApply()
{
	UWorld* World = PendingPostWorldInitWorld.Get();
	if (!World && GetGameInstance())
	{
		World = GetGameInstance()->GetWorld();
	}
	if (!World)
	{
		return;
	}

	if (bReapplyCachedOnWorldInit && bHasCachedSnapshot)
	{
		ApplyReadinessToActors(World, CachedSnapshot);
		return;
	}

	if (bAutoLoadFromDiskOnFirstWorldInit)
	{
		FString Err;
		ReloadSnapshotFromDiskAndApply(Err);
	}
}

void UFELNeuroMechanicBridgeSubsystem::OnReadinessAppliedDebugPIE(const FFELReadinessSnapshot& S)
{
#if !UE_BUILD_SHIPPING
	float JumpZ = 0.f;
	float Walk = 0.f;
	FELNeuroMechanicDisplay::ComputeEffectiveJumpAndWalk(S, JumpZ, Walk);

	UE_LOG(LogTemp, Display, TEXT("[FEL Clinical] Readiness applied — JumpZ=%.1f cm/s, MaxWalkSpeed=%.1f uu/s | verticalEstimateInches=%.2f neuralDrive=%.2f prqScore=%.1f"),
		JumpZ, Walk, S.VerticalEstimateInches, S.NeuralDrive, S.PRQScore);

	if (GEngine)
	{
		const FString Msg = FString::Printf(
			TEXT("Clinical HUD: JumpZ=%.0f  Locomotion=%.0f  (vertEst=%.1f in, drive=%.0f)"),
			JumpZ, Walk, S.VerticalEstimateInches, S.NeuralDrive);
		GEngine->AddOnScreenDebugMessage(871, 6.f, FColor::Cyan, Msg);
	}
#endif
}

bool UFELNeuroMechanicBridgeSubsystem::TryLoadSnapshot(FFELReadinessSnapshot& OutSnapshot, FString& OutError)
{
	FString* Ptr = &OutError;
	return FELReadinessIO::TryLoadSnapshot(OutSnapshot, Ptr);
}

bool UFELNeuroMechanicBridgeSubsystem::TryLoadSnapshotIntoCacheOnly(FString& OutError)
{
	if (!FELReadinessIO::TryLoadSnapshot(CachedSnapshot, &OutError))
	{
		return false;
	}
	bHasCachedSnapshot = true;
	return true;
}

void UFELNeuroMechanicBridgeSubsystem::GetCurrentArenaSettings(FFELArenaRules& OutRules) const
{
	EFELArenaMode M = FELArenaModeFromSwiftId(CachedSnapshot.ActiveArenaMode);
	if (M == EFELArenaMode::Unknown)
	{
		M = EFELArenaMode::BasketballHeadToHead;
	}
	OutRules = FELArenaRulesRegistry::GetMergedRules(M);
}

void UFELNeuroMechanicBridgeSubsystem::GetArenaSettingsForMode(EFELArenaMode Mode, FFELArenaRules& OutRules) const
{
	OutRules = FELArenaRulesRegistry::GetMergedRules(Mode);
}

void UFELNeuroMechanicBridgeSubsystem::ApplyReadiness(const FFELReadinessSnapshot& Snapshot, const bool bDeferActorApplyBecauseTravelQueued)
{
	CachedSnapshot = Snapshot;
	bHasCachedSnapshot = true;

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* World = GI->GetWorld())
		{
			bool bIssuedVenueTravel = false;
			if (bDeferActorApplyBecauseTravelQueued)
			{
				bIssuedVenueTravel = true;
			}
			else
			{
				bIssuedVenueTravel = FELReadinessIO::TryMandatoryVenueTravelForActiveMode(World, Snapshot);
			}
			if (!bIssuedVenueTravel)
			{
				ApplyReadinessToActors(World, Snapshot);
				if (Snapshot.bPlayTwinBirthCinematicOnce)
				{
					if (APlayerController* PC = World->GetFirstPlayerController())
					{
						if (AFELBasketballCharacter* Ch = Cast<AFELBasketballCharacter>(PC->GetPawn()))
						{
							Ch->PlayTwinBirthIntro(3.f);
						}
					}
					CachedSnapshot.bPlayTwinBirthCinematicOnce = false;
				}
			}
			// If `OpenLevel` ran, the next map load / GameMode will re-apply cached snapshot from disk.
		}
	}

	OnReadinessApplied.Broadcast(Snapshot);
#if !UE_BUILD_SHIPPING
	OnNeuroHUDStatsRefresh.Broadcast();
#endif
}

bool UFELNeuroMechanicBridgeSubsystem::ReloadSnapshotFromDiskAndApply(FString& OutError)
{
	FFELReadinessSnapshot Snap;
	if (!TryLoadSnapshot(Snap, OutError))
	{
		return false;
	}
	ApplyReadiness(Snap);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (AFELBasketballGameMode* GM = Cast<AFELBasketballGameMode>(W->GetAuthGameMode()))
			{
				GM->SyncNeuroFieldsFromSnapshot(Snap);
				GM->RefreshArenaConfigurationFromSnapshot(Snap);
			}
		}
	}
	return true;
}

bool UFELNeuroMechanicBridgeSubsystem::ApplySnapshotFromJsonString(const FString& JsonString, FString& OutError)
{
	FFELReadinessSnapshot Snap;
	FString* Ptr = &OutError;
	UWorld* WorldForParse = nullptr;
	if (UGameInstance* GI = GetGameInstance())
	{
		WorldForParse = GI->GetWorld();
	}
	bool bIssuedTravelFromParse = false;
	if (!FELReadinessIO::ParseSnapshotJsonString(JsonString, Snap, Ptr, WorldForParse, &bIssuedTravelFromParse))
	{
		return false;
	}
	ApplyReadiness(Snap, bIssuedTravelFromParse);
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (AFELBasketballGameMode* GM = Cast<AFELBasketballGameMode>(W->GetAuthGameMode()))
			{
				GM->SyncNeuroFieldsFromSnapshot(Snap);
				GM->RefreshArenaConfigurationFromSnapshot(Snap);
			}
		}
	}
	return true;
}

void UFELNeuroMechanicBridgeSubsystem::ReapplyCachedToCurrentWorld()
{
	if (!bHasCachedSnapshot)
	{
		return;
	}
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* World = GI->GetWorld())
		{
			ApplyReadinessToActors(World, CachedSnapshot);
		}
	}
}

void UFELNeuroMechanicBridgeSubsystem::SyncAuthGameModeNeuroFromCache()
{
	if (!bHasCachedSnapshot)
	{
		return;
	}
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			if (AFELBasketballGameMode* GM = Cast<AFELBasketballGameMode>(W->GetAuthGameMode()))
			{
				GM->SyncNeuroFieldsFromSnapshot(CachedSnapshot);
			}
		}
	}
}

void UFELNeuroMechanicBridgeSubsystem::SetBrainBrawlBoostCountingEnabled(const bool bEnabled)
{
	bBrainBrawlBoostCountingEnabled = bEnabled;
}

void UFELNeuroMechanicBridgeSubsystem::ResetBrainBrawlBoostCountForActivePhase()
{
	BrainBrawlBoostCountThisSession = 0;
}

void UFELNeuroMechanicBridgeSubsystem::ApplyTemporaryPRQBoost(const double DeltaPoints, const float DurationSeconds)
{
	if (!bHasCachedSnapshot)
	{
		return;
	}
	const double Added = FMath::Clamp(DeltaPoints, 0.0, 25.0);
	PendingPRQBoostTotal += Added;
	CachedSnapshot.PRQScore = FMath::Min(100.0, CachedSnapshot.PRQScore + Added);
	if (bBrainBrawlBoostCountingEnabled)
	{
		BrainBrawlBoostCountThisSession++;
	}
	ApplyReadiness(CachedSnapshot);
	SyncAuthGameModeNeuroFromCache();

	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* W = GI->GetWorld())
		{
			W->GetTimerManager().SetTimer(
				PRQBoostResetTimerHandle,
				this,
				&UFELNeuroMechanicBridgeSubsystem::ExpirePendingPRQBoost,
				FMath::Max(0.1f, DurationSeconds),
				false);
		}
	}
}

void UFELNeuroMechanicBridgeSubsystem::ExpirePendingPRQBoost()
{
	if (!bHasCachedSnapshot)
	{
		PendingPRQBoostTotal = 0.0;
		return;
	}
	const double Sub = PendingPRQBoostTotal;
	PendingPRQBoostTotal = 0.0;
	CachedSnapshot.PRQScore = FMath::Max(0.0, CachedSnapshot.PRQScore - Sub);
	ApplyReadiness(CachedSnapshot);
	SyncAuthGameModeNeuroFromCache();
}

void UFELNeuroMechanicBridgeSubsystem::ApplyReadinessToActors(UWorld* World, const FFELReadinessSnapshot& Snapshot)
{
	if (!World)
	{
		return;
	}

	EFELArenaMode Am = FELArenaModeFromSwiftId(Snapshot.ActiveArenaMode);
	if (Am == EFELArenaMode::Unknown)
	{
		Am = EFELArenaMode::BasketballHeadToHead;
	}
	const FFELArenaRules Rules = FELArenaRulesRegistry::GetMergedRules(Am);

	if (AFELBasketballGameMode* GM = Cast<AFELBasketballGameMode>(World->GetAuthGameMode()))
	{
		GM->RefreshPRQInfluenceFromAthleteProfile(static_cast<float>(Snapshot.PRQScore));
	}

	if (APlayerController* PC = World->GetFirstPlayerController())
	{
		if (APawn* Pawn = PC->GetPawn())
		{
			if (AFELBasketballCharacter* Character = Cast<AFELBasketballCharacter>(Pawn))
			{
				Character->ApplyReadiness(Snapshot);
				Character->ApplyArenaPhysicsLayer(Rules);
				Character->ApplyNeuroArenaGameplay(Snapshot, Rules);
			}
		}
	}

	for (TActorIterator<AFELBasketballActor> It(World); It; ++It)
	{
		if (AFELBasketballActor* Ball = *It)
		{
			Ball->ApplyReadiness(Snapshot);
		}
	}

	FELReadinessIO::ApplyNeuroFlowPostProcessFromSnapshot(World, Snapshot);
}
