// Copyright (c) Final Evolution Lab.
// Vault Terminal — top 3 Creator Cards as holographic planes; yaw spin when player is near.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"
#include "GameFramework/Actor.h"
#include "AFELVaultHologramTerminalActor.generated.h"

class USceneComponent;
class UStaticMeshComponent;
class UTextRenderComponent;
class UMaterialInstanceDynamic;
class UTexture2D;

UCLASS()
class FINALEVOLUTIONLAB_API AFELVaultHologramTerminalActor : public AActor
{
	GENERATED_BODY()

public:
	AFELVaultHologramTerminalActor();

	virtual void Tick(float DeltaSeconds) override;

	/** Texture parameter on `HologramCardMaterial` (unlit/emissive hologram). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Vault")
	FName CardArtParameterName = TEXT("CardArt");

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Vault")
	float ProximityRadiusUU = 520.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Vault")
	float MaxYawDegreesPerSecond = 35.f;

	/** Base material with texture parameter `CardArt` (assign in editor). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Vault")
	TObjectPtr<UMaterialInterface> HologramCardMaterial;

	UFUNCTION(BlueprintCallable, Category = "FEL|Lab|Vault")
	void RefreshCreatorCardsFromSnapshot(const FFELReadinessSnapshot& Snap);

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Lab|Vault")
	TObjectPtr<USceneComponent> HologramRoot;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Lab|Vault")
	TObjectPtr<UStaticMeshComponent> CardPlane0;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Lab|Vault")
	TObjectPtr<UStaticMeshComponent> CardPlane1;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Lab|Vault")
	TObjectPtr<UStaticMeshComponent> CardPlane2;

	/** Holographic line when Swift grants welcome shards / onboarding toast (`LabWelcomeToast` in snapshot). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Lab|Vault")
	TObjectPtr<UTextRenderComponent> WelcomeText;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UMaterialInstanceDynamic>> CardMIDs;

	float RotationBlend = 0.f;

	/** “Stand” slotting — cards rise into place when readiness refreshes. */
	bool bSlotAnimating = false;
	float SlotAnimTime = 0.f;
	static constexpr float SlotAnimDurationSec = 0.65f;
	FVector CardBaseLoc0 = FVector::ZeroVector;
	FVector CardBaseLoc1 = FVector::ZeroVector;
	FVector CardBaseLoc2 = FVector::ZeroVector;
};
