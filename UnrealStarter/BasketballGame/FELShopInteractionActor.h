// Copyright (c) Final Evolution Lab.
// Hotspot anchors inside Luma Sovereign Shop — visibility traces + Swift marketplace handshake.

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "FELShopInteractionActor.generated.h"

class UBoxComponent;

/**
 * Place in-editor at mannequin / gear wall locations. Box blocks ECC_Visibility for touch raycasts.
 * Pair with invisible blocking volumes for pawn collision vs photogrammetry shells.
 */
UCLASS()
class FINALEVOLUTIONLAB_API AFELShopInteractionActor : public AActor
{
	GENERATED_BODY()

public:
	AFELShopInteractionActor();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Shop")
	TObjectPtr<UBoxComponent> HotspotBox;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shop")
	FString HotspotId = TEXT("sovereign_mannequin_a");

	/** Default: Luma AI Venice Shop (`FELLumaCaptureIds::LumaVeniceShop`); override per hotspot. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Shop")
	FString LumaCaptureId = TEXT("03953AA0-E30A-4680-AB5D-1889CC99F71D");

	UFUNCTION(BlueprintCallable, Category = "FEL|Shop")
	void ActivateFromTap();

	virtual void BeginPlay() override;

protected:
	float LastNotifyWorldTime = -1e9f;
	static constexpr float TapCooldownSec = 0.35f;
};
