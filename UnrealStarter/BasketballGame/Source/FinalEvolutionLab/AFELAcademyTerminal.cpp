// Copyright (c) Final Evolution Lab.

#include "AFELAcademyTerminal.h"
#include "FELNativeBridge.h"
#include "Components/BoxComponent.h"
#include "Components/SceneComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/World.h"

AFELAcademyTerminal::AFELAcademyTerminal()
{
	PrimaryActorTick.bCanEverTick = true;

	RootScene = CreateDefaultSubobject<USceneComponent>(TEXT("RootScene"));
	SetRootComponent(RootScene);

	ProximityTrigger = CreateDefaultSubobject<UBoxComponent>(TEXT("ProximityTrigger"));
	ProximityTrigger->SetupAttachment(RootScene);
	ProximityTrigger->SetBoxExtent(FVector(140.f, 140.f, 96.f));
	ProximityTrigger->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	ProximityTrigger->SetCollisionResponseToAllChannels(ECR_Ignore);
	ProximityTrigger->SetCollisionResponseToChannel(ECC_Pawn, ECR_Overlap);
	ProximityTrigger->SetGenerateOverlapEvents(true);

	KioskMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("KioskMesh"));
	KioskMesh->SetupAttachment(RootScene);
	KioskMesh->SetCollisionEnabled(ECollisionEnabled::QueryAndPhysics);
	KioskMesh->SetCollisionResponseToChannel(ECC_Pawn, ECR_Block);

	AccentMesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("AccentMesh"));
	AccentMesh->SetupAttachment(KioskMesh);
	AccentMesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	InteractKey = EKeys::E;
}

void AFELAcademyTerminal::BeginPlay()
{
	Super::BeginPlay();
	if (ProximityTrigger)
	{
		ProximityTrigger->OnComponentBeginOverlap.AddDynamic(this, &AFELAcademyTerminal::OnProximityBegin);
		ProximityTrigger->OnComponentEndOverlap.AddDynamic(this, &AFELAcademyTerminal::OnProximityEnd);
	}
	RefreshDemoViewTarget();
}

void AFELAcademyTerminal::RefreshDemoViewTarget()
{
	if (DemoViewTarget.IsValid())
	{
		return;
	}
	if (DemoViewTargetSoft.IsNull())
	{
		return;
	}
	if (UObject* Loaded = DemoViewTargetSoft.LoadSynchronous())
	{
		DemoViewTarget = Cast<AActor>(Loaded);
	}
}

void AFELAcademyTerminal::OnProximityBegin(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult)
{
	if (APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0))
	{
		if (OtherActor == PC->GetPawn())
		{
			bPlayerInRange = true;
			SetInteractionPromptVisible(true);
		}
	}
}

void AFELAcademyTerminal::OnProximityEnd(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
	UPrimitiveComponent* OtherComp, int32 OtherBodyIndex)
{
	if (APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0))
	{
		if (OtherActor == PC->GetPawn())
		{
			bPlayerInRange = false;
			SetInteractionPromptVisible(false);
		}
	}
}

void AFELAcademyTerminal::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!bPlayerInRange)
	{
		return;
	}
	APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0);
	if (!PC || PC->PlayerCameraManager == nullptr)
	{
		return;
	}
	if (PC->WasInputKeyJustPressed(InteractKey))
	{
		TryInteract();
	}
}

void AFELAcademyTerminal::TryInteract()
{
	UWorld* W = GetWorld();
	if (!W)
	{
		return;
	}
	const double Now = W->GetTimeSeconds();
	if (Now - LastInteractTime < static_cast<double>(InteractCooldownSeconds))
	{
		return;
	}
	LastInteractTime = Now;

	OnAcademyInteract.Broadcast();
	FELNativeBridge::NotifyAcademyTerminalEngaged();
	OpenAcademyUI();
}
