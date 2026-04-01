// Copyright (c) Final Evolution Lab.

#include "UFELAssetRegistrySubsystem.h"
#include "FinalEvolutionLab.h"
#include "FELArenaVenueTravel.h"
#include "Animation/AnimMontage.h"
#include "Engine/AssetManager.h"
#include "Engine/World.h"
#include "UObject/UObjectGlobals.h"

namespace
{
	static FSoftObjectPath DefaultVenuePathForMode(const EFELArenaMode Mode)
	{
		return FELArenaVenueTravel::GetDefaultVenueSoftPath(Mode);
	}

	static FSoftObjectPath DefaultDeepMotionMontagePath(const int32 ModuleIndex1Based)
	{
		return FSoftObjectPath(*FString::Printf(
			TEXT("/Game/FEL/DeepMotion/Demo_mod%d/Demo_mod%d.Demo_mod%d"),
			ModuleIndex1Based,
			ModuleIndex1Based,
			ModuleIndex1Based));
	}
}

void UFELAssetRegistrySubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	SeedDefaultMapsIfEmpty();
}

void UFELAssetRegistrySubsystem::Deinitialize()
{
	PurgeAllVenueWarmHandles();
	if (BioSyncWarmHandle.IsValid())
	{
		BioSyncWarmHandle->CancelHandle();
		BioSyncWarmHandle.Reset();
	}
	Super::Deinitialize();
}

void UFELAssetRegistrySubsystem::SeedDefaultMapsIfEmpty()
{
	if (VenueWorldByArenaMode.Num() == 0)
	{
		static const EFELArenaMode kModes[] = {
			EFELArenaMode::BasketballHeadToHead,
			EFELArenaMode::BasketballDunkContest,
			EFELArenaMode::Basketball3v3,
			EFELArenaMode::Karate,
			EFELArenaMode::Baseball,
			EFELArenaMode::Football,
			EFELArenaMode::Soccer,
			EFELArenaMode::Golf,
			EFELArenaMode::Tennis,
			EFELArenaMode::Volleyball,
			EFELArenaMode::Gymnastics,
			EFELArenaMode::BrainBrawl,
			EFELArenaMode::MarketBrowse,
			EFELArenaMode::Surfing,
			EFELArenaMode::Skateboarding,
			EFELArenaMode::Snowboarding,
		};
		for (EFELArenaMode M : kModes)
		{
			TSoftObjectPtr<UWorld> W;
			W = TSoftObjectPtr<UWorld>(DefaultVenuePathForMode(M));
			VenueWorldByArenaMode.Add(M, W);
		}
	}

	if (AcademyModuleDemonstrationMontage.Num() == 0)
	{
		for (int32 i = 1; i <= 15; ++i)
		{
			const FString Key = FString::Printf(TEXT("mod%d"), i);
			TSoftObjectPtr<UAnimMontage> Montage;
			Montage = TSoftObjectPtr<UAnimMontage>(DefaultDeepMotionMontagePath(i));
			AcademyModuleDemonstrationMontage.Add(Key, Montage);
		}
	}

	if (DigitalTwinSkeletalMesh.IsNull())
	{
		DigitalTwinSkeletalMesh = TSoftObjectPtr<USkeletalMesh>(
			FSoftObjectPath(TEXT("/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking.SKM_ElijahBonds_Walking")));
	}
}

void UFELAssetRegistrySubsystem::WarmUpForBioSync(const EFELArenaMode ActiveMode)
{
	bBioSyncWarmUpFinished = false;
	if (BioSyncWarmHandle.IsValid())
	{
		BioSyncWarmHandle->CancelHandle();
		BioSyncWarmHandle.Reset();
	}

	if (UAssetManager::IsInitialized())
	{
		if (const FPrimaryAssetId* BundleId = VenuePrimaryAssetBundles.Find(ActiveMode))
		{
			if (BundleId->IsValid())
			{
				UAssetManager::Get().LoadPrimaryAsset(
					*BundleId,
					TArray<FName>(),
					FStreamableDelegate::CreateUObject(this, &UFELAssetRegistrySubsystem::OnBioSyncWarmUpFinished));
				return;
			}
		}
	}

	TArray<FSoftObjectPath> Paths;
	if (!DigitalTwinSkeletalMesh.IsNull())
	{
		Paths.Add(DigitalTwinSkeletalMesh.ToSoftObjectPath());
	}
	if (const TSoftObjectPtr<UWorld>* Venue = VenueWorldByArenaMode.Find(ActiveMode))
	{
		if (!Venue->IsNull())
		{
			Paths.Add(Venue->ToSoftObjectPath());
		}
	}

	if (Paths.Num() == 0)
	{
		OnBioSyncWarmUpFinished();
		return;
	}

	BioSyncWarmHandle = StreamableManager.RequestAsyncLoad(
		Paths,
		FStreamableDelegate::CreateUObject(this, &UFELAssetRegistrySubsystem::OnBioSyncWarmUpFinished));

	if (const TSoftObjectPtr<UWorld>* Venue = VenueWorldByArenaMode.Find(ActiveMode))
	{
		if (!Venue->IsNull())
		{
			if (TSharedPtr<FStreamableHandle>* Existing = VenueWarmHandlesByMode.Find(ActiveMode))
			{
				if (Existing->IsValid())
				{
					(*Existing)->ReleaseHandle();
				}
			}
			VenueWarmHandlesByMode.Remove(ActiveMode);
			VenueWarmHandlesByMode.Add(ActiveMode, BioSyncWarmHandle);
		}
	}
}

