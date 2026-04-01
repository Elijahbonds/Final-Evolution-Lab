// Copyright (c) Final Evolution Lab.
// Per-arena-mode exercise demonstration pipeline: resolves Academy module montage (catalog override or mod1–mod15)
// and triggers the exercise demonstrator ghost with 3D Perfect Form montage playback.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaModeDefinitions.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "Engine/StreamableManager.h"
#include "Templates/SharedPointer.h"
#include "UFELExerciseDemoPipelineSubsystem.generated.h"

class UAnimMontage;
class UFELAssetRegistrySubsystem;
class UFELDemoManager;

UCLASS()
class FINALEVOLUTIONLAB_API UFELExerciseDemoPipelineSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	UFUNCTION(BlueprintCallable, Category = "FEL|ExerciseDemo")
	FString GetModuleKeyForArenaMode(EFELArenaMode Mode) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|ExerciseDemo")
	FString GetExerciseNameForArenaMode(EFELArenaMode Mode) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|ExerciseDemo")
	void PreloadExerciseDemoForMode(EFELArenaMode Mode);

	UFUNCTION(BlueprintCallable, Category = "FEL|ExerciseDemo")
	UAnimMontage* GetCachedMontageForMode(EFELArenaMode Mode);

	UFUNCTION(BlueprintCallable, Category = "FEL|ExerciseDemo")
	void TriggerExerciseDemoForMode(EFELArenaMode Mode, UFELDemoManager* DemoManager, float PRQ0to100);

private:
	void SeedModeToModuleMapping();
	void OnMontageLoaded(EFELArenaMode Mode);

	TMap<EFELArenaMode, FString> ModeToModuleKey;
	TMap<EFELArenaMode, FString> ModeToExerciseName;
	TMap<EFELArenaMode, TSharedPtr<FStreamableHandle>> ActiveLoadHandles;
	FStreamableManager DemoStreamableManager;
};
