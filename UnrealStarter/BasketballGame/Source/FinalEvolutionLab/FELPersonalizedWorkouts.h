// Copyright (c) Final Evolution Lab.
// AI-powered personalized workout recommendations based on body scan data.
// Phase 5: OpenCap Body Scanning — Personalized Workouts

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELOpenCapIntegration.h"
#include "FELBiomechanicsAnalyzer.h"
#include "FELInjuryPrevention.h"
#include "FELPersonalizedWorkouts.generated.h"

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class ETrainingGoal : uint8
{
	VerticalJump    UMETA(DisplayName = "Increase Vertical Jump"),
	Speed           UMETA(DisplayName = "Improve Speed"),
	Agility         UMETA(DisplayName = "Enhance Agility"),
	Strength        UMETA(DisplayName = "Build Strength"),
	Flexibility     UMETA(DisplayName = "Improve Flexibility"),
	Endurance       UMETA(DisplayName = "Build Endurance"),
	InjuryRehab     UMETA(DisplayName = "Injury Rehabilitation"),
	GeneralFitness  UMETA(DisplayName = "General Fitness")
};

UENUM(BlueprintType)
enum class EPeriodizationPhase : uint8
{
	Foundation      UMETA(DisplayName = "Foundation"),
	StrengthPhase   UMETA(DisplayName = "Strength"),
	Power           UMETA(DisplayName = "Power"),
	Peak            UMETA(DisplayName = "Peak Performance"),
	Recovery        UMETA(DisplayName = "Active Recovery")
};

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FExercisePrescription
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString ExerciseID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString ExerciseName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	int32 Sets = 3;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	int32 Reps = 10;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	float RestSeconds = 60.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	float IntensityPercent = 70.f;  // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString Rationale;  // Why this exercise was chosen

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString AlternativeExerciseID;  // Substitute if limited
};

USTRUCT(BlueprintType)
struct FPersonalizedWorkout
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString WorkoutID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString WorkoutName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	ETrainingGoal PrimaryGoal = ETrainingGoal::GeneralFitness;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	EPeriodizationPhase Phase = EPeriodizationPhase::Foundation;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	int32 EstimatedDurationMin = 45;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	TArray<FExercisePrescription> WarmUp;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	TArray<FExercisePrescription> MainExercises;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	TArray<FExercisePrescription> CoolDown;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FDateTime GeneratedDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	TArray<FString> FocusAreas;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	TArray<FString> Limitations;
};

USTRUCT(BlueprintType)
struct FTrainingPlan
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString PlanID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	FString PlanName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	ETrainingGoal Goal = ETrainingGoal::GeneralFitness;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	int32 DurationWeeks = 8;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	int32 SessionsPerWeek = 3;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	TArray<FPersonalizedWorkout> WeeklyWorkouts;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	int32 CurrentWeek = 1;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|PersonalWorkout")
	float ProgressPercent = 0.f;
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnWorkoutGenerated, const FPersonalizedWorkout&, Workout);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnTrainingPlanCreated, const FTrainingPlan&, Plan);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELPersonalizedWorkouts : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Workout Generation ────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|PersonalWorkout")
	FPersonalizedWorkout GenerateWorkout(const FString& UserID, ETrainingGoal Goal,
		const FPerformanceMetrics& Metrics, const FInjuryRiskAssessment& RiskData);

	UFUNCTION(BlueprintCallable, Category = "FEL|PersonalWorkout")
	FTrainingPlan GenerateTrainingPlan(const FString& UserID, ETrainingGoal Goal,
		int32 DurationWeeks, int32 SessionsPerWeek,
		const FPerformanceMetrics& Metrics, const FInjuryRiskAssessment& RiskData);

	// ── Plan Management ───────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|PersonalWorkout")
	FTrainingPlan GetActivePlan(const FString& UserID) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|PersonalWorkout")
	void AdvanceToNextWeek(const FString& UserID);

	UFUNCTION(BlueprintPure, Category = "FEL|PersonalWorkout")
	FPersonalizedWorkout GetTodaysWorkout(const FString& UserID) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|PersonalWorkout")
	void RecordWorkoutCompletion(const FString& UserID, const FString& WorkoutID);

	// ── Progression ────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|PersonalWorkout")
	void AdjustIntensityBasedOnRecovery(const FString& UserID, EFatigueLevel Fatigue);

	// ── Delegates ──────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|PersonalWorkout")
	FOnWorkoutGenerated OnWorkoutGenerated;

	UPROPERTY(BlueprintAssignable, Category = "FEL|PersonalWorkout")
	FOnTrainingPlanCreated OnPlanCreated;

private:
	TMap<FString, FTrainingPlan> ActivePlans;
	TMap<FString, TArray<FString>> CompletedWorkouts;

	TArray<FExercisePrescription> GenerateWarmUpBlock(const FInjuryRiskAssessment& RiskData) const;
	TArray<FExercisePrescription> GenerateMainBlock(ETrainingGoal Goal,
		const FPerformanceMetrics& Metrics, const FInjuryRiskAssessment& RiskData) const;
	TArray<FExercisePrescription> GenerateCoolDownBlock() const;
	FString GenerateWorkoutID() const;
};
