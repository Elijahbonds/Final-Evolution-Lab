// Copyright (c) Final Evolution Lab.
// Workout programming logic: periodization, progressive overload, workout plans.
// Phase 3: Exercise Animation System

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELExercise.h"
#include "FELWorkoutProgram.generated.h"

/* ─────────────────────────────  ENUMS  ───────────────────────────── */

UENUM(BlueprintType)
enum class EWorkoutGoal : uint8
{
	Strength       UMETA(DisplayName = "Strength"),
	Hypertrophy    UMETA(DisplayName = "Hypertrophy"),
	Endurance      UMETA(DisplayName = "Endurance"),
	Athletic       UMETA(DisplayName = "Athletic Performance"),
	Mobility       UMETA(DisplayName = "Mobility & Recovery"),
	VerticalJump   UMETA(DisplayName = "Vertical Jump")
};

UENUM(BlueprintType)
enum class EPeriodization : uint8
{
	Linear         UMETA(DisplayName = "Linear"),
	Undulating     UMETA(DisplayName = "Daily Undulating"),
	Block          UMETA(DisplayName = "Block")
};

UENUM(BlueprintType)
enum class EWorkoutStatus : uint8
{
	NotStarted     UMETA(DisplayName = "Not Started"),
	InProgress     UMETA(DisplayName = "In Progress"),
	Completed      UMETA(DisplayName = "Completed"),
	Skipped        UMETA(DisplayName = "Skipped")
};

/* ─────────────────────────  EXERCISE  SET  ───────────────────────── */

USTRUCT(BlueprintType)
struct FExerciseSet
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	FString ExerciseID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	int32 Sets = 3;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	int32 Reps = 10;

	/** Rest time between sets in seconds. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	float RestTime = 60.f;

	/** Optional: weight / resistance (lbs). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	float Weight = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	FString Notes;

	/** Completed sets tracking for active session. */
	UPROPERTY(BlueprintReadWrite, Category = "FEL|Workout")
	int32 CompletedSets = 0;
};

/* ─────────────────────────  WORKOUT  DAY  ────────────────────────── */

USTRUCT(BlueprintType)
struct FWorkoutDay
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	FString DayName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	TArray<FExerciseSet> Exercises;

	/** Estimated duration in minutes. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	int32 EstimatedDuration = 45;

	UPROPERTY(BlueprintReadWrite, Category = "FEL|Workout")
	EWorkoutStatus Status = EWorkoutStatus::NotStarted;
};

/* ────────────────────────  WORKOUT  WEEK  ────────────────────────── */

USTRUCT(BlueprintType)
struct FWorkoutWeek
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	int32 WeekNumber = 1;

	/** True if this is a deload / recovery week. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	bool bIsDeloadWeek = false;

	/** Intensity modifier (0.5 = deload, 1.0 = normal, 1.1 = overreach). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout", meta = (ClampMin = "0.3", ClampMax = "1.3"))
	float IntensityModifier = 1.0f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	TArray<FWorkoutDay> Days;
};

/* ──────────────────────  WORKOUT  PROGRAM  ───────────────────────── */

USTRUCT(BlueprintType)
struct FWorkoutProgram
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	FString ProgramID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	FString ProgramName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	int32 DurationWeeks = 8;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	EWorkoutGoal Goal = EWorkoutGoal::Athletic;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	EExerciseDifficulty Level = EExerciseDifficulty::Intermediate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	EPeriodization Periodization = EPeriodization::Linear;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	TArray<FWorkoutWeek> Weeks;

	/** Days per week the program requires. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Workout")
	int32 DaysPerWeek = 4;
};

/* ──────────────  ACTIVE  WORKOUT  SESSION  ───────────────────────── */

USTRUCT(BlueprintType)
struct FActiveWorkoutSession
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	FString SessionID;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	FString ProgramID;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	int32 CurrentWeek = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	int32 CurrentDay = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	int32 CurrentExerciseIndex = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	float ElapsedSeconds = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	float TotalCaloriesBurned = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	int32 ExercisesCompleted = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Workout")
	bool bIsActive = false;
};

/* ──────────  WORKOUT  PROGRAM  MANAGER  SUBSYSTEM  ───────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELWorkoutProgramManager : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── catalogue ─────────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	TArray<FWorkoutProgram> GetAllPrograms() const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	bool GetProgramByID(const FString& ProgramID, FWorkoutProgram& OutProgram) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	TArray<FWorkoutProgram> GetProgramsByGoal(EWorkoutGoal Goal) const;

	// ── active session ───────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	bool StartWorkoutSession(const FString& ProgramID, int32 WeekIndex, int32 DayIndex);

	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	void CompleteCurrentExercise(int32 ActualReps, float ActualWeight);

	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	void EndWorkoutSession();

	UFUNCTION(BlueprintPure, Category = "FEL|Workout")
	FActiveWorkoutSession GetActiveSession() const { return ActiveSession; }

	UFUNCTION(BlueprintPure, Category = "FEL|Workout")
	bool IsWorkoutActive() const { return ActiveSession.bIsActive; }

	// ── progressive overload ─────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	FExerciseSet CalculateProgressiveOverload(const FExerciseSet& Previous, EPeriodization Scheme) const;

	// ── custom workout builder ───────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Workout")
	FWorkoutProgram CreateCustomProgram(const FString& Name, EWorkoutGoal Goal, const TArray<FWorkoutDay>& Days);

private:
	void LoadCatalogues();
	void SaveUserPrograms();

	TMap<FString, FWorkoutProgram> ProgramDB;
	FActiveWorkoutSession ActiveSession;
};
