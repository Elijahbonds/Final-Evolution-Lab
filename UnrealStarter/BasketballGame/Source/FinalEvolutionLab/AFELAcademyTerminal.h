// Copyright (c) Final Evolution Lab.
// Lab venue — proximity interactable for Vertical Velocity Academy (Digital Twin Hub).

#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "UObject/SoftObjectPtr.h"
#include "AFELAcademyTerminal.generated.h"

class UBoxComponent;
class UStaticMeshComponent;
class UPrimitiveComponent;
class AActor;

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnAcademyTerminalActivated);

/**
 * Place in the Lab map near the scan-calibrated avatar lane.
 * Overlap + optional key press opens Academy UI / Movement Snack flow (bind in Blueprint).
 * "Platinum" trim: assign a metallic material on AccentMesh or override GetPlatinumAccentMaterial in BP.
 */
UCLASS(Blueprintable)
class FINALEVOLUTIONLAB_API AFELAcademyTerminal : public AActor
{
	GENERATED_BODY()

public:
	AFELAcademyTerminal();

	virtual void Tick(float DeltaSeconds) override;
	virtual void BeginPlay() override;

	UFUNCTION()
	void OnProximityBegin(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex, bool bFromSweep, const FHitResult& SweepResult);

	UFUNCTION()
	void OnProximityEnd(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp,
		int32 OtherBodyIndex);

	/** True while a registered pawn overlaps the trigger (designer: drive prompt visibility). */
	UFUNCTION(BlueprintPure, Category = "FEL|Academy|Terminal")
	bool IsPlayerInRange() const { return bPlayerInRange; }

	/** Default interact — E / Gamepad Face Button Bottom. Override mapping in BP if using Enhanced Input. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy|Terminal")
	FKey InteractKey = EKeys::E;

	/** Fired when the local player presses InteractKey while in range (C++ routes from Tick). */
	UPROPERTY(BlueprintAssignable, Category = "FEL|Academy|Terminal")
	FOnAcademyTerminalActivated OnAcademyInteract;

	/** Designer: spawn WBP, push Academy hub, or stream UI. */
	UFUNCTION(BlueprintImplementableEvent, Category = "FEL|Academy|Terminal")
	void OpenAcademyUI();

	/** Optional 3D prompt (bind visibility in BP). */
	UFUNCTION(BlueprintImplementableEvent, Category = "FEL|Academy|Terminal")
	void SetInteractionPromptVisible(bool bVisible);

	/** Call from BP after spawning UFELMovementSnackWidget to run camera → Demo Spot → montage. */
	UFUNCTION(BlueprintPure, Category = "FEL|Academy|Terminal")
	AActor* GetDemoViewTarget() const { return DemoViewTarget.Get(); }

protected:
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Academy|Terminal")
	TObjectPtr<USceneComponent> RootScene = nullptr;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Academy|Terminal")
	TObjectPtr<UBoxComponent> ProximityTrigger = nullptr;

	/** Kiosk body — swap mesh in editor; tint "Platinum" via material instance. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Academy|Terminal")
	TObjectPtr<UStaticMeshComponent> KioskMesh = nullptr;

	/** Optional second mesh for metallic accent strip. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "FEL|Academy|Terminal")
	TObjectPtr<UStaticMeshComponent> AccentMesh = nullptr;

	/** Camera or empty actor at the Movement Snack "Demo Spot" (avatar faces this area). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Academy|Terminal")
	TSoftObjectPtr<AActor> DemoViewTargetSoft;

	UPROPERTY(Transient, DuplicateTransient)
	TWeakObjectPtr<AActor> DemoViewTarget;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Academy|Terminal", meta = (ClampMin = "0"))
	float InteractCooldownSeconds = 0.75f;

private:
	void RefreshDemoViewTarget();
	void TryInteract();

	bool bPlayerInRange = false;
	double LastInteractTime = -1.0;
};
