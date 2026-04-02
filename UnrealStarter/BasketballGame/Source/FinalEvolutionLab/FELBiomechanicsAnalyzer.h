// Copyright (c) Final Evolution Lab.
// Biomechanical analysis system — processes OpenCap skeleton data.
// Phase 5: OpenCap Body Scanning — Biomechanics Analyzer

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELOpenCapIntegration.h"
#include "FELBiomechanicsAnalyzer.generated.h"

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class EROMGrade : uint8
{
	Excellent   UMETA(DisplayName = "Excellent"),
	Good        UMETA(DisplayName = "Good"),
	Average     UMETA(DisplayName = "Average"),
	BelowAvg    UMETA(DisplayName = "Below Average"),
	Poor        UMETA(DisplayName = "Poor")
};

UENUM(BlueprintType)
enum class EMovementPattern : uint8
{
	Squat           UMETA(DisplayName = "Squat"),
	Jump            UMETA(DisplayName = "Jump"),
	Landing         UMETA(DisplayName = "Landing"),
	Sprint          UMETA(DisplayName = "Sprint"),
	ShootingForm    UMETA(DisplayName = "Shooting Form"),
	DefensiveSlide  UMETA(DisplayName = "Defensive Slide"),
	LateralCut      UMETA(DisplayName = "Lateral Cut"),
	OverheadReach   UMETA(DisplayName = "Overhead Reach"),
	Custom          UMETA(DisplayName = "Custom")
};

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FJointAnalysisResult
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	FString JointName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float MinAngle = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float MaxAngle = 0.f;

	/** Range of motion. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float ROM = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	EROMGrade Grade = EROMGrade::Average;

	/** Asymmetry percentage vs opposite side (0 = perfectly symmetric). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float AsymmetryPercent = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	FString LimitationNote;
};

USTRUCT(BlueprintType)
struct FMovementAnalysisResult
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	EMovementPattern Pattern = EMovementPattern::Custom;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float OverallScore = 0.f;   // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	TArray<FJointAnalysisResult> JointResults;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	TArray<FString> Compensations;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	TArray<FString> Strengths;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	TArray<FString> Recommendations;
};

USTRUCT(BlueprintType)
struct FPerformanceMetrics
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float VerticalJumpCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float SprintSpeedMPS = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float AgilityScore = 0.f;     // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float PowerOutput = 0.f;      // Watts

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float EnduranceCapacity = 0.f; // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float FlexibilityScore = 0.f;  // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Biomechanics")
	float BalanceScore = 0.f;      // 0-100
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnAnalysisComplete, const FMovementAnalysisResult&, Result);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnPerformanceMetricsReady, const FPerformanceMetrics&, Metrics);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELBiomechanicsAnalyzer : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Joint Analysis ─────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	TArray<FJointAnalysisResult> AnalyzeJointROM(const TArray<FOpenCapSkeletonFrame>& Frames);

	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FJointAnalysisResult AnalyzeSingleJoint(const FString& JointName, const TArray<FOpenCapSkeletonFrame>& Frames);

	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	TArray<FString> DetectAsymmetries(const TArray<FOpenCapSkeletonFrame>& Frames, float ThresholdPercent = 10.f);

	// ── Movement Pattern Analysis ──────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FMovementAnalysisResult AnalyzeMovementPattern(EMovementPattern Pattern,
		const TArray<FOpenCapSkeletonFrame>& Frames);

	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FMovementAnalysisResult AnalyzeSquat(const TArray<FOpenCapSkeletonFrame>& Frames);

	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FMovementAnalysisResult AnalyzeJumpMechanics(const TArray<FOpenCapSkeletonFrame>& Frames);

	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FMovementAnalysisResult AnalyzeShootingForm(const TArray<FOpenCapSkeletonFrame>& Frames);

	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FMovementAnalysisResult AnalyzeRunningGait(const TArray<FOpenCapSkeletonFrame>& Frames);

	// ── Performance Metrics ────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	FPerformanceMetrics CalculatePerformanceMetrics(const TArray<FOpenCapSkeletonFrame>& Frames,
		const FBodyMetrics& BodyMetrics);

	UFUNCTION(BlueprintPure, Category = "FEL|Biomechanics")
	FPerformanceMetrics GetLatestPerformanceMetrics(const FString& UserID) const;

	// ── Comparison ─────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|Biomechanics")
	TMap<FString, float> CompareScansOverTime(const FString& UserID);

	// ── Delegates ──────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|Biomechanics")
	FOnAnalysisComplete OnAnalysisComplete;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Biomechanics")
	FOnPerformanceMetricsReady OnPerformanceMetricsReady;

private:
	/** Cached performance metrics per user. */
	TMap<FString, FPerformanceMetrics> PerformanceCache;

	/** Ideal joint angles for comparison. */
	TMap<FString, float> IdealJointAngles;

	void InitializeIdealAngles();
	EROMGrade GradeROM(const FString& JointName, float ROM) const;
	float CalculateJointAngle(const FOpenCapJointData& Parent, const FOpenCapJointData& Joint, const FOpenCapJointData& Child) const;
};
