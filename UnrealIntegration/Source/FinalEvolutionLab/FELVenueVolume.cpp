// Copyright (c) Final Evolution Lab.
#include "FELVenueVolume.h"
#include "FELBridgeSubsystem.h"
#include "GameFramework/Pawn.h"
#include "Engine/World.h"

AFELVenueVolume::AFELVenueVolume()
{
	PrimaryActorTick.bCanEverTick = false;

	CollisionComponent = CreateDefaultSubobject<UBoxComponent>(TEXT("CollisionComp"));
	RootComponent = CollisionComponent;
	CollisionComponent->SetCollisionProfileName(TEXT("Trigger"));
	CollisionComponent->SetGenerateOverlapEvents(true);
}

void AFELVenueVolume::BeginPlay()
{
	Super::BeginPlay();
	CollisionComponent->OnComponentBeginOverlap.AddDynamic(this, &AFELVenueVolume::OnOverlapBegin);
}

void AFELVenueVolume::OnOverlapBegin(
	UPrimitiveComponent* OverlappedComp,
	AActor* OtherActor,
	UPrimitiveComponent* OtherComp,
	int32 OtherBodyIndex,
	bool bFromSweep,
	const FHitResult& SweepResult)
{
	if (!OtherActor || OtherActor == this)
	{
		return;
	}

	// Verify the overlapping actor is the player character
	APawn* PlayerPawn = Cast<APawn>(OtherActor);
	if (PlayerPawn && PlayerPawn->IsLocallyControlled())
	{
		UWorld* World = GetWorld();
		if (World)
		{
			UGameInstance* GI = World->GetGameInstance();
			if (GI)
			{
				UFELBridgeSubsystem* Bridge = GI->GetSubsystem<UFELBridgeSubsystem>();
				if (Bridge)
				{
					Bridge->NotifyVenueTravel(VenueToken, DefaultModeId);
				}
			}
		}
	}
}
