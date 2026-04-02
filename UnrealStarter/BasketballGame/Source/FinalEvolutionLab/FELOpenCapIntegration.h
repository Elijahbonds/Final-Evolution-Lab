// Copyright (c) Final Evolution Lab.
// OpenCap markerless motion capture integration for body scanning.
// Phase 5: OpenCap Body Scanning

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELOpenCapIntegration.generated.h"

/* ─────────────────────────  CONSTANTS  ──────────────────────────── */

namespace FELOpenCapConstants
{
	/** OpenCap API base URL. */
	static const TCHAR* API_BASE_URL = TEXT("https://api.opencap.ai/v1");

	/** Minimum number of camera angles required. */
	constexpr int32 MIN_CAMERA_ANGLES = 2;

	/** Maximum processing time before timeout (seconds). */
	constexpr float MAX_PROCESSING_TIME_SEC = 300.0f;

	/** Minimum video duration for reliable analysis (seconds). */
	constexpr float MIN_VIDEO_DURATION_SEC = 10.0f;

	/** Maximum video duration (seconds). */
	constexpr float MAX_VIDEO_DURATION_SEC = 60.0f;

	/** Recommended recording FPS. */
	constexpr int32 RECOMMENDED_FPS = 60;
}

/* ─────────────────────────  ENUMS  ──────────────────────────────── */

UENUM(BlueprintType)
enum class EOpenCapSessionStatus : uint8
{
	Idle            UMETA(DisplayName = "Idle"),
	Recording       UMETA(DisplayName = "Recording"),
	Uploading       UMETA(DisplayName = "Uploading"),
	Processing      UMETA(DisplayName = "Processing"),
	Analyzing       UMETA(DisplayName = "Analyzing"),
	Complete        UMETA(DisplayName = "Complete"),
	Failed          UMETA(DisplayName = "Failed")
};

UENUM(BlueprintType)
enum class ECalibrationStatus : uint8
{
	NotStarted      UMETA(DisplayName = "Not Started"),
	InProgress      UMETA(DisplayName = "In Progress"),
	Calibrated      UMETA(DisplayName = "Calibrated"),
	Failed          UMETA(DisplayName = "Failed")
};

UENUM(BlueprintType)
enum class EBodyScanType : uint8
{
	FullBody        UMETA(DisplayName = "Full Body"),
	UpperBody       UMETA(DisplayName = "Upper Body"),
	LowerBody       UMETA(DisplayName = "Lower Body"),
	SpecificJoint   UMETA(DisplayName = "Specific Joint")
};

/* ─────────────────────────  DATA STRUCTS  ───────────────────────── */

USTRUCT(BlueprintType)
struct FOpenCapJointData
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	FString JointName;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	FVector Position = FVector::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	FRotator Rotation = FRotator::ZeroRotator;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float Confidence = 0.f;
};

USTRUCT(BlueprintType)
struct FOpenCapSkeletonFrame
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float Timestamp = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	TArray<FOpenCapJointData> Joints;
};

USTRUCT(BlueprintType)
struct FOpenCapSessionData
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	FString SessionID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	FString UserID;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	FDateTime CaptureDate;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	EBodyScanType ScanType = EBodyScanType::FullBody;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	EOpenCapSessionStatus Status = EOpenCapSessionStatus::Idle;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float ProcessingProgress = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	TArray<FOpenCapSkeletonFrame> SkeletonFrames;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	int32 CameraCount = 0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float VideoDurationSec = 0.f;
};

USTRUCT(BlueprintType)
struct FBodyMetrics
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float HeightCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float WingspanCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float StandingReachCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float LegLengthCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float TorsoLengthCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float ShoulderWidthCm = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|OpenCap")
	float HipWidthCm = 0.f;
};

/* ─────────────────────  DELEGATES  ──────────────────────────────── */

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnOpenCapStatusChanged, const FString&, SessionID, EOpenCapSessionStatus, NewStatus);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnOpenCapProgress, const FString&, SessionID, float, Progress);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnBodyScanComplete, const FOpenCapSessionData&, ScanData);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnBodyMetricsUpdated, const FBodyMetrics&, Metrics);

/* ─────────────────────  SUBSYSTEM  ──────────────────────────────── */

UCLASS()
class FINALEVOLUTIONLAB_API UFELOpenCapIntegration : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	// ── Session Management ─────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	FString StartNewSession(const FString& UserID, EBodyScanType ScanType = EBodyScanType::FullBody);

	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	bool CancelSession(const FString& SessionID);

	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	EOpenCapSessionStatus GetSessionStatus(const FString& SessionID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	float GetProcessingProgress(const FString& SessionID) const;

	// ── Video Upload ───────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	bool UploadVideoForProcessing(const FString& SessionID, const FString& FrontVideoPath, const FString& SideVideoPath);

	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	bool UploadSingleVideo(const FString& SessionID, const FString& VideoPath, int32 CameraIndex);

	// ── Calibration ────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	bool StartCalibration(const FString& SessionID);

	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	ECalibrationStatus GetCalibrationStatus(const FString& SessionID) const;

	// ── Results ────────────────────────────────────────────────────
	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	FOpenCapSessionData GetSessionData(const FString& SessionID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	TArray<FOpenCapSkeletonFrame> GetSkeletonFrames(const FString& SessionID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	FBodyMetrics GetBodyMetrics(const FString& UserID) const;

	UFUNCTION(BlueprintPure, Category = "FEL|OpenCap")
	TArray<FOpenCapSessionData> GetScanHistory(const FString& UserID) const;

	// ── Connection ─────────────────────────────────────────────────
	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	bool TestConnection();

	UFUNCTION(BlueprintCallable, Category = "FEL|OpenCap")
	void SetAPIKey(const FString& Key);

	// ── Delegates ──────────────────────────────────────────────────
	UPROPERTY(BlueprintAssignable, Category = "FEL|OpenCap")
	FOnOpenCapStatusChanged OnStatusChanged;

	UPROPERTY(BlueprintAssignable, Category = "FEL|OpenCap")
	FOnOpenCapProgress OnProgress;

	UPROPERTY(BlueprintAssignable, Category = "FEL|OpenCap")
	FOnBodyScanComplete OnScanComplete;

	UPROPERTY(BlueprintAssignable, Category = "FEL|OpenCap")
	FOnBodyMetricsUpdated OnMetricsUpdated;

private:
	/** Active sessions keyed by SessionID. */
	TMap<FString, FOpenCapSessionData> ActiveSessions;

	/** Cached body metrics keyed by UserID. */
	TMap<FString, FBodyMetrics> CachedMetrics;

	/** Scan history keyed by UserID. */
	TMap<FString, TArray<FOpenCapSessionData>> ScanHistory;

	/** OpenCap API key. */
	FString APIKey;

	/** Calibration state per session. */
	TMap<FString, ECalibrationStatus> CalibrationStates;

	/** Timer handle for polling processing status. */
	FTimerHandle PollTimerHandle;

	// ── Internal ───────────────────────────────────────────────────
	void PollProcessingStatus();
	void ProcessOpenCapResponse(const FString& SessionID, const FString& ResponseJSON);
	FBodyMetrics ExtractBodyMetrics(const TArray<FOpenCapSkeletonFrame>& Frames) const;
	FString GenerateSessionID() const;
};
