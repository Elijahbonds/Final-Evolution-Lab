// Copyright (c) Final Evolution Lab.
// Clinical Mirror — Spiral Line + Front Functional Line translucent HUD; Push 1,2 pulse; SFMA rotation FAIL → red congestion.

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "FELBiometricTypes.h"
#include "UFELBiometricOverlays.generated.h"

class UStaticMeshComponent;
class UMaterialInstanceDynamic;

/**
 * High-fidelity fascial plane overlays for the Unreal Lab: assign two translucent meshes (Spiral Line, Front Functional Line)
 * in-editor and drive M_Clinical_Transparency / CONFIG_Clinical scalars. Pair with UFELRhythmicCueingWidget beats.
 */
UCLASS(ClassGroup = (FEL), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELBiometricOverlays : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELBiometricOverlays();

	/** Finds all UFELBiometricOverlays in the world and applies Push 1,2 rhythm pulse (clinical HUD sync). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical", meta = (WorldContext = "WorldContextObject"))
	static void ApplyGlobalRhythmPulse(UObject* WorldContextObject, int32 BeatPhaseMod3);

	/** Wire Spiral / Front meshes from the owning actor (or leave null for material-only / Blueprint mesh spawn). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Clinical|Meshes")
	TObjectPtr<UStaticMeshComponent> SpiralLineMesh;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Clinical|Meshes")
	TObjectPtr<UStaticMeshComponent> FrontFunctionalLineMesh;

	/** Optional MID slots — created from mesh materials in BeginPlay when meshes are set. */
	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Clinical")
	TObjectPtr<UMaterialInstanceDynamic> SpiralMID;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Clinical")
	TObjectPtr<UMaterialInstanceDynamic> FrontMID;

	/** Master toggle for spiral + front line visibility and ticking. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void SetClinicalOverlaysActive(bool bActive);

	/** Called from GameMode biometric broadcast — SFMA rotation FAIL drives red congestion on fascial planes. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void ApplyBiometricContext(const FFELBiometricContext& Context);

	/** Beat phase 0 = penultimate Push, 1 = "1", 2 = "2" — ties to UFELRhythmicCueingWidget / Push 1,2 cadence. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void OnPushRhythmBeat(int32 BeatPhaseMod3);

protected:
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	void EnsureMIDs();
	void PushPulseForPhase(int32 Phase);
	void ApplyCongestionVisual(bool bRedRoadblock);

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	bool bOverlaysActive = true;

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	bool bSFMA_RotationRoadblock = false;

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	float BasePulseSpeed = 1.15f;

	/** Scales spiral emissive pulse so the overlay stays readable under the rim at high approach speed (Alpha 1 polish). 0.75–0.9 typical. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Clinical", meta = (ClampMin = "0.35", ClampMax = "1.0"))
	float SpiralVisualIntensityScale = 0.82f;

	float PulseAccum = 0.f;
	float FrontFunctionalTension = 0.f;
	float SpiralPulseBoost = 0.f;
	/** Last values pushed to MIDs — skip redundant scalar sets during System Scan / recording to reduce render-thread work. */
	float LastWrittenSpiralPulse = -1000.f;
	float LastWrittenFrontTension = -1000.f;
	float LastWrittenFrontPulsePhase = -1000.f;
};
