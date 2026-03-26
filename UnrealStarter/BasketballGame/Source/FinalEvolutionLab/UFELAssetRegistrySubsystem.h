// Copyright (c) Final Evolution Lab.
// Global 3D registry: venue levels, Academy mocap montages, Digital Twin mesh — async warm-up + purge for Gold Master memory budget.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "AssetRegistry/AssetData.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StreamableManager.h"
#include "Templates/SharedPointer.h"
#include "UObject/SoftObjectPtr.h"
#include "UFELAssetRegistrySubsystem.generated.h"

class UWorld;
class UAnimMontage;
class USkeletalMesh;

/**
 * Central registry for soft paths + async warm-up handles.
 * Venues: one UWorld per EFELArenaMode (assign real maps in editor via subsystem defaults or project config).
 * Academy: mod1…mod12 → DeepMotion-exported montages.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELAssetRegistrySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** 12 sport venues — Venice Beach, Dojo, etc. (content paths). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Venues")
	TMap<EFELArenaMode, TSoftObjectPtr<UWorld>> VenueWorldByArenaMode;

	/** Vertical Velocity Academy module keys (mod1…mod12) → demonstration montages under /Game/FEL/DeepMotion/… */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Academy")
	TMap<FString, TSoftObjectPtr<UAnimMontage>> AcademyModuleDemonstrationMontage;

	/** Scan-calibrated Digital Twin (same family as AFELBasketballCharacter mesh). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Avatar")
	TSoftObjectPtr<USkeletalMesh> DigitalTwinSkeletalMesh;

	/**
	 * Optional per-mode PrimaryAssetLabel bundles (FELVenue — see CONFIG_DefaultGame_FEL.ini AssetManagerSettings).
	 * When set, Bio-Sync warm-up loads this bundle atomically (twin mesh + Niagara + Luma textures) instead of separate soft paths.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Registry|Bundles")
	TMap<EFELArenaMode, FPrimaryAssetId> VenuePrimaryAssetBundles;

	/** When Swift Bio-Sync / readiness snapshot arrives: preload twin mesh + active venue in background (signal velocity). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|WarmUp")
	void WarmUpForBioSync(EFELArenaMode ActiveMode);

	/** Release streamable handles for a venue slice (call when leaving a mode). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|Memory")
	void PurgeVenueForMode(EFELArenaMode Mode);

	/** Optional: clear all warm-up handles (e.g. Lab shell exit). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|Memory")
	void PurgeAllVenueWarmHandles();

	UFUNCTION(BlueprintPure, Category = "FEL|Registry|Academy")
	bool HasModuleDemonstrationMontage(const FString& ModuleKey) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Registry|Academy")
	UAnimMontage* ResolveModuleDemonstrationMontage(const FString& ModuleKey, bool bLoadSynchronously);

	UFUNCTION(BlueprintPure, Category = "FEL|Registry|Academy")
	TSoftObjectPtr<UAnimMontage> GetModuleDemonstrationMontageSoft(const FString& ModuleKey) const;

	/** Async montage resolve — OnComplete fires when load finishes (or immediately if already resident). */
	TSharedPtr<FStreamableHandle> RequestAsyncDemonstrationMontage(
		const FString& ModuleKey,
		FStreamableDelegate OnComplete);

	UFUNCTION(BlueprintPure, Category = "FEL|Registry")
	bool HasCompletedBioSyncWarmUp() const { return bBioSyncWarmUpFinished; }

private:
	void SeedDefaultMapsIfEmpty();
	void OnBioSyncWarmUpFinished();

	FStreamableManager StreamableManager;
	TSharedPtr<FStreamableHandle> BioSyncWarmHandle;
	TMap<EFELArenaMode, TSharedPtr<FStreamableHandle>> VenueWarmHandlesByMode;
	bool bBioSyncWarmUpFinished = false;
};
