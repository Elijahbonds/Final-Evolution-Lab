// Copyright (c) Final Evolution Lab.
// Injury prevention system — risk assessment, alerts, rehabilitation.
// Phase 5: OpenCap Body Scanning — Injury Prevention

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELBiomechanicsAnalyzer.h"
#include "FELInjuryPrevention.generated.h"

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class EInjuryRiskLevel : uint8
{
	Low       UMETA(DisplayName = "Low Risk"),
	Moderate  UMETA(DisplayName = "Moderate Risk"),
	High      UMETA(DisplayName = "High Risk"),
	Critical  UMETA(DisplayName = "Critical Risk")
};

UENUM(BlueprintType)
enum class EBodyRegion : uint8
{
	LeftKnee    UMETA(DisplayName = "Left Knee"),
	RightKnee   UMETA(DisplayName = "Right Knee"),
	LeftAnkle   UMETA(DisplayName = "Left Ankle"),
	RightAnkle  UMETA(DisplayName = "Right Ankle"),
	LeftHip     UMETA(DisplayName = "Left Hip"),
	RightHip    UMETA(DisplayName = "Right Hip"),
	LeftShoulder UMETA(DisplayName = "Left Shoulder"),
	RightShoulder UMETA(DisplayName = "Right Shoulder"),
	LowerBack   UMETA(DisplayName = "Lower Back"),
	UpperBack   UMETA(DisplayName = "Upper Back"),
	Neck        UMETA(DisplayName = "Neck"),
	LeftWrist   UMETA(DisplayName = "Left Wrist"),
	RightWrist  UMETA(DisplayName = "Right Wrist")
};

UENUM(BlueprintType)
enum class EFatigueLevel : uint8
{
	Fresh       UMETA(DisplayName = "Fresh"),
	Mild        UMETA(DisplayName = "Mildly Fatigued"),
	Moderate    UMETA(DisplayName = "Moderately Fatigued"),
	High        UMETA(DisplayName = "Highly Fatigued"),
	Exhausted   UMETA(DisplayName = "Exhausted")
};

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FInjuryRiskFactor
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	EBodyRegion Region;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	EInjuryRiskLevel RiskLevel = EInjuryRiskLevel::Low;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	float RiskScore = 0.f;  // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	TArray<FString> ContributingFactors;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	TArray<FString> PreventiveMeasures;
};

USTRUCT(BlueprintType)
struct FInjuryRiskAssessment
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FString UserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FDateTime AssessmentDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	float OverallRiskScore = 0.f;  // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	EInjuryRiskLevel OverallRiskLevel = EInjuryRiskLevel::Low;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	TArray<FInjuryRiskFactor> RiskFactors;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	EFatigueLevel CurrentFatigue = EFatigueLevel::Fresh;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	TArray<FString> WarmUpRecommendations;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	TArray<FString> MobilityRecommendations;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	TArray<FString> CorrectiveExercises;
};

USTRUCT(BlueprintType)
struct FInjuryHistoryEntry
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	EBodyRegion Region;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FString Description;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FDateTime InjuryDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FDateTime RecoveryDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	bool bFullyRecovered = false;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	float RecoveryProgress = 0.f;  // 0-100
};

USTRUCT(BlueprintType)
struct FInjuryPreventionAlert
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	EInjuryRiskLevel AlertLevel = EInjuryRiskLevel::Moderate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FString Title;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FString Message;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	FString RecommendedAction;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Injury")
	bool bShouldStopWorkout = false;
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnInjuryAlertTriggered, const FInjuryPreventionAlert&, Alert);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFatigueChanged, EFatigueLevel, NewLevel);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnRiskAssessmentComplete, const FInjuryRiskAssessment&, Assessment);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELInjuryPrevention : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Risk Assessment ───────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Injury")
	FInjuryRiskAssessment PerformRiskAssessment(const FString& UserID,
		const TArray<FMovementAnalysisResult>& MovementResults,
		const FPerformanceMetrics& Metrics);

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	FInjuryRiskAssessment GetLatestAssessment(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	EInjuryRiskLevel GetCurrentRiskLevel(const FString& UserID) const;

	// ── Fatigue Tracking ───────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Injury")
	void UpdateFatigueLevel(const FString& UserID, float WorkoutDurationMin, float Intensity);

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	EFatigueLevel GetFatigueLevel(const FString& UserID) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Injury")
	void ResetFatigue(const FString& UserID);

	// ── Injury History ─────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Injury")
	void RecordInjury(const FString& UserID, const FInjuryHistoryEntry& Entry);

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	TArray<FInjuryHistoryEntry> GetInjuryHistory(const FString& UserID) const;

	UFUNCTION(BlueprintCallable, Category = "FEL|Injury")
	void UpdateRecoveryProgress(const FString& UserID, EBodyRegion Region, float Progress);

	// ── Recommendations ───────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	TArray<FString> GetWarmUpRoutine(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	TArray<FString> GetMobilityRecommendations(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	TArray<FString> GetCorrectiveExercises(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|Injury")
	bool ShouldTakeRestDay(const FString& UserID) const;

	// ── Alerts ─────────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Injury")
	void CheckAndTriggerAlerts(const FString& UserID);

	UPROPERTY(BlueprintAssignable, Category = "FEL|Injury")
	FOnInjuryAlertTriggered OnAlertTriggered;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Injury")
	FOnFatigueChanged OnFatigueChanged;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Injury")
	FOnRiskAssessmentComplete OnAssessmentComplete;

private:
	TMap<FString, FInjuryRiskAssessment> LatestAssessments;
	TMap<FString, EFatigueLevel> FatigueLevels;
	TMap<FString, TArray<FInjuryHistoryEntry>> InjuryHistories;
	TMap<FString, float> CumulativeFatigue; // 0-100

	FInjuryRiskFactor AssessRegionRisk(EBodyRegion Region,
		const TArray<FMovementAnalysisResult>& Results,
		const TArray<FInjuryHistoryEntry>& History) const;
	EInjuryRiskLevel ScoreToRiskLevel(float Score) const;
	TArray<FString> GenerateWarmUp(const FInjuryRiskAssessment& Assessment) const;
	TArray<FString> GenerateMobilityWork(const FInjuryRiskAssessment& Assessment) const;
	TArray<FString> GenerateCorrectiveExercises(const FInjuryRiskAssessment& Assessment) const;
};
