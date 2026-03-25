// Copyright (c) Final Evolution Lab.

#include "FELShopInteractionActor.h"
#include "FELNativeBridge.h"
#include "Components/BoxComponent.h"
#include "Engine/World.h"

AFELShopInteractionActor::AFELShopInteractionActor()
{
	PrimaryActorTick.bCanEverTick = false;
	HotspotBox = CreateDefaultSubobject<UBoxComponent>(TEXT("HotspotBox"));
	SetRootComponent(HotspotBox);
	HotspotBox->SetBoxExtent(FVector(56.f, 40.f, 96.f));
	HotspotBox->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	HotspotBox->SetCollisionObjectType(ECC_WorldDynamic);
	HotspotBox->SetCollisionResponseToAllChannels(ECR_Ignore);
	HotspotBox->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);
	HotspotBox->SetGenerateOverlapEvents(false);
}

void AFELShopInteractionActor::BeginPlay()
{
	Super::BeginPlay();
}

void AFELShopInteractionActor::ActivateFromTap()
{
	UWorld* const W = GetWorld();
	if (!W)
	{
		return;
	}
	const float T = W->GetTimeSeconds();
	if (T - LastNotifyWorldTime < TapCooldownSec)
	{
		return;
	}
	LastNotifyWorldTime = T;
	FELNativeBridge::NotifyShardMarketplaceHotspot(HotspotId, LumaCaptureId);
}
