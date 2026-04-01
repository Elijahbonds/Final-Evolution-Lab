// Copyright (c) Final Evolution Lab.
// Exercise catalog subsystem — loads ExerciseCatalog.json, provides exercise lookup,
// generates training programs per sport mode, and drives 3D demonstration playback.

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELExerciseCatalogTypes.h"
#include "FELArenaModeDefinitions.h"
#include "UFELExerciseCatalogSubsystem.generated.h"

class AFELExerciseDemonstrator;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnExerciseDemoStarted, const FString&, ExerciseId);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnExerciseDemoCompleted, const FString&, ExerciseId, bool, bWasInterrupted);

UCLASS()
class FINALEVOLUTIONLAB_API UFELExerciseCatalogSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Load or reload the exercise catalog from JSON. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	bool LoadCatalog();

	/** Get all exercises in a category. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FFELExerciseDefinition> GetExercisesByCategory(EFELExerciseCategory Category) const;

	/** Get exercises relevant to a specific game mode. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FFELExerciseDefinition> GetExercisesForMode(const FString& ModeKey) const;

	/** Find a specific exercise by ID. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	bool GetExerciseById(const FString& ExerciseId, FFELExerciseDefinition& OutExercise) const;

	/** Generate a warm-up program for a game mode. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	FFELExerciseSession GenerateWarmUpSession(const FString& ModeKey, float AvailableMinutes = 10.f) const;

	/** Generate a full training session combining warm-up, strength, sport-specific, and cooldown. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	FFELExerciseSession GenerateFullTrainingSession(const FString& ModeKey, float AvailableMinutes = 30.f) const;

	/** Spawn a demonstrator actor and play exercise animation. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	bool PlayExerciseDemo(const FString& ExerciseId, FVector SpawnLocation, FRotator SpawnRotation);

	/** Stop current exercise demonstration. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	void StopExerciseDemo();

	/** Get total number of exercises in catalog. */
	UFUNCTION(BlueprintPure, Category = "FEL|Exercise")
	int32 GetTotalExerciseCount() const { return AllExercises.Num(); }

	/** Returns JSON manifest of all exercises for the streaming frontend. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	FString GetExerciseManifestJSON() const;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Exercise")
	FOnExerciseDemoStarted OnExerciseDemoStarted;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Exercise")
	FOnExerciseDemoCompleted OnExerciseDemoCompleted;

private:
	TArray<FFELExerciseDefinition> AllExercises;
	TMap<FString, FFELExerciseDefinition> ExerciseLookup;

	TWeakObjectPtr<AFELExerciseDemonstrator> ActiveDemonstrator;
	FString ActiveDemoExerciseId;

	void ParseCatalogJSON(const FString& JsonContent);
	EFELExerciseCategory ParseCategoryId(const FString& CategoryId) const;

	UFUNCTION()
	void HandleDemonstrationEnded(bool bInterrupted);
};
