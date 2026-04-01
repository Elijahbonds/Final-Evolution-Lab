// Copyright (c) Final Evolution Lab.
// Data types for the 3D animated exercise catalog system.

#pragma once

#include "CoreMinimal.h"
#include "FELExerciseCatalogTypes.generated.h"

class USkeletalMesh;
class UAnimMontage;
class UAnimInstance;

UENUM(BlueprintType)
enum class EFELExerciseCategory : uint8
{
	WarmUp         UMETA(DisplayName = "Warm-Up & Activation"),
	Strength       UMETA(DisplayName = "Strength & Power"),
	Mobility       UMETA(DisplayName = "Mobility & Flexibility"),
	SportSpecific  UMETA(DisplayName = "Sport-Specific Drills"),
	Recovery       UMETA(DisplayName = "Recovery & Cooldown"),
};

USTRUCT(BlueprintType)
struct FFELExerciseDefinition
{
	GENERATED_BODY()

	/** Unique exercise identifier (matches ExerciseCatalog.json). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString ExerciseId;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	EFELExerciseCategory Category = EFELExerciseCategory::WarmUp;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FString> TargetMuscles;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	int32 DurationSeconds = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	int32 Reps = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	int32 Sets = 1;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise", meta = (ClampMin = "0", ClampMax = "1"))
	float Difficulty = 0.5f;

	/** Soft reference to the AnimMontage for 3D demonstration. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TSoftObjectPtr<UAnimMontage> AnimMontage;

	/** Soft reference to the skeletal mesh for the demonstrator avatar. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TSoftObjectPtr<USkeletalMesh> DemonstratorMesh;

	/** PRQ benefit area (matches readiness snapshot field). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	FString PRQBenefit;

	/** Which game modes benefit from this exercise. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Exercise")
	TArray<FString> SportRelevance;
};

USTRUCT(BlueprintType)
struct FFELExerciseSession
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly) FString SessionId;
	UPROPERTY(BlueprintReadOnly) TArray<FString> ExerciseIds;
	UPROPERTY(BlueprintReadOnly) int32 CurrentExerciseIndex = 0;
	UPROPERTY(BlueprintReadOnly) float SessionDurationSeconds = 0.f;
	UPROPERTY(BlueprintReadOnly) int32 ExercisesCompleted = 0;
	UPROPERTY(BlueprintReadOnly) float EstimatedPRQGain = 0.f;
};
