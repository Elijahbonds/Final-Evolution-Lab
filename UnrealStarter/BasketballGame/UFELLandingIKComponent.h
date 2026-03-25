// Copyright (c) Final Evolution Lab.
// Procedural landing wobble from ankle/knee kinetic heat (Lab Dunk + Gymnastics "stick" quality).

#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "UFELLandingIKComponent.generated.h"

UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELLandingIKComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELLandingIKComponent();

	/** 0–1 from System Scan kinetic map — higher = more ankle instability on landing. */
	UFUNCTION(BlueprintCallable, Category = "FEL|LandingIK")
	void SetKineticHeats(float AnkleHeat01, float KneeHeat01);

	/** Call from Character::Landed for dunk / gymnastics contexts. */
	UFUNCTION(BlueprintCallable, Category = "FEL|LandingIK")
	void ApplyLandingFromScan(bool bStickLandingMode, float AnkleHeat01, float KneeHeat01);

	UFUNCTION(BlueprintPure, Category = "FEL|LandingIK")
	float GetLandingWobblePitchDegrees() const { return CurrentWobblePitchDeg; }

	UFUNCTION(BlueprintPure, Category = "FEL|LandingIK")
	float GetLandingPelvisShiftCM() const { return CurrentPelvisShiftCM; }

protected:
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|LandingIK", meta = (ClampMin = "0", ClampMax = "18"))
	float MaxLandingWobblePitchDeg = 7.5f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|LandingIK", meta = (ClampMin = "0", ClampMax = "12"))
	float MaxPelvisShiftCM = 4.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|LandingIK", meta = (ClampMin = "0.05", ClampMax = "3"))
	float WobbleDecayPerSecond = 1.35f;

	float CachedAnkle01 = 0.2f;
	float CachedKnee01 = 0.2f;
	float CurrentWobblePitchDeg = 0.f;
	float CurrentPelvisShiftCM = 0.f;
};
