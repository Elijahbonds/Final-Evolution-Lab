// Copyright (c) Final Evolution Lab.

#include "FELVenueShopFlyByDirector.h"
#include "Camera/CameraComponent.h"
#include "Components/SceneComponent.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/Pawn.h"
#include "TimerManager.h"
#include "Engine/World.h"

AFELVenueShopFlyByDirector::AFELVenueShopFlyByDirector()
{
	PrimaryActorTick.bCanEverTick = true;
	RootScene = CreateDefaultSubobject<USceneComponent>(TEXT("RootScene"));
	SetRootComponent(RootScene);
	FlyByCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FlyByCamera"));
	FlyByCamera->SetupAttachment(RootScene);
	FlyByCamera->bUsePawnControlRotation = false;
}

void AFELVenueShopFlyByDirector::BeginPlay()
{
	Super::BeginPlay();
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(FlyByStartTimer, this, &AFELVenueShopFlyByDirector::TryBeginFlyBy, 0.35f, false);
	}
}

void AFELVenueShopFlyByDirector::TryBeginFlyBy()
{
	APlayerController* PC = GetWorld() ? GetWorld()->GetFirstPlayerController() : nullptr;
	APawn* Pawn = PC ? PC->GetPawn() : nullptr;
	if (!PC || !Pawn)
	{
		if (UWorld* W = GetWorld())
		{
			W->GetTimerManager().SetTimer(FlyByStartTimer, this, &AFELVenueShopFlyByDirector::TryBeginFlyBy, 0.2f, false);
		}
		return;
	}

	const FVector Focus = Pawn->GetActorLocation();
	const FVector Forward = Pawn->GetActorForwardVector();
	const FVector Right = Pawn->GetActorRightVector();
	PanStart = Focus + Forward * 400.f + Right * (-900.f) + FVector(0.f, 0.f, 520.f);
	PanEnd = Focus + Forward * 400.f + Right * 900.f + FVector(0.f, 0.f, 520.f);
	SetActorLocation(PanStart);
	const FRotator LookAt = (Focus - PanStart).Rotation();
	FlyByCamera->SetWorldRotation(LookAt);
	bFlyByActive = true;
	ElapsedPan = 0.f;
	PC->SetViewTargetWithBlend(this, 0.25f);
	if (UWorld* W = GetWorld())
	{
		W->GetTimerManager().SetTimer(FlyByEndTimer, this, &AFELVenueShopFlyByDirector::FinishFlyBy, PanSeconds, false);
	}
}

void AFELVenueShopFlyByDirector::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);
	if (!bFlyByActive)
	{
		return;
	}
	ElapsedPan += DeltaSeconds;
	const float Alpha = FMath::Clamp(ElapsedPan / FMath::Max(0.01f, PanSeconds), 0.f, 1.f);
	const float Ease = Alpha * Alpha * (3.f - 2.f * Alpha);
	const FVector Loc = FMath::Lerp(PanStart, PanEnd, Ease);
	SetActorLocation(Loc);
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
	{
		if (APawn* P = PC->GetPawn())
		{
			const FVector Focus = P->GetActorLocation();
			const FRotator R = (Focus - Loc).Rotation();
			FlyByCamera->SetWorldRotation(R);
		}
	}
}

void AFELVenueShopFlyByDirector::FinishFlyBy()
{
	bFlyByActive = false;
	if (APlayerController* PC = GetWorld() ? GetWorld()->GetFirstPlayerController() : nullptr)
	{
		if (APawn* P = PC->GetPawn())
		{
			PC->SetViewTargetWithBlend(P, 0.55f);
		}
	}
}
