// Copyright (c) Final Evolution Lab.

#include "AFELVaultHologramTerminalActor.h"
#include "UFELBrandInjectionSubsystem.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Components/TextRenderComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/Pawn.h"
#include "Kismet/GameplayStatics.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

namespace
{
FColor FEL_TierWelcomeColor(const FString& Tier)
{
	if (Tier.Contains(TEXT("diamond"), ESearchCase::IgnoreCase))
	{
		return FColor(220, 245, 255, 255);
	}
	if (Tier.Contains(TEXT("gold"), ESearchCase::IgnoreCase))
	{
		return FColor(255, 215, 120, 255);
	}
	return FColor(0, 240, 255, 255);
}
}

AFELVaultHologramTerminalActor::AFELVaultHologramTerminalActor()
{
	PrimaryActorTick.bCanEverTick = true;

	HologramRoot = CreateDefaultSubobject<USceneComponent>(TEXT("HologramRoot"));
	SetRootComponent(HologramRoot);

	CardPlane0 = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CardPlane0"));
	CardPlane1 = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CardPlane1"));
	CardPlane2 = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("CardPlane2"));

	static ConstructorHelpers::FObjectFinder<UStaticMesh> PlaneAsset(
		TEXT("/Engine/BasicShapes/Plane.Plane"));
	UStaticMesh* PlaneMesh = PlaneAsset.Succeeded() ? PlaneAsset.Object : nullptr;

	UStaticMeshComponent* const Planes[3] = {CardPlane0, CardPlane1, CardPlane2};
	for (UStaticMeshComponent* P : Planes)
	{
		P->SetupAttachment(HologramRoot);
		if (PlaneMesh)
		{
			P->SetStaticMesh(PlaneMesh);
		}
		P->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		P->SetRelativeScale3D(FVector(0.35f, 0.5f, 1.f));
	}

	CardPlane0->SetRelativeLocation(FVector(0.f, -140.f, 110.f));
	CardPlane1->SetRelativeLocation(FVector(0.f, 0.f, 110.f));
	CardPlane2->SetRelativeLocation(FVector(0.f, 140.f, 110.f));

	CardPlane0->SetRelativeRotation(FRotator(0.f, -12.f, 0.f));
	CardPlane2->SetRelativeRotation(FRotator(0.f, 12.f, 0.f));

	CardBaseLoc0 = CardPlane0->GetRelativeLocation();
	CardBaseLoc1 = CardPlane1->GetRelativeLocation();
	CardBaseLoc2 = CardPlane2->GetRelativeLocation();

	WelcomeText = CreateDefaultSubobject<UTextRenderComponent>(TEXT("WelcomeText"));
	WelcomeText->SetupAttachment(HologramRoot);
	WelcomeText->SetRelativeLocation(FVector(0.f, 0.f, 220.f));
	WelcomeText->SetHorizontalAlignment(EHTA_Center);
	WelcomeText->SetVerticalAlignment(EVRTA_TextCenter);
	WelcomeText->SetWorldSize(26.f);
	WelcomeText->SetTextRenderColor(FColor(0, 240, 255, 255));
	WelcomeText->SetHiddenInGame(true);
}

void AFELVaultHologramTerminalActor::RefreshCreatorCardsFromSnapshot(const FFELReadinessSnapshot& Snap)
{
	if (WelcomeText)
	{
		FString Line = Snap.LabWelcomeToast;
		if (!Snap.StoodCreatorCardTraitLine.IsEmpty())
		{
			Line = Line.IsEmpty() ? Snap.StoodCreatorCardTraitLine : Line + FString(TEXT("\n")) + Snap.StoodCreatorCardTraitLine;
		}
		if (!Line.IsEmpty())
		{
			WelcomeText->SetText(FText::FromString(Line));
			WelcomeText->SetHiddenInGame(false);
			WelcomeText->SetTextRenderColor(FEL_TierWelcomeColor(Snap.StoodCardTier));
		}
		else
		{
			WelcomeText->SetText(FText::GetEmpty());
			WelcomeText->SetHiddenInGame(true);
		}
	}

	bSlotAnimating = true;
	SlotAnimTime = 0.f;
	if (CardPlane0)
	{
		CardPlane0->SetRelativeLocation(CardBaseLoc0 + FVector(0.f, 0.f, -95.f));
	}
	if (CardPlane1)
	{
		CardPlane1->SetRelativeLocation(CardBaseLoc1 + FVector(0.f, 0.f, -95.f));
	}
	if (CardPlane2)
	{
		CardPlane2->SetRelativeLocation(CardBaseLoc2 + FVector(0.f, 0.f, -95.f));
	}

	CardMIDs.Reset();
	TArray<UStaticMeshComponent*> Planes = {CardPlane0, CardPlane1, CardPlane2};
	for (int32 i = 0; i < 3; ++i)
	{
		UStaticMeshComponent* P = Planes[i];
		if (!P || !HologramCardMaterial)
		{
			continue;
		}
		UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(HologramCardMaterial, this);
		P->SetMaterial(0, MID);
		CardMIDs.Add(MID);
		if (Snap.CreatorCardTexturePaths.IsValidIndex(i))
		{
			if (UTexture2D* Tex = UFELBrandInjectionSubsystem::LoadTextureFromContentPath(Snap.CreatorCardTexturePaths[i]))
			{
				MID->SetTextureParameterValue(CardArtParameterName, Tex);
			}
		}
	}
}

void AFELVaultHologramTerminalActor::Tick(const float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (bSlotAnimating)
	{
		SlotAnimTime += DeltaSeconds;
		auto EaseInOut = [](const float T) -> float
		{
			return 1.f - FMath::Pow(1.f - FMath::Clamp(T, 0.f, 1.f), 3.f);
		};
		auto StepPlane = [&](UStaticMeshComponent* Plane, const FVector& Base, const float StaggerSec) -> void
		{
			if (!Plane)
			{
				return;
			}
			const float T = FMath::Clamp((SlotAnimTime - StaggerSec) / SlotAnimDurationSec, 0.f, 1.f);
			const float E = EaseInOut(T);
			const FVector Hidden = Base + FVector(0.f, 0.f, -95.f);
			Plane->SetRelativeLocation(FMath::Lerp(Hidden, Base, E));
		};
		StepPlane(CardPlane0, CardBaseLoc0, 0.f);
		StepPlane(CardPlane1, CardBaseLoc1, 0.08f);
		StepPlane(CardPlane2, CardBaseLoc2, 0.16f);
		if (SlotAnimTime >= SlotAnimDurationSec + 0.2f)
		{
			bSlotAnimating = false;
		}
	}
	APawn* Player = UGameplayStatics::GetPlayerPawn(this, 0);
	if (!Player)
	{
		return;
	}
	const float D = FVector::Dist(Player->GetActorLocation(), GetActorLocation());
	const float Target = (D < ProximityRadiusUU) ? 1.f : 0.f;
	RotationBlend = FMath::FInterpTo(RotationBlend, Target, DeltaSeconds, 3.f);
	const float Speed = FMath::Lerp(0.f, MaxYawDegreesPerSecond, RotationBlend);
	HologramRoot->AddRelativeRotation(FRotator(0.f, Speed * DeltaSeconds, 0.f));
}
