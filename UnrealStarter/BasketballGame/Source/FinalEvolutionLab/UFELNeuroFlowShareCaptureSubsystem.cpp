// Copyright (c) Final Evolution Lab.

#include "UFELNeuroFlowShareCaptureSubsystem.h"
#include "FELNativeBridge.h"
#include "HAL/PlatformFilemanager.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"

void UFELNeuroFlowShareCaptureSubsystem::RequestNeuroFlowMomentCapture(const float DurationSeconds)
{
	PendingDurationSec = FMath::Clamp(DurationSeconds, 1.f, 12.f);
	bCapturePending = true;

	// Gold Master: replace with Movie Render Queue / Media Capture output. Host saves to Photos via Swift.
	const FString Dir = FPaths::ProjectSavedDir() / TEXT("FEL") / TEXT("Exports");
	IFileManager::Get().MakeDirectory(*Dir, true);
	const FString Path = Dir / TEXT("FinalEvolution_NeuroFlow_Moment.mp4");
	TArray<uint8> Placeholder;
	Placeholder.Add(0);
	FFileHelper::SaveArrayToFile(Placeholder, *Path);

	FELNativeBridge::NotifyNeuroFlowMp4Exported(FPaths::ConvertRelativePathToFull(Path));

	bCapturePending = false;
	PendingDurationSec = 0.f;
}
