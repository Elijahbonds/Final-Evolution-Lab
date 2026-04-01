// Copyright (c) Final Evolution Lab.

#include "FELNativeBridge.h"
#include "FELMatchTypes.h"
#include "HAL/Platform.h"

// Stubs are always linked so Unreal iOS Development builds succeed without the legacy Swift shell.
// If you host native implementations in a separate static library, remove or weak-link these.
extern "C" void FEL_IOS_PostSessionReady(const char* PathUtf8)
{
	(void)PathUtf8;
}

extern "C" void FEL_IOS_PostExitToDashboard() {}
extern "C" void FEL_IOS_PostShareEvolution() {}
extern "C" void FEL_IOS_PostUINotificationFeedback(int32 Kind)
{
	(void)Kind;
}

extern "C" void FEL_IOS_PostAvatarSnapshotPng(const void* Bytes, int32 Len)
{
	(void)Bytes;
	(void)Len;
}

extern "C" void FEL_IOS_PostNeuroFlowMp4Path(const char* PathUtf8)
{
	(void)PathUtf8;
}

extern "C" void FEL_IOS_PostShardMarketplaceHotspot(const char* HotspotUtf8, const char* CaptureUtf8)
{
	(void)HotspotUtf8;
	(void)CaptureUtf8;
}

extern "C" void FEL_IOS_PostLevelLoaded(const char* MapUtf8)
{
	(void)MapUtf8;
}

extern "C" void FEL_IOS_PostCoachPerformanceJSON(const char* JsonUtf8)
{
	(void)JsonUtf8;
}

extern "C" void FEL_IOS_PostUniversalSyncExport(const char* Base64Utf8)
{
	(void)Base64Utf8;
}

extern "C" void FEL_IOS_PostHeroMomentExportReady(float EstimatedApexInches)
{
	(void)EstimatedApexInches;
}

extern "C" void FEL_IOS_PostPenultimateStrideRhythm(int32 Phase)
{
	(void)Phase;
}

void FELNativeBridge::NotifySessionResultsReady(const FString& AbsolutePathToSessionResultsJson)
{
	FEL_IOS_PostSessionReady(TCHAR_TO_UTF8(*AbsolutePathToSessionResultsJson));
}

void FELNativeBridge::NotifyExitToDashboardRequested()
{
	FEL_IOS_PostExitToDashboard();
}

void FELNativeBridge::NotifyShareEvolutionRequested()
{
	FEL_IOS_PostShareEvolution();
}

void FELNativeBridge::NotifyAcademyTerminalEngaged()
{
	FEL_IOS_PostUINotificationFeedback(0);
}

void FELNativeBridge::NotifyAcademyModuleCompletionPulse()
{
	FEL_IOS_PostUINotificationFeedback(1);
}

void FELNativeBridge::NotifyMatchCompleteIOSFeedback(const FFELMatchResultSummary& S)
{
	const bool bDunk = S.GameModeId.Contains(TEXT("basketball_dunk"));
	if (bDunk && S.MasteryScore >= 92.0)
	{
		FEL_IOS_PostUINotificationFeedback(2);
	}
	else
	{
		FEL_IOS_PostUINotificationFeedback(3);
	}
}

void FELNativeBridge::NotifyAvatarSnapshotPng(const TArray<uint8>& PngBytes)
{
	if (PngBytes.Num() > 0)
	{
		FEL_IOS_PostAvatarSnapshotPng(PngBytes.GetData(), PngBytes.Num());
	}
}

void FELNativeBridge::NotifyNeuroFlowMp4Exported(const FString& AbsolutePathToMp4)
{
	FEL_IOS_PostNeuroFlowMp4Path(TCHAR_TO_UTF8(*AbsolutePathToMp4));
}

void FELNativeBridge::NotifyPerfectImpactHaptics(const bool bPerfectStrike)
{
	FEL_IOS_PostUINotificationFeedback(bPerfectStrike ? 5 : 4);
}

void FELNativeBridge::NotifyPerfectDunkWarpThud()
{
	FEL_IOS_PostUINotificationFeedback(6);
}

void FELNativeBridge::NotifySonicFlareApexHaptics()
{
	FEL_IOS_PostUINotificationFeedback(7);
}

void FELNativeBridge::NotifyShardMarketplaceHotspot(const FString& HotspotId, const FString& LumaCaptureId)
{
	FEL_IOS_PostShardMarketplaceHotspot(TCHAR_TO_UTF8(*HotspotId), TCHAR_TO_UTF8(*LumaCaptureId));
}

void FELNativeBridge::NotifyLevelLoaded(const FString& MapName)
{
	FEL_IOS_PostLevelLoaded(TCHAR_TO_UTF8(*MapName));
}

void FELNativeBridge::NotifyCoachPerformanceJSON(const FString& JsonUtf8)
{
	FEL_IOS_PostCoachPerformanceJSON(TCHAR_TO_UTF8(*JsonUtf8));
}

void FELNativeBridge::NotifyUniversalSyncExport(const FString& Base64Payload)
{
	FEL_IOS_PostUniversalSyncExport(TCHAR_TO_UTF8(*Base64Payload));
}

void FELNativeBridge::NotifyHeroMomentExportReady(const float EstimatedApexHeightInches)
{
#if PLATFORM_IOS
	FEL_IOS_PostHeroMomentExportReady(EstimatedApexHeightInches);
#endif
}

void FELNativeBridge::NotifyPenultimateStrideRhythm(const int32 BeatPhaseMod3)
{
	FEL_IOS_PostPenultimateStrideRhythm(BeatPhaseMod3);
}
