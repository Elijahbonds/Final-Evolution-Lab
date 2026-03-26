// Copyright (c) Final Evolution Lab.

#include "UFELDojoTempestMinigameComponent.h"
#include "FELDojoNeuralTempest.h"
#include "UFELCreatorCard.h"
#include "Math/UnrealMathUtility.h"

UFELDojoTempestMinigameComponent::UFELDojoTempestMinigameComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	SetComponentTickEnabled(false);
}

void UFELDojoTempestMinigameComponent::InitializeFromReadiness(const FFELReadinessSnapshot& Snap, UFELCreatorCard* OptionalCreatorCard)
{
	CachedSnap = Snap;
	ActiveCreatorCard = OptionalCreatorCard;
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, OptionalCreatorCard, CachedEnergyComposite, CachedStrikeComposite);
	const float PRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	MaxHealth = FELDojoNeuralTempest::ComputeMaxHealthFromPRQ(PRQ);
	Health = MaxHealth;
	StormIntegrity = InitialStormIntegrity;
	CycloneEnergy = 0.f;
	CachedStrikeStrength = FELDojoNeuralTempest::ComputeStrikeStrength(PRQ, CachedStrikeComposite);
	bTempestActive = true;
	bSurgeChannel = false;
	bNotifiedPlayerDepleted = false;
	bNotifiedStormBroken = false;
	SetComponentTickEnabled(true);
}

void UFELDojoTempestMinigameComponent::StopTempest()
{
	bTempestActive = false;
	SetComponentTickEnabled(false);
}

void UFELDojoTempestMinigameComponent::SetSurgeChannelActive(const bool bActive)
{
	bSurgeChannel = bActive;
}

bool UFELDojoTempestMinigameComponent::TryCommitTempestBurst(const float EnergyCost, float& OutDamageToStorm)
{
	OutDamageToStorm = 0.f;
	if (!bTempestActive || CycloneEnergy + KINDA_SMALL_NUMBER < EnergyCost)
	{
		return false;
	}
	const float Charge01 = FMath::Clamp(CycloneEnergy / 100.f, 0.f, 1.f);
	CycloneEnergy = FMath::Max(0.f, CycloneEnergy - EnergyCost);
	const float CostNorm = EnergyCost / FMath::Max(DefaultBurstEnergyCost, 5.f);
	const float D = CachedStrikeStrength * FMath::Lerp(0.78f, 1.28f, Charge01) * FMath::Clamp(CostNorm, 0.65f, 1.4f);
	OutDamageToStorm = D;
	StormIntegrity = FMath::Max(0.f, StormIntegrity - D);
	if (StormIntegrity <= KINDA_SMALL_NUMBER && !bNotifiedStormBroken)
	{
		bNotifiedStormBroken = true;
		OnStormBroken.Broadcast();
		StopTempest();
	}
	return true;
}

float UFELDojoTempestMinigameComponent::GetHealthNormalized() const
{
	return MaxHealth > KINDA_SMALL_NUMBER ? FMath::Clamp(Health / MaxHealth, 0.f, 1.f) : 0.f;
}

float UFELDojoTempestMinigameComponent::GetCycloneEnergyNormalized() const
{
	return FMath::Clamp(CycloneEnergy / 100.f, 0.f, 1.f);
}

float UFELDojoTempestMinigameComponent::GetStormIntegrityNormalized() const
{
	const float Den = FMath::Max(InitialStormIntegrity, 1.f);
	return FMath::Clamp(StormIntegrity / Den, 0.f, 1.f);
}

void UFELDojoTempestMinigameComponent::TickComponent(
	const float DeltaTime,
	const ELevelTick TickType,
	FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (!bTempestActive)
	{
		return;
	}
	const float PRQ = static_cast<float>(FMath::Clamp(CachedSnap.PRQScore, 0.0, 100.0));
	const float N = static_cast<float>(FMath::Clamp(CachedSnap.NeuralDrive, 0.0, 100.0));
	const float K = static_cast<float>(FMath::Clamp(CachedSnap.KineticLeakageMultiplier, 0.45, 1.0));
	const float Mitigate = FMath::Clamp(1.12f - PRQ * 0.0042f, 0.62f, 1.12f);
	const float SquallDps = BaseSquallDamagePerSecond * Mitigate * FMath::Lerp(1.18f, 0.88f, K);
	Health = FMath::Max(0.f, Health - SquallDps * DeltaTime);
	float Regen = FELDojoNeuralTempest::ComputeEnergyRegenPerSecond(PRQ, N, K, CachedEnergyComposite);
	if (bSurgeChannel)
	{
		Regen *= SurgeChannelRegenMultiplier;
	}
	CycloneEnergy = FMath::Clamp(CycloneEnergy + Regen * DeltaTime, 0.f, 100.f);
	if (Health <= KINDA_SMALL_NUMBER && !bNotifiedPlayerDepleted)
	{
		bNotifiedPlayerDepleted = true;
		OnPlayerTempestDepleted.Broadcast();
		StopTempest();
	}
}
