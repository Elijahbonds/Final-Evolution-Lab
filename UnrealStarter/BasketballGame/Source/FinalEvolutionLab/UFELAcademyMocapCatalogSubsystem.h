// Copyright (c) Final Evolution Lab.
// Maps Vertical Velocity Academy module keys (mod1…mod15 registry) to demonstration montages from DeepMotion export.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "FELDunkMocapTypes.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UObject/SoftObjectPtr.h"
#include "UFELAcademyMocapCatalogSubsystem.generated.h"

class UAnimMontage;

UCLASS()
class FINALEVOLUTIONLAB_API UFELAcademyMocapCatalogSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	UFELAcademyMocapCatalogSubsystem();
	/** Academy module montages (mod1…mod15) live on `UFELAssetRegistrySubsystem` for async warm-up + purge. */

	/** DeepMotion "Perfect Form" clips — Dunk / Strike / Kick keyed by arena mode (assign in editor). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Mocap|PerfectForm")
	TMap<EFELArenaMode, TSoftObjectPtr<UAnimMontage>> PerfectFormMontageByArenaMode;

	/**
	 * Pro dunker reference montages (manual export → DeepMotion / FBX → import). Suggested content path:
	 * `/Game/FEL/Mocap/Dunkers/ElijahBonds/` and `/Game/FEL/Mocap/Dunkers/AmirSmith/`.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Mocap|Dunkers")
	TArray<TSoftObjectPtr<UAnimMontage>> ElijahBondsDunkReferenceMontages;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Mocap|Dunkers")
	TArray<TSoftObjectPtr<UAnimMontage>> AmirSmithDunkReferenceMontages;

	/** Archetype buckets (windmill, 360, etc.) — CDO seeds empty rows per enum value for faster authoring. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Mocap|Dunkers|Archetypes")
	TMap<EFELDunkMocapArchetype, FFELDunkArchetypeClipBucket> DunkMontagesByArchetype;

	/** More pros: set `DunkerSlug` (e.g. `JordanKilian`) and assign montages; resolved by `ResolveDunkerReferenceMontage`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Mocap|Dunkers")
	TArray<FFELNamedDunkerMocapList> AdditionalNamedDunkerLists;

	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap")
	UAnimMontage* ResolveMontageForModule(const FString& ModuleKey, bool bLoadSynchronously = true);

	/** Resolves DeepMotion mocap for the active sport context (Dunk contest, Karate strike, soccer kick, etc.). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap|PerfectForm")
	UAnimMontage* ResolvePerfectFormMontage(EFELArenaMode Mode, bool bLoadSynchronously = true);

	/** `DunkerId`: `ElijahBonds` / `Bonds` / `AmirSmith` / `Smith`, or any `AdditionalNamedDunkerLists.DunkerSlug`. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap|Dunkers")
	UAnimMontage* ResolveDunkerReferenceMontage(FName DunkerId, int32 ClipIndex, bool bLoadSynchronously = true);

	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap|Dunkers|Archetypes")
	UAnimMontage* ResolveDunkArchetypeMontage(EFELDunkMocapArchetype Archetype, int32 ClipIndex, bool bLoadSynchronously = true);

	/** Deterministic pick for contest variety; falls back to `Generic` if the archetype bucket is empty. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap|Dunkers|Archetypes")
	UAnimMontage* ResolveRandomDunkMontageForArchetype(EFELDunkMocapArchetype Archetype, int32 RandomSeed, bool bLoadSynchronously = true);

	UFUNCTION(BlueprintPure, Category = "FEL|Academy|Mocap|Dunkers|Archetypes")
	int32 GetDunkArchetypeClipCount(EFELDunkMocapArchetype Archetype) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Academy|Mocap")
	bool HasModuleMontage(const FString& ModuleKey);

protected:
	static UAnimMontage* ResolveSoftMontageRef(const TSoftObjectPtr<UAnimMontage>& Ref, bool bLoadSynchronously);
};
