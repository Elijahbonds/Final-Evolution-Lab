// Copyright (c) Final Evolution Lab.
// Karate lab gameplay — Head-To-Head Storm (1v1 tempest duel) or Endless Agent Waves (matrix-style horde).
// PRQ scales strength, speed feel, and performance; Creator Card composites layer on top. No UMG — bind widgets in BP.

#pragma once

#include "CoreMinimal.h"
#include "FELArenaRulesTypes.h"
#include "FELKarateLabModes.h"
#include "FELKaratePRQBoost.h"
#include "FELReadinessTypes.h"
#include "Components/ActorComponent.h"
#include "UFELKarateArenaModeComponent.generated.h"

class UFELCreatorCard;

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELKarateH2HVictory);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FFELKarateH2HDefeat);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FFELKarateEndlessWaveAdvanced, int32, NewWaveIndex);

/**
 * HeadToHeadStorm: you vs one opponent — both accrue Cyclone Energy; bursts trade damage on integrity/health.
 * EndlessAgentWaves: wave integrity pool + rising squall; clearing a wave heals slightly and increments wave index forever.
 * MatrixRevolutionsSiege: stronger per-wave scaling + horde multiplier; surge channel extra mitigates infection squall; slightly lower wave-clear heal.
 */
UCLASS(ClassGroup = (Custom), meta = (BlueprintSpawnableComponent))
class FINALEVOLUTIONLAB_API UFELKarateArenaModeComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UFELKarateArenaModeComponent();

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	/** Uses `Snap.KarateLabVariant` (from `active_mode` / `karateLabMode` JSON). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Karate")
	void InitializeKarateFromProfile(const FFELReadinessSnapshot& Snap, UFELCreatorCard* OptionalCreatorCard);

	/** Uses merged `FFELArenaRules::KarateLabMode` (data asset + ArenaSettings). */
	UFUNCTION(BlueprintCallable, Category = "FEL|Karate")
	void InitializeKarateFromArenaRules(
		const FFELReadinessSnapshot& Snap,
		const FFELArenaRules& Rules,
		UFELCreatorCard* OptionalCreatorCard);

	UFUNCTION(BlueprintCallable, Category = "FEL|Karate")
	void InitializeKarateWithLabMode(
		const FFELReadinessSnapshot& Snap,
		UFELCreatorCard* OptionalCreatorCard,
		EFELKarateLabMode Mode);

	UFUNCTION(BlueprintCallable, Category = "FEL|Karate")
	void StopKarateArena();

	UFUNCTION(BlueprintCallable, Category = "FEL|Karate")
	void SetPlayerSurgeChannelActive(bool bActive);

	UFUNCTION(BlueprintCallable, Category = "FEL|Karate")
	bool TryPlayerTempestBurst(float EnergyCost, float& OutDamageToTarget);

	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	EFELKarateLabMode GetActiveKarateMode() const { return ActiveMode; }

	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	float GetPlayerHealthNormalized() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	float GetPlayerCycloneNormalized() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	float GetPRQSpeedMultiplierForLocomotion() const { return PRQBoost.SpeedMultiplier; }

	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	float GetPRQStrikeStrength() const { return CachedStrikeStrength; }

	/** H2H: opponent shell 0–1. Endless: current wave pool 0–1. */
	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	float GetPrimaryTargetNormalized() const;

	UFUNCTION(BlueprintPure, Category = "FEL|Karate")
	int32 GetEndlessWaveIndex() const { return EndlessWaveIndex; }

	UPROPERTY(BlueprintAssignable, Category = "FEL|Karate|H2H")
	FFELKarateH2HVictory OnHeadToHeadVictory;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Karate|H2H")
	FFELKarateH2HDefeat OnHeadToHeadDefeat;

	UPROPERTY(BlueprintAssignable, Category = "FEL|Karate|Endless")
	FFELKarateEndlessWaveAdvanced OnEndlessWaveAdvanced;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Karate")
	float PlayerHealth = 0.f;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Karate")
	float PlayerMaxHealth = 100.f;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Karate")
	float PlayerCycloneEnergy = 0.f;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Karate|H2H")
	float OpponentIntegrity = 100.f;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Karate|H2H")
	float OpponentCycloneEnergy = 0.f;

	UPROPERTY(Transient, BlueprintReadOnly, Category = "FEL|Karate|Endless")
	float WaveIntegrityPool = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Karate", meta = (ClampMin = "0"))
	float BaseSquallDamagePerSecond = 4.2f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Karate", meta = (ClampMin = "5", ClampMax = "100"))
	float DefaultBurstEnergyCost = 36.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Karate", meta = (ClampMin = "1"))
	float SurgeChannelRegenMultiplier = 2.05f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Karate|H2H", meta = (ClampMin = "10"))
	float InitialOpponentIntegrity = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "FEL|Karate|Endless", meta = (ClampMin = "1"))
	float EndlessWaveBaseIntegrity = 88.f;

protected:
	void BeginRun(const FFELReadinessSnapshot& Snap, UFELCreatorCard* OptionalCreatorCard, EFELKarateLabMode Mode);
	void TickHeadToHead(float DeltaTime);
	void TickEndless(float DeltaTime);
	void TickOpponentAI(float DeltaTime);

	UPROPERTY(Transient)
	TObjectPtr<UFELCreatorCard> ActiveCreatorCard = nullptr;

	EFELKarateLabMode ActiveMode = EFELKarateLabMode::HeadToHeadStorm;
	FFELReadinessSnapshot CachedSnap;
	FFELKaratePRQCombatBoost PRQBoost;
	float CachedEnergyComposite = 1.f;
	float CachedStrikeComposite = 1.f;
	float CachedStrikeStrength = 10.f;
	bool bArenaActive = false;
	bool bPlayerSurge = false;
	float OpponentThinkAccum = 0.f;
	int32 EndlessWaveIndex = 1;
	float EndlessWaveMaxForNorm = 100.f;
	bool bNotifiedH2HWin = false;
	bool bNotifiedH2HLoss = false;
};
