// Copyright (c) Final Evolution Lab.
// Real-time form correction AI — compares user biomechanics to ideal.
// Phase 5: OpenCap Body Scanning — Form Correction

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELOpenCapIntegration.h"
#include "FELBiomechanicsAnalyzer.h"
#include "FELFormCorrectionAI.generated.h"

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class EFormFeedbackType : uint8
{
	VisualOverlay   UMETA(DisplayName = "Visual Overlay"),
	AudioCue        UMETA(DisplayName = "Audio Cue"),
	HapticFeedback  UMETA(DisplayName = "Haptic Feedback"),
	TextInstruction UMETA(DisplayName = "Text Instruction"),
	VideoDemo       UMETA(DisplayName = "Video Demo")
};

UENUM(BlueprintType)
enum class ECorrectionSeverity : uint8
{
	Info        UMETA(DisplayName = "Info"),
	Minor       UMETA(DisplayName = "Minor"),
	Moderate    UMETA(DisplayName = "Moderate"),
	Critical    UMETA(DisplayName = "Critical")
};

UENUM(BlueprintType)
enum class ECorrectionCategory : uint8
{
	JointAngle      UMETA(DisplayName = "Joint Angle"),
	MovementTempo   UMETA(DisplayName = "Movement Tempo"),
	RangeOfMotion   UMETA(DisplayName = "Range of Motion"),
	Balance         UMETA(DisplayName = "Balance & Stability"),
	Breathing       UMETA(DisplayName = "Breathing Pattern")
};

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FFormCorrection
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FString JointName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	ECorrectionCategory Category = ECorrectionCategory::JointAngle;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	ECorrectionSeverity Severity = ECorrectionSeverity::Minor;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FString Message;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FString AudioCueID;

	/** Current angle vs ideal angle deviation in degrees. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	float DeviationDegrees = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FVector CorrectionDirection = FVector::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	float Confidence = 0.f;
};

USTRUCT(BlueprintType)
struct FFormCorrectionSession
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FString ExerciseID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	float OverallFormScore = 0.f;  // 0-100

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	int32 TotalReps = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	int32 PerfectReps = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	TArray<FFormCorrection> ActiveCorrections;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	TArray<FFormCorrection> HistoricalCorrections;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FDateTime SessionStart;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	bool bIsActive = false;
};

USTRUCT(BlueprintType)
struct FIdealFormData
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	FString ExerciseID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	TMap<FString, float> IdealJointAngles;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	float IdealTempoBPM = 60.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FormAI")
	float AngleToleranceDegrees = 15.f;
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFormCorrectionIssued, const FFormCorrection&, Correction);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnFormScoreUpdated, float, NewScore);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnPerfectRepAchieved);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELFormCorrectionAI : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Session Management ─────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	void StartCorrectionSession(const FString& ExerciseID);

	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	void EndCorrectionSession();

	UFUNCTION(BlueprintPure, Category = "FEL|FormAI")
	bool IsSessionActive() const { return CurrentSession.bIsActive; }

	UFUNCTION(BlueprintPure, Category = "FEL|FormAI")
	FFormCorrectionSession GetCurrentSession() const { return CurrentSession; }

	// ── Real-time Analysis ─────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	TArray<FFormCorrection> AnalyzeFrame(const FOpenCapSkeletonFrame& Frame);

	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	void ProcessRepCompletion();

	UFUNCTION(BlueprintPure, Category = "FEL|FormAI")
	float GetCurrentFormScore() const { return CurrentSession.OverallFormScore; }

	// ── Feedback Control ───────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	void SetEnabledFeedbackTypes(const TArray<EFormFeedbackType>& Types);

	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	void SetSensitivity(float Sensitivity); // 0.0=lenient, 1.0=strict

	// ── Ideal Form Data ────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|FormAI")
	void LoadIdealFormForExercise(const FString& ExerciseID);

	// ── Delegates ──────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|FormAI")
	FOnFormCorrectionIssued OnCorrectionIssued;

	UPROPERTY(BlueprintAssignable, Category = "FEL|FormAI")
	FOnFormScoreUpdated OnFormScoreUpdated;

	UPROPERTY(BlueprintAssignable, Category = "FEL|FormAI")
	FOnPerfectRepAchieved OnPerfectRep;

private:
	FFormCorrectionSession CurrentSession;
	FIdealFormData CurrentIdealForm;

	TArray<EFormFeedbackType> EnabledFeedback;
	float CorrectionSensitivity = 0.5f;

	/** Ideal form database keyed by ExerciseID. */
	TMap<FString, FIdealFormData> IdealFormDB;

	void InitializeIdealFormDatabase();
	FFormCorrection EvaluateJoint(const FString& JointName, float CurrentAngle, float IdealAngle) const;
};
