// Copyright (c) Final Evolution Lab.
// Movement Snack — short corrective demo (3D) + optional +5 shard Quick Log (Fuel economy parity).

#pragma once

#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "Engine/StreamableManager.h"
#include "UFELMovementSnackWidget.generated.h"

class AActor;
class APlayerController;
class USkeletalMeshComponent;
class UAnimMontage;
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnMovementSnackQuickLogShards);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnMovementSnackDemoReady);

/**
 * Designer: bind a skeletal mesh / AnimBP to `PlaySnackDemonstration3D` for the scan-calibrated avatar.
 * Blueprint: spawn `AFELExerciseDemonstrator` or play montage on your showroom avatar.
 */
UCLASS(BlueprintType, Blueprintable)
class FINALEVOLUTIONLAB_API UFELMovementSnackWidget : public UUserWidget
{
	GENERATED_BODY()

public:
	virtual void NativeConstruct() override;
	virtual void NativeDestruct() override;

	/** Spawn from `AFELAcademyTerminal` (or Lab UI) — optional weak ref for Demo Spot / platinum trim. */
	UFUNCTION(BlueprintCallable, Category = "FEL|MovementSnack")
	void BindTerminalActor(AActor* TerminalActor);

	/** Vertical Velocity Academy module key, e.g. `mod1`…`mod12` — resolves montage via `UFELAcademyMocapCatalogSubsystem`. */
	UPROPERTY(BlueprintReadWrite, Category = "FEL|Academy|Mocap")
	FString AcademyModuleKey;

	UFUNCTION(BlueprintCallable, Category = "FEL|Academy|Mocap")
	void SetAcademyModuleKey(const FString& ModuleKey);

	/** DeepMotion FBX → UAnimMontage import; assigned per module in the mocap catalog. */
	UFUNCTION(BlueprintPure, Category = "FEL|Academy|Mocap")
	UAnimMontage* GetResolvedDemonstrationMontage() const;

	/**
	 * Blends the player camera to DemoViewTarget (Demo Spot), waits, then fires `PlaySnackDemonstration3D` (montage on scan-calibrated avatar).
	 * Call `FinishSnackDemoAndRestoreCamera` when the montage ends (Blueprint timer or Animation Notify).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|MovementSnack")
	void RunDemoWithCameraTransition(
		APlayerController* PlayerController,
		AActor* DemoViewTarget,
		float BlendInSeconds,
		float DelaySecondsAfterBlendBeforeSnack);

	UFUNCTION(BlueprintCallable, Category = "FEL|MovementSnack")
	void FinishSnackDemoAndRestoreCamera(float BlendOutSeconds);

	/** Fire first — plays Blueprint 3D demo (corrective, e.g. CNS Freeway activation). */
	UFUNCTION(BlueprintCallable, Category = "FEL|MovementSnack")
	void TriggerSnackDemo();

	/** Fuel economy: broadcast to GameMode / progression to grant +5 Evolution Shards (same as Swift `ShardTransaction.congestionCleared` / meal snacks). */
	UFUNCTION(BlueprintCallable, Category = "FEL|MovementSnack")
	void QuickLogGrantShards();

	UPROPERTY(BlueprintAssignable, Category = "FEL|MovementSnack")
	FOnMovementSnackQuickLogShards OnQuickLogForShards;

	UPROPERTY(BlueprintAssignable, Category = "FEL|MovementSnack")
	FOnMovementSnackDemoReady OnSnackDemoReady;

	UFUNCTION(BlueprintPure, Category = "FEL|MovementSnack")
	AActor* GetBoundTerminal() const { return BoundTerminal.Get(); }

	UFUNCTION(BlueprintImplementableEvent, Category = "FEL|MovementSnack")
	void PlaySnackDemonstration3D();

	/** Wire to AnimBP: drive Copy Pose / Layer blend weight (0 = live avatar, 1 = demo mocap). */
	UFUNCTION(BlueprintImplementableEvent, Category = "FEL|MovementSnack")
	void OnMovementSnackPoseBlendAlpha(float Alpha);

	/** High-quality 2D fallback if montage fails to load within 3 seconds. */
	UFUNCTION(BlueprintImplementableEvent, Category = "FEL|MovementSnack")
	void ShowAthleteFallbackPoster();

protected:
	UPROPERTY()
	TWeakObjectPtr<AActor> BoundTerminal;

	UPROPERTY()
	TWeakObjectPtr<APlayerController> DemoPlayerController;

	FTimerHandle SnackDemoTimerHandle;
	FTimerHandle PoseBlendTimerHandle;
	FTimerHandle DemonstrationLoadFallbackTimer;

	TSharedPtr<FStreamableHandle> DemonstrationMontageLoadHandle;

	UFUNCTION()
	void OnDemonstrationMontageLoadedInternal();

	UFUNCTION()
	void OnDemonstrationLoadTimedOut();

	UPROPERTY()
	TWeakObjectPtr<USkeletalMeshComponent> PoseBlendSource;

	float PoseBlendDuration = 0.5f;
	float PoseBlendRemaining = 0.f;

	void FireSnackDemoAfterDelay();
	void TickPoseBlendStep();
};
