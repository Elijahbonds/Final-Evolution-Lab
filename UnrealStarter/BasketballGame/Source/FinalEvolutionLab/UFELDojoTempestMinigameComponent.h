// Copyright (c) Final Evolution Lab.
// Actor component — runs the Dojo Neural Tempest loop (storm pressure vs Cyclone Energy + bursts). No UMG; bind HUD in BP.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"
#include "Components/ActorComponent.h"
#include "UFELDojoTempestMinigameComponent.generated.h"

class UFELCreatorCard;

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELDojoTempestPlayerDepleted);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELDojoTempestStormBroken);

/**
 * Neural Tempest: ambient "squall" drains your health; channeling builds Cyclone Energy faster; spend energy on
 * Tempest Bursts to break Storm Integrity. All core rates scale with PRQ, Neural Drive, kinetic leakage, and optional Creator Card.
 */
UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELDojoTempestMinigameComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELDojoTempestMinigameComponent();

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	/** Begin the loop from profile + optional equipped Creator Card data asset. */
	UFUNCTION(BlueprintCallable, Category = "FEL|DojoTempest")
	void InitializeFromReadiness(const FFELReadinessSnapshot& Snap, UFELCreatorCard* OptionalCreatorCard);

	UFUNCTION(BlueprintCallable, Category = "FEL|DojoTempest")
	void StopTempest();

	/** Holding surge channels neural flow into the cyclone (storm-style build). */
	UFUNCTION(BlueprintCallable, Category = "FEL|DojoTempest")
	void SetSurgeChannelActive(bool bActive);

	/** Spend Cyclone Energy to strike the storm; returns damage applied to Storm Integrity. */
	UFUNCTION(BlueprintCallable, Category = "FEL|DojoTempest")
	bool TryCommitTempestBurst(float EnergyCost, float& OutDamageToStorm);

	UFUNCTION(BlueprintPure, Category = "FEL|DojoTempest")
	float GetHealthNormalized() const;

	UFUNCTION(BlueprintPure, Category = "FEL|DojoTempest")
	float GetCycloneEnergyNormalized() const;

	UFUNCTION(BlueprintPure, Category = "FEL|DojoTempest")
	float GetStormIntegrityNormalized() const;

	UPROPERTY(BlueprintAssignable, Category = "FEL|DojoTempest")
	FFELDojoTempestPlayerDepleted OnPlayerTempestDepleted;

	UPROPERTY(BlueprintAssignable, Category = "FEL|DojoTempest")
	FFELDojoTempestStormBroken OnStormBroken;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|DojoTempest")
	float Health = 0.f;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|DojoTempest")
	float MaxHealth = 100.f;

	/** 0–100 Cyclone Energy (storm meter). */
	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|DojoTempest")
	float CycloneEnergy = 0.f;

	/** Abstract storm shell — reduce to 0 to clear the mini-game. */
	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|DojoTempest")
	float StormIntegrity = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|DojoTempest", meta = (ClampMin = "10", UIMin = "10"))
	float InitialStormIntegrity = 100.f;

	/** Baseline pressure before PRQ mitigation. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|DojoTempest", meta = (ClampMin = "0"))
	float BaseSquallDamagePerSecond = 4.5f;

	/** Energy cost default for one burst (tunable in BP). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|DojoTempest", meta = (ClampMin = "5", UIMin = "5", ClampMax = "100"))
	float DefaultBurstEnergyCost = 38.f;

	/** While channeling, energy regen is multiplied. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|DojoTempest", meta = (ClampMin = "1"))
	float SurgeChannelRegenMultiplier = 2.15f;

protected:
	UPROPERTY(Transient)
	TObjectPtr<UFELCreatorCard> ActiveCreatorCard = nullptr;

	FFELReadinessSnapshot CachedSnap;
	float CachedEnergyComposite = 1.f;
	float CachedStrikeComposite = 1.f;
	float CachedStrikeStrength = 10.f;
	bool bTempestActive = false;
	bool bSurgeChannel = false;
	bool bNotifiedPlayerDepleted = false;
	bool bNotifiedStormBroken = false;
};
