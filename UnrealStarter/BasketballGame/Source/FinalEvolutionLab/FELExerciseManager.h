// Copyright (c) Final Evolution Lab.
// Exercise Manager: loads the exercise database, manages animations, tracks progress.
// Phase 3: Exercise Animation System

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELExercise.h"
#include "FELExerciseManager.generated.h"

class UAnimMontage;

/**
 * Central subsystem that owns the full exercise database and player progress.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELExerciseManager : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	// ── lifecycle ──────────────────────────────────────────────────────
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── database queries ──────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FExerciseData> GetAllExercises() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FExerciseData> GetExercisesByCategory(EExerciseCategory Category) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FExerciseData> GetExercisesByDifficulty(EExerciseDifficulty Difficulty) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	bool GetExerciseByID(const FString& ExerciseID, FExerciseData& OutExercise) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FExerciseData> GetExercisesForGameMode(const FString& GameModeID) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FExerciseData> SearchExercises(const FString& Query) const;

	// ── animation helpers ─────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	UAnimMontage* LoadExerciseAnimation(const FString& ExerciseID, int32 VariantIndex = 0);

	// ── progress / personal records ───────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	void RecordExerciseCompletion(const FString& ExerciseID, int32 Reps, float Weight, float DurationMinutes);

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	FExerciseProgress GetExerciseProgress(const FString& ExerciseID) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	float CalculateCaloriesBurned(const FString& ExerciseID, float DurationMinutes) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Exercise")
	TArray<FExerciseData> GetRecommendedExercises(int32 Count = 5) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Exercise")
	int32 GetExerciseCount() const { return ExerciseDB.Num(); }

private:
	void LoadExerciseDatabase();
	void LoadProgressFromSave();
	void SaveProgressToSave();

	TMap<FString, FExerciseData>    ExerciseDB;
	TMap<FString, FExerciseProgress> ProgressMap;
	TMap<FString, UAnimMontage*>     AnimCache;
};
