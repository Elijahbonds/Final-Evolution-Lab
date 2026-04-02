// Copyright (c) Final Evolution Lab.
// OpenCap markerless motion capture integration implementation.
// Phase 5: OpenCap Body Scanning

#include "FELOpenCapIntegration.h"
#include "TimerManager.h"
#include "Misc/Guid.h"
#include "JsonObjectConverter.h"

void UFELOpenCapIntegration::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);
	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Integration subsystem initialized."));
}

void UFELOpenCapIntegration::Deinitialize()
{
	ActiveSessions.Empty();
	CachedMetrics.Empty();
	ScanHistory.Empty();
	Super::Deinitialize();
}

/* ─────────────  Session Management  ─────────────────────────────── */

FString UFELOpenCapIntegration::StartNewSession(const FString& UserID, EBodyScanType ScanType)
{
	FString SessionID = GenerateSessionID();

	FOpenCapSessionData Session;
	Session.SessionID     = SessionID;
	Session.UserID        = UserID;
	Session.CaptureDate   = FDateTime::UtcNow();
	Session.ScanType      = ScanType;
	Session.Status        = EOpenCapSessionStatus::Idle;

	ActiveSessions.Add(SessionID, Session);
	CalibrationStates.Add(SessionID, ECalibrationStatus::NotStarted);

	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] New session started: %s for user %s"), *SessionID, *UserID);
	OnStatusChanged.Broadcast(SessionID, EOpenCapSessionStatus::Idle);
	return SessionID;
}

bool UFELOpenCapIntegration::CancelSession(const FString& SessionID)
{
	if (!ActiveSessions.Contains(SessionID)) return false;

	ActiveSessions[SessionID].Status = EOpenCapSessionStatus::Failed;
	OnStatusChanged.Broadcast(SessionID, EOpenCapSessionStatus::Failed);
	ActiveSessions.Remove(SessionID);
	CalibrationStates.Remove(SessionID);

	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Session cancelled: %s"), *SessionID);
	return true;
}

EOpenCapSessionStatus UFELOpenCapIntegration::GetSessionStatus(const FString& SessionID) const
{
	if (const FOpenCapSessionData* S = ActiveSessions.Find(SessionID))
	{
		return S->Status;
	}
	return EOpenCapSessionStatus::Idle;
}

float UFELOpenCapIntegration::GetProcessingProgress(const FString& SessionID) const
{
	if (const FOpenCapSessionData* S = ActiveSessions.Find(SessionID))
	{
		return S->ProcessingProgress;
	}
	return 0.f;
}

/* ─────────────  Video Upload  ───────────────────────────────────── */

bool UFELOpenCapIntegration::UploadVideoForProcessing(const FString& SessionID,
	const FString& FrontVideoPath, const FString& SideVideoPath)
{
	if (!ActiveSessions.Contains(SessionID)) return false;

	FOpenCapSessionData& Session = ActiveSessions[SessionID];

	// Validate paths
	if (!FPaths::FileExists(FrontVideoPath) || !FPaths::FileExists(SideVideoPath))
	{
		UE_LOG(LogTemp, Error, TEXT("[FEL-OpenCap] Video file(s) not found."));
		return false;
	}

	Session.CameraCount = 2;
	Session.Status = EOpenCapSessionStatus::Uploading;
	OnStatusChanged.Broadcast(SessionID, EOpenCapSessionStatus::Uploading);

	// Build multipart upload request to OpenCap API
	// POST {API_BASE_URL}/sessions/{SessionID}/upload
	FString URL = FString::Printf(TEXT("%s/sessions/%s/upload"), FELOpenCapConstants::API_BASE_URL, *SessionID);

	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Uploading 2 videos for session %s"), *SessionID);

	// In production, this would use FHttpModule to send the multipart request.
	// For now, simulate the upload completion and transition to Processing.
	Session.Status = EOpenCapSessionStatus::Processing;
	Session.ProcessingProgress = 0.f;
	OnStatusChanged.Broadcast(SessionID, EOpenCapSessionStatus::Processing);

	// Start polling for results
	if (UWorld* World = GetGameInstance()->GetWorld())
	{
		World->GetTimerManager().SetTimer(
			PollTimerHandle, this, &UFELOpenCapIntegration::PollProcessingStatus, 5.0f, true);
	}

	return true;
}

bool UFELOpenCapIntegration::UploadSingleVideo(const FString& SessionID,
	const FString& VideoPath, int32 CameraIndex)
{
	if (!ActiveSessions.Contains(SessionID)) return false;
	if (!FPaths::FileExists(VideoPath)) return false;

	FOpenCapSessionData& Session = ActiveSessions[SessionID];
	Session.CameraCount = FMath::Max(Session.CameraCount, CameraIndex + 1);

	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Uploaded camera %d video for session %s"), CameraIndex, *SessionID);
	return true;
}

/* ─────────────  Calibration  ────────────────────────────────────── */

bool UFELOpenCapIntegration::StartCalibration(const FString& SessionID)
{
	if (!ActiveSessions.Contains(SessionID)) return false;

	CalibrationStates[SessionID] = ECalibrationStatus::InProgress;
	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Calibration started for session %s"), *SessionID);

	// Simulate calibration success
	CalibrationStates[SessionID] = ECalibrationStatus::Calibrated;
	return true;
}

