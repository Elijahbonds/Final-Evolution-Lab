// Copyright (c) Final Evolution Lab.
// Apex / Perfect-band camera: tightens spring arm + FOV in sync with NeuroFlowVisualBlend.

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELCinematicCameraComponent.generated.h"

class USpringArmComponent;
class UCameraComponent;

UCLASS(ClassGroup = (FEL), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELCinematicCameraComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELCinematicCameraComponent();

	virtual void BeginPlay() override;

	/**
	 * Call from `AFELBasketballCharacter::Tick` after `UpdateNeuroFlowVisuals` so `NeuroFlowVisualBlend` matches this frame.
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Cinematic")
	/**
	 * @param GatherApproachSeconds Bonds Bounce gather clock (0–~0.55s typical). Drives extra FOV/arm punch during explosive takeoff window.
	 */
	void UpdateApexCamera(float DeltaSeconds, float NeuroFlowVisualBlend01, float GatherApproachSeconds = 0.f);

	/** Call from character when Bonds Bounce resolves to Perfect (tightens apex chase). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Cinematic")
	void NotifyPerfectTimingBand();

	/** Match Results "Save Best Moment": forced apex framing + slomo (see character `UpdateNeuroFlowVisuals`). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Cinematic")
	void BeginReplayHighlight(float DurationSeconds = 3.f);

	/**
	 * First Bio-Sync / "Birth of the Twin": orbit spring arm yaw + tight apex blend for DurationSeconds (default 3s).
	 * Paired with `AFELBasketballCharacter::PlayTwinBirthIntro` (Neuro-Flow VFX/audio).
	 */
	UFUNCTION(BlueprintCallable, Category = "FEL|Cinematic")
	void BeginTwinBirthCinematic(float DurationSeconds = 3.f);

	UFUNCTION(BlueprintPure, Category = "FEL|Cinematic")
	bool IsReplayHighlightActive() const { return ReplayHighlightRemainSec > 0.f; }

protected:
	UPROPERTY(EditAnywhere, Category = "FEL|Apex")
	float ApexVelocityThresholdUU = 185.f;

	/** Relative to cached default arm length at BeginPlay (e.g. 0.72 = tighter third-person). */
	UPROPERTY(EditAnywhere, Category = "FEL|Apex", meta = (ClampMin = "0.4", ClampMax = "1.2"))
	float ApexArmLengthScale = 0.74f;

	UPROPERTY(EditAnywhere, Category = "FEL|Apex", meta = (ClampMin = "40", ClampMax = "120"))
	float ApexFieldOfView = 72.f;

	/** Fraction of default FOV to subtract during Gather (Bonds Bounce "punch-in"); 0.15 = 15% tighter FOV at full gather window. */
	UPROPERTY(EditAnywhere, Category = "FEL|Apex|Gather", meta = (ClampMin = "0", ClampMax = "0.35"))
	float GatherFovPunchFraction = 0.15f;

	UPROPERTY(EditAnywhere, Category = "FEL|Apex")
	float PerfectBoostDurationSec = 1.35f;

	UPROPERTY(EditAnywhere, Category = "FEL|Apex")
	float BlendInterpSpeed = 5.5f;

	UPROPERTY(Transient)
	TObjectPtr<USpringArmComponent> CachedSpringArm;

	UPROPERTY(Transient)
	TObjectPtr<UCameraComponent> CachedFollowCamera;

	float DefaultArmLength = 400.f;
	float DefaultFieldOfView = 90.f;
	float CurrentApexBlend = 0.f;
	float PerfectBoostRemainSec = 0.f;
	float ReplayHighlightRemainSec = 0.f;

	UPROPERTY(EditAnywhere, Category = "FEL|TwinBirth")
	float TwinBirthOrbitYawSpeed = 32.f;

	float TwinBirthRemainSec = 0.f;
};