void UFELAssetRegistrySubsystem::OnBioSyncWarmUpFinished()
{
	bBioSyncWarmUpFinished = true;
}

void UFELAssetRegistrySubsystem::PurgeVenueForMode(const EFELArenaMode Mode)
{
	if (TSharedPtr<FStreamableHandle>* H = VenueWarmHandlesByMode.Find(Mode))
	{
		if (H->IsValid())
		{
			(*H)->ReleaseHandle();
		}
		VenueWarmHandlesByMode.Remove(Mode);
	}
	if (UAssetManager* AM = UAssetManager::GetIfInitialized())
	{
		if (const FPrimaryAssetId* BundleId = VenuePrimaryAssetBundles.Find(Mode))
		{
			if (BundleId->IsValid())
			{
				AM->UnloadPrimaryAsset(*BundleId);
			}
		}
	}
	FlushAsyncLoading();
}

void UFELAssetRegistrySubsystem::PurgeAllVenueWarmHandles()
{
	for (auto& Pair : VenueWarmHandlesByMode)
	{
		if (Pair.Value.IsValid())
		{
			Pair.Value->ReleaseHandle();
		}
	}
	VenueWarmHandlesByMode.Empty();
	if (UAssetManager::IsInitialized())
	{
		for (const TPair<EFELArenaMode, FPrimaryAssetId>& P : VenuePrimaryAssetBundles)
		{
			if (P.Value.IsValid())
			{
				UAssetManager::Get().UnloadPrimaryAsset(P.Value);
			}
		}
	}
	FlushAsyncLoading();
}

void UFELAssetRegistrySubsystem::RegisterAcademyModuleDemonstrationMontage(
	const FString& ModuleKey,
	const TSoftObjectPtr<UAnimMontage> Montage)
{
	if (ModuleKey.IsEmpty() || Montage.IsNull())
	{
		return;
	}
	AcademyModuleDemonstrationMontage.Add(ModuleKey, Montage);
}

bool UFELAssetRegistrySubsystem::HasModuleDemonstrationMontage(const FString& ModuleKey) const
{
	const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey);
	return Found && !Found->IsNull();
}

UAnimMontage* UFELAssetRegistrySubsystem::ResolveModuleDemonstrationMontage(const FString& ModuleKey, const bool bLoadSynchronously)
{
	const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey);
	if (!Found || Found->IsNull())
	{
#if !UE_BUILD_SHIPPING
		UE_LOG(LogFinalEvolutionLab, Verbose, TEXT("ResolveModuleDemonstrationMontage: no soft reference for module key '%s'."), *ModuleKey);
#endif
		return nullptr;
	}
	if (bLoadSynchronously)
	{
		UAnimMontage* const Loaded = Found->LoadSynchronous();
#if !UE_BUILD_SHIPPING
		if (!Loaded)
		{
			UE_LOG(LogFinalEvolutionLab, Verbose, TEXT("ResolveModuleDemonstrationMontage: LoadSynchronous failed for '%s' (path=%s). Cook/import DeepMotion montage or clear the map entry."),
				*ModuleKey, *Found->ToSoftObjectPath().ToString());
		}
#endif
		return Loaded;
	}
	return Found->Get();
}

TSoftObjectPtr<UAnimMontage> UFELAssetRegistrySubsystem::GetModuleDemonstrationMontageSoft(const FString& ModuleKey) const
{
	if (const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey))
	{
		return *Found;
	}
	return TSoftObjectPtr<UAnimMontage>();
}

TSharedPtr<FStreamableHandle> UFELAssetRegistrySubsystem::RequestAsyncDemonstrationMontage(
	const FString& ModuleKey,
	FStreamableDelegate OnComplete)
{
	const TSoftObjectPtr<UAnimMontage>* Found = AcademyModuleDemonstrationMontage.Find(ModuleKey);
	if (!Found || Found->IsNull())
	{
		if (OnComplete.IsBound())
		{
			OnComplete.Execute();
		}
		return nullptr;
	}
	if (Found->Get())
	{
		if (OnComplete.IsBound())
		{
			OnComplete.Execute();
		}
		return nullptr;
	}
	// StreamableManager invokes OnComplete on the game thread when the asset finishes loading.
	return StreamableManager.RequestAsyncLoad(Found->ToSoftObjectPath(), OnComplete);
}
