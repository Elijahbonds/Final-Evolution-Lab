// Copyright (c) Final Evolution Lab.
// Interactive Clinical Anatomy — Spiral Line + Back Functional Line highlight (Build 6).

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "UFELFascialSlingVisualizer.generated.h"

class UMaterialInterface;
class UMaterialInstanceDynamic;

/**
 * Toggles fascial "sling" visualization on the academy mannequin: Spiral Line (rear foot → opposite shoulder)
 * and Back Functional Line during penultimate stride / Push 1,2. Pair with M_Clinical_Transparency for Muscle-and-Motion style layers.
 */
UCLASS(ClassGroup = (FEL), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELFascialSlingVisualizer : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELFascialSlingVisualizer();

	/** Enable glowing cyan pulse along Spiral Line splines. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void SetFascialSlingActive(bool bActive);

	/** SFMA fail → red congestion on thoracic + spiral (Swift bridge posts JSON). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void ApplySFMAHeatmapCongestion(bool bRedCongestionOnThoracicAndSpiral);

	/** 0…1 pulse phase driven by Niagara or material parameter each tick. */
	UFUNCTION(BlueprintCallable, Category = "FEL|Clinical")
	void SetSpiralPulsePhase(float Phase01);

protected:
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	bool bSlingActive = false;

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	bool bCongestionHeatmap = false;

	UPROPERTY(EditAnywhere, Category = "FEL|Clinical")
	float PulsePhase = 0.f;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> SpiralMID;

	float PulseAccum = 0.f;
};