ECalibrationStatus UFELOpenCapIntegration::GetCalibrationStatus(const FString& SessionID) const
{
	if (const ECalibrationStatus* S = CalibrationStates.Find(SessionID))
	{
		return *S;
	}
	return ECalibrationStatus::NotStarted;
}

/* ─────────────  Results  ────────────────────────────────────────── */

FOpenCapSessionData UFELOpenCapIntegration::GetSessionData(const FString& SessionID) const
{
	if (const FOpenCapSessionData* S = ActiveSessions.Find(SessionID))
	{
		return *S;
	}
	return FOpenCapSessionData();
}

TArray<FOpenCapSkeletonFrame> UFELOpenCapIntegration::GetSkeletonFrames(const FString& SessionID) const
{
	if (const FOpenCapSessionData* S = ActiveSessions.Find(SessionID))
	{
		return S->SkeletonFrames;
	}
	return TArray<FOpenCapSkeletonFrame>();
}

FBodyMetrics UFELOpenCapIntegration::GetBodyMetrics(const FString& UserID) const
{
	if (const FBodyMetrics* M = CachedMetrics.Find(UserID))
	{
		return *M;
	}
	return FBodyMetrics();
}

TArray<FOpenCapSessionData> UFELOpenCapIntegration::GetScanHistory(const FString& UserID) const
{
	if (const TArray<FOpenCapSessionData>* H = ScanHistory.Find(UserID))
	{
		return *H;
	}
	return TArray<FOpenCapSessionData>();
}

/* ─────────────  Connection  ─────────────────────────────────────── */

bool UFELOpenCapIntegration::TestConnection()
{
	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Testing connection to %s"), FELOpenCapConstants::API_BASE_URL);
	// In production: GET {API_BASE_URL}/health
	return !APIKey.IsEmpty();
}

void UFELOpenCapIntegration::SetAPIKey(const FString& Key)
{
	APIKey = Key;
	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] API key updated."));
}

/* ─────────────  Internal  ───────────────────────────────────────── */

void UFELOpenCapIntegration::PollProcessingStatus()
{
	for (auto& Pair : ActiveSessions)
	{
		FOpenCapSessionData& Session = Pair.Value;
		if (Session.Status != EOpenCapSessionStatus::Processing) continue;

		// Simulate progress advancement
		Session.ProcessingProgress = FMath::Min(Session.ProcessingProgress + 10.f, 100.f);
		OnProgress.Broadcast(Session.SessionID, Session.ProcessingProgress);

		if (Session.ProcessingProgress >= 100.f)
		{
			Session.Status = EOpenCapSessionStatus::Analyzing;
			OnStatusChanged.Broadcast(Session.SessionID, EOpenCapSessionStatus::Analyzing);

			// Extract metrics and complete
			FBodyMetrics Metrics = ExtractBodyMetrics(Session.SkeletonFrames);
			CachedMetrics.Add(Session.UserID, Metrics);
			OnMetricsUpdated.Broadcast(Metrics);

			Session.Status = EOpenCapSessionStatus::Complete;
			OnStatusChanged.Broadcast(Session.SessionID, EOpenCapSessionStatus::Complete);
			OnScanComplete.Broadcast(Session);

			// Archive to history
			if (!ScanHistory.Contains(Session.UserID))
			{
				ScanHistory.Add(Session.UserID, TArray<FOpenCapSessionData>());
			}
			ScanHistory[Session.UserID].Add(Session);

			UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Session %s complete."), *Session.SessionID);
		}
	}

	// Stop timer if no active processing sessions
	bool bAnyProcessing = false;
	for (const auto& Pair : ActiveSessions)
	{
		if (Pair.Value.Status == EOpenCapSessionStatus::Processing)
		{
			bAnyProcessing = true;
			break;
		}
	}
	if (!bAnyProcessing)
	{
		if (UWorld* World = GetGameInstance()->GetWorld())
		{
			World->GetTimerManager().ClearTimer(PollTimerHandle);
		}
	}
}

void UFELOpenCapIntegration::ProcessOpenCapResponse(const FString& SessionID, const FString& ResponseJSON)
{
	// In production: parse OpenCap JSON response into skeleton frames
	UE_LOG(LogTemp, Log, TEXT("[FEL-OpenCap] Processing response for session %s"), *SessionID);
}

FBodyMetrics UFELOpenCapIntegration::ExtractBodyMetrics(const TArray<FOpenCapSkeletonFrame>& Frames) const
{
	FBodyMetrics Metrics;
	// In production: compute anthropometric measurements from 3D skeleton data
	// For now, return reasonable placeholder values
	Metrics.HeightCm       = 178.0f;
	Metrics.WingspanCm     = 182.0f;
	Metrics.StandingReachCm = 230.0f;
	Metrics.LegLengthCm    = 85.0f;
	Metrics.TorsoLengthCm  = 50.0f;
	Metrics.ShoulderWidthCm = 45.0f;
	Metrics.HipWidthCm     = 35.0f;
	return Metrics;
}

FString UFELOpenCapIntegration::GenerateSessionID() const
{
	return FString::Printf(TEXT("OCAP-%s"), *FGuid::NewGuid().ToString(EGuidFormats::Short));
}
