// Copyright (c) Final Evolution Lab.
// Maps Vertical Velocity Academy module keys (mod1…mod12) to demonstration montages from DeepMotion export.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "UObject/SoftObjectPtr.h"
#include "UFELAcademyMocapCatalogSubsystem.generated.h"

class UAnimMontage;

UCLASS()
class FINALEVOLUTIONLAB_API UFELAcademyMocapCatalogSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** Academy module montages (mod1…mod12) live on `UFELAssetRegistrySubsystem` for async warm-up + purge. */

	/** DeepMotion "Perfect Form" clips — Dunk / Strike / Kick keyed by arena mode (assign in editor). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Mocap|PerfectForm")
	TMap<EFELArenaMode, TSoftObjectPtr<UAnimMontage>> PerfectFormMontageByArenaMode;

	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap")
	UAnimMontage* ResolveMontageForModule(const FString& ModuleKey, bool bLoadSynchronously = true);

	/** Resolves DeepMotion mocap for the active sport context (Dunk contest, Karate strike, soccer kick, etc.). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap|PerfectForm")
	UAnimMontage* ResolvePerfectFormMontage(EFELArenaMode Mode, bool bLoadSynchronously = true);

	UFUNCTION(BlueprintPure, Category = "FEL|Academy|Mocap")
	bool HasModuleMontage(const FString& ModuleKey);
};
