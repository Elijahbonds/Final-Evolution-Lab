// Copyright (c) Final Evolution Lab.
// Gold Master: short cinematic pan on Luma_Venice_Shop before returning to player camera.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELVenueShopFlyByDirector.generated.h"

class UCameraComponent;
class USceneComponent;

/**
 * Spawns on Luma shop maps: 2s pan, then blends view back to the possessed pawn.
 * Place via AFELBasketballGameMode or Level Blueprint.
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELVenueShopFlyByDirector : public AActor
{
	GENERATED_BODY()

public:
	AFELVenueShopFlyByDirector();

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void TryBeginFlyBy();

	UFUNCTION()
	void FinishFlyBy();

	UPROPERTY(VisibleAnywhere, Category = "FEL|Camera")
	TObjectPtr<USceneComponent> RootScene;

	UPROPERTY(VisibleAnywhere, Category = "FEL|Camera")
	TObjectPtr<UCameraComponent> FlyByCamera;

	float PanSeconds = 2.f;
	float ElapsedPan = 0.f;
	FVector PanStart = FVector::ZeroVector;
	FVector PanEnd = FVector::ZeroVector;
	bool bFlyByActive = false;

	FTimerHandle FlyByStartTimer;
	FTimerHandle FlyByEndTimer;
};
