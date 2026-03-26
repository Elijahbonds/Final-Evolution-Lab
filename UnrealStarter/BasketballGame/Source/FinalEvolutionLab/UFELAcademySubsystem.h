// Copyright (c) Final Evolution Lab.
// Vertical Velocity Academy — 12-module registry + scan-driven prescription.

#pragma once

#include "CoreMinimal.h"
#include "Containers/Set.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELAcademyTypes.h"
#include "UFELAcademySubsystem.generated.h"

UCLASS()
class FINALEVOLUTIONLAB_API UFELAcademySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;

	UFUNCTION(BlueprintPure, Category = "FEL|Academy")
	void GetAllModules(TArray<FFELAcademyModuleEntry>& OutModules) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Academy")
	void BuildPrescriptionFromKineticHeat(double AnkleHeat01, double KneeHeat01, double HipHeat01, FFELAcademyPrescriptionResult& OutResult) const;

	/** Swift `mod9` — Plyos mastery: +2% neuro potential in Dunk Contest (exported via readiness_snapshot). */
	UFUNCTION(BlueprintPure, Category = "FEL|Academy")
	static float GetPlyosMasteryNeuroBonusFraction() { return 0.02f; }

	/**
	 * Call when the player completes a module in Unreal (Lab terminal / snack). De-duplicated per module until the next session export.
	 * Default shard grant matches Swift Academy module rewards (tune in one place).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Session")
	void RecordSessionModuleCompletion(const FString& ModuleKey, int32 EvolutionShardsForModule = 25);

	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Session")
	void GetSessionAcademyProgress(TArray<FString>& OutCompletedModuleKeys, int32& OutEvolutionShardsTotal) const;

	/** Called after `session_results.json` is written so the next match starts a fresh academy window. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Session")
	void ClearSessionAcademyProgressAfterExport();

private:
	void EnsureRegistryBuilt() const;

	mutable TArray<FFELAcademyModuleEntry> ModuleRegistry;
	mutable bool bRegistryBuilt = false;

	TSet<FString> SessionAcademyModules;
	int32 SessionAcademyShardTotal = 0;
};
