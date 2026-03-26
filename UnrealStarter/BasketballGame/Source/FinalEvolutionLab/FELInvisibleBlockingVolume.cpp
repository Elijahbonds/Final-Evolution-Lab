// Copyright (c) Final Evolution Lab.

#include "FELInvisibleBlockingVolume.h"
#include "Components/BoxComponent.h"

AFELInvisibleBlockingVolume::AFELInvisibleBlockingVolume()
{
	PrimaryActorTick.bCanEverTick = false;
	BlockBox = CreateDefaultSubobject<UBoxComponent>(TEXT("BlockBox"));
	SetRootComponent(BlockBox);
	BlockBox->InitBoxExtent(FVector(100.f, 100.f, 120.f));
	BlockBox->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	BlockBox->SetCollisionObjectType(ECC_WorldStatic);
	BlockBox->SetCollisionResponseToAllChannels(ECR_Block);
	// Do not occlude Sovereign Shop tap traces (ECC_Visibility) — only block physical pawn movement.
	BlockBox->SetCollisionResponseToChannel(ECC_Visibility, ECR_Ignore);
	BlockBox->SetHiddenInGame(true);
	BlockBox->SetVisibility(false);
	BlockBox->SetGenerateOverlapEvents(false);
}
