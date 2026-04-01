// Copyright (c) Final Evolution Lab.

#include "UFELAvatarSnapshotSubsystem.h"
#include "Engine/GameInstance.h"
#include "AFELAvatarSnapshotRig.h"
#include "FELBasketballCharacter.h"
#include "FELNativeBridge.h"
#include "Components/SceneCaptureComponent2D.h"
#include "Engine/TextureRenderTarget2D.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "ImageUtils.h"
#include "Serialization/MemoryWriter.h"
#include "Kismet/KismetMathLibrary.h"
#include "RenderingThread.h"

void UFELAvatarSnapshotSubsystem::CaptureAvatarPngAndSendToHost()
{
	if (UGameInstance* GI = GetGameInstance())
	{
		if (UWorld* World = GI->GetWorld())
		{
			APlayerController* PC = World->GetFirstPlayerController();
			AFELBasketballCharacter* Ch = PC ? Cast<AFELBasketballCharacter>(PC->GetPawn()) : nullptr;
			if (!Ch)
			{
				return;
			}

			FActorSpawnParameters Params;
			Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
			const FVector Focus = Ch->GetActorLocation() + FVector(0.f, 0.f, 96.f);
			const FVector CamLoc = Focus + Ch->GetActorRotation().RotateVector(CameraOffsetUU);
			const FRotator Face = UKismetMathLibrary::FindLookAtRotation(CamLoc, Focus);

			AFELAvatarSnapshotRig* Rig = World->SpawnActor<AFELAvatarSnapshotRig>(AFELAvatarSnapshotRig::StaticClass(), CamLoc, Face, Params);
			if (!Rig || !Rig->Capture)
			{
				return;
			}

			UTextureRenderTarget2D* RT = NewObject<UTextureRenderTarget2D>(Rig);
			RT->InitCustomFormat(FMath::Clamp(CaptureSize, 256, 2048), FMath::Clamp(CaptureSize, 256, 2048), PF_B8G8R8A8, false);
			RT->ClearColor = FLinearColor(0.f, 0.f, 0.f, 0.f);
			RT->UpdateResourceImmediate(true);

			USceneCaptureComponent2D* Cap = Rig->Capture;
			Cap->TextureTarget = RT;
			Cap->ShowOnlyActors.Reset();
			Cap->ShowOnlyActors.Add(Ch);
			Cap->PrimitiveRenderMode = ESceneCapturePrimitiveRenderMode::PRM_UseShowOnlyList;
			Cap->CaptureSource = SCS_FinalColorLDR;
			Cap->bCaptureEveryFrame = false;
			Cap->CaptureScene();

			FlushRenderingCommands();

			TArray<uint8> PNGData;
			FMemoryWriter Ar(PNGData);
			FImageUtils::ExportRenderTarget2DAsPNG(RT, Ar);
			if (PNGData.Num() > 0)
			{
				FELNativeBridge::NotifyAvatarSnapshotPng(PNGData);
			}

			Rig->Destroy();
		}
	}
}
