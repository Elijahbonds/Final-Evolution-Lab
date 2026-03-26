// Copyright (c) Final Evolution Lab.

#include "AFELAvatarSnapshotRig.h"
#include "Components/SceneCaptureComponent2D.h"

AFELAvatarSnapshotRig::AFELAvatarSnapshotRig()
{
	PrimaryActorTick.bCanEverTick = false;
	Capture = CreateDefaultSubobject<USceneCaptureComponent2D>(TEXT("Capture"));
	SetRootComponent(Capture);
	Capture->bCaptureEveryFrame = false;
	Capture->bCaptureOnMovement = false;
}
