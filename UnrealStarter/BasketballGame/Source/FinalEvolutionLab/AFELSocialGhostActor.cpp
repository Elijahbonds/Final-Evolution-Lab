// Copyright (c) Final Evolution Lab.

#include "AFELSocialGhostActor.h"
#include "Components/PostProcessComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/SkeletalMesh.h"
#include "Materials/MaterialInterface.h"
#include "Internationalization/Text.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInstanceDynamic.h"

AFELSocialGhostActor::AFELSocialGhostActor()
{
	PrimaryActorTick.bCanEverTick = true;

	GhostMesh = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("GhostMesh"));
	SetRootComponent(GhostMesh);
	GhostMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	GhostMesh->CastShadow = false;
	GhostMesh->SetRenderInMainPass(true);

	PRQTag = CreateDefaultSubobject<UTextRenderComponent>(TEXT("PRQTag"));
	PRQTag->SetupAttachment(GhostMesh);
	PRQTag->SetRelativeLocation(FVector(0.f, 0.f, 228.f));
	PRQTag->SetHorizontalAlignment(EHTA_Center);
	PRQTag->SetVerticalAlignment(EVRTA_TextCenter);
	PRQTag->SetWorldSize(18.f);
	PRQTag->SetTextRenderColor(FColor(0, 255, 240, 255));
	PRQTag->SetHiddenInGame(true);
}

void AFELSocialGhostActor::SetFriendPRQDisplay(const int32 FriendPRQ)
{
	if (!PRQTag)
	{
		return;
	}
	if (FriendPRQ <= 0)
	{
		PRQTag->SetHiddenInGame(true);
		return;
	}
	PRQTag->SetText(FText::FromString(FString::Printf(TEXT("PRQ %d"), FriendPRQ)));
	PRQTag->SetHiddenInGame(false);
}

void AFELSocialGhostActor::Tick(const float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	(void)DeltaSeconds;
	if (!PRQTag || PRQTag->bHiddenInGame)
	{
		return;
	}
	if (APlayerCameraManager* PCM = UGameplayStatics::GetPlayerCameraManager(this, 0))
	{
		const FVector Cam = PCM->GetCameraLocation();
		FVector ToCam = Cam - PRQTag->GetComponentLocation();
		ToCam.Z = 0.f;
		if (!ToCam.IsNearlyZero(1.f))
		{
			PRQTag->SetWorldRotation(ToCam.Rotation());
		}
	}
}

void AFELSocialGhostActor::ApplyFriendAvatarMeshPath(const FString& Path)
{
	if (Path.IsEmpty() || !Path.StartsWith(TEXT("/")))
	{
		return;
	}
	if (USkeletalMesh* Sk = Cast<USkeletalMesh>(StaticLoadObject(USkeletalMesh::StaticClass(), nullptr, *Path)))
	{
		GhostMesh->SetSkeletalMesh(Sk);
	}

	const int32 Num = GhostMesh->GetNumMaterials();
	for (int32 i = 0; i < Num; ++i)
	{
		if (GhostTranslucentMasterMaterial)
		{
			if (UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(GhostTranslucentMasterMaterial, this))
			{
				MID->SetScalarParameterValue(TEXT("Opacity"), GhostOpacity);
				MID->SetScalarParameterValue(TEXT("EdgeIntensity"), 1.35f);
				MID->SetVectorParameterValue(TEXT("HologramTint"), FLinearColor(0.2f, 0.95f, 1.f, 1.f));
				GhostMesh->SetMaterial(i, MID);
			}
		}
		else if (UMaterialInterface* M = GhostMesh->GetMaterial(i))
		{
			if (UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(M, this))
			{
				MID->SetScalarParameterValue(TEXT("Opacity"), GhostOpacity);
				GhostMesh->SetMaterial(i, MID);
			}
		}
	}
}
