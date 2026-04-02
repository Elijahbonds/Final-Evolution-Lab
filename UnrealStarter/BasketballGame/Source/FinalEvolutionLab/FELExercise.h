// Copyright (c) Final Evolution Lab.
// Complete exercise data structures covering all 23 exercise categories.
// Phase 3: Exercise Animation System

#pragma once

#include "CoreMinimal.h"
#include "FELExercise.generated.h"

class UAnimMontage;
class UStaticMesh;

/* ─────────────────────────────  ENUMS  ───────────────────────────── */

UENUM(BlueprintType)
enum class EExerciseCategory : uint8
{
	WarmUp        UMETA(DisplayName = "Warm-Up"),
	Strength      UMETA(DisplayName = "Strength Training"),
	Mobility      UMETA(DisplayName = "Mobility"),
	Plyometrics   UMETA(DisplayName = "Plyometrics"),
	Recovery      UMETA(DisplayName = "Recovery / Cooldown")
};

UENUM(BlueprintType)
enum class EExerciseDifficulty : uint8
{
	Beginner      UMETA(DisplayName = "Beginner"),
	Intermediate  UMETA(DisplayName = "Intermediate"),
	Advanced      UMETA(DisplayName = "Advanced"),
	Elite         UMETA(DisplayName = "Elite")
};

UENUM(BlueprintType)
enum class EFormCheckpoint : uint8
{
	Posture       UMETA(DisplayName = "Posture"),
	Alignment     UMETA(DisplayName = "Joint Alignment"),
	Range         UMETA(DisplayName = "Range of Motion"),
	Tempo         UMETA(DisplayName = "Tempo / Cadence"),
	Breathing     UMETA(DisplayName = "Breathing")
};

/* ─────────────────────────  FORM  CHECKPOINT  ────────────────────── */

USTRUCT(BlueprintType)
struct FFormCheckpointData
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	EFormCheckpoint Type = EFormCheckpoint::Posture;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString Description;

	/** Normalised time in the animation [0-1] where this check applies. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise", meta = (ClampMin = "0", ClampMax = "1"))
	float AnimTimeNorm = 0.f;
};

/* ─────────────────────────  EXERCISE  DATA  ──────────────────────── */

USTRUCT(BlueprintType)
struct FExerciseData
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString ExerciseID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	EExerciseCategory Category = EExerciseCategory::WarmUp;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	EExerciseDifficulty Difficulty = EExerciseDifficulty::Beginner;

	/** Soft-path array to animation montages (primary + variations). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FString> AnimationPaths;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	int32 DefaultSets = 3;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	int32 DefaultReps = 10;

	/** Default duration in seconds (for timed exercises). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	float DefaultDuration = 30.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FString> MuscleGroups;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FString> Equipment;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString VideoTutorialPath;

	/** Ordered form check-points for real-time feedback. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FFormCheckpointData> FormCheckpoints;

	/** Estimated calories burned per minute at moderate intensity. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	float CaloriesPerMinute = 5.f;

	/** Which game modes this exercise ties into. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FString> RelevantGameModes;
};

/* ─────────────────  PERSONAL  RECORD  /  PROGRESS  ──────────────── */

USTRUCT(BlueprintType)
struct FExercisePersonalRecord
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	FString ExerciseID;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	int32 MaxReps = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	float MaxWeight = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	float BestDuration = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	FDateTime AchievedDate;
};

USTRUCT(BlueprintType)
struct FExerciseProgress
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	FString ExerciseID;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	int32 TotalCompletions = 0;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	float TotalCaloriesBurned = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	float TotalDurationMinutes = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	FExercisePersonalRecord PersonalRecord;

	UPROPERTY(BlueprintReadOnly, Category = "FEL|Exercise")
	FDateTime LastCompleted;
};
