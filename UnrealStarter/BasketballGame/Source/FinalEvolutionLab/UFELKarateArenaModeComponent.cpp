// Copyright (c) Final Evolution Lab.

#include "UFELKarateArenaModeComponent.h"
#include "FELDojoNeuralTempest.h"
#include "UFELCreatorCard.h"
#include "Math/UnrealMathUtility.h"

UFELKarateArenaModeComponent::UFELKarateArenaModeComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	SetComponentTickEnabled(false);
}

void UFELKarateArenaModeComponent::InitializeKarateFromProfile(
	const FFELReadinessSnapshot& Snap,
	UFELCreatorCard* OptionalCreatorCard)
{
	BeginRun(Snap, OptionalCreatorCard, Snap.KarateLabVariant);
}

void UFELKarateArenaModeComponent::InitializeKarateFromArenaRules(
	const FFELReadinessSnapshot& Snap,
	const FFELArenaRules& Rules,
	UFELCreatorCard* OptionalCreatorCard)
{
	BeginRun(Snap, OptionalCreatorCard, Rules.KarateLabMode);
}

void UFELKarateArenaModeComponent::InitializeKarateWithLabMode(
	const FFELReadinessSnapshot& Snap,
	UFELCreatorCard* OptionalCreatorCard,
	const EFELKarateLabMode Mode)
{
	BeginRun(Snap, OptionalCreatorCard, Mode);
}

void UFELKarateArenaModeComponent::BeginRun(
	const FFELReadinessSnapshot& Snap,
	UFELCreatorCard* OptionalCreatorCard,
	const EFELKarateLabMode Mode)
{
	CachedSnap = Snap;
	ActiveCreatorCard = OptionalCreatorCard;
	ActiveMode = Mode;
	FELKaratePRQBoost::ComputeCombatBoost(static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0)), PRQBoost);
	FELDojoNeuralTempest::ResolveCreatorCardComposites(Snap, OptionalCreatorCard, CachedEnergyComposite, CachedStrikeComposite);
	CachedEnergyComposite *= PRQBoost.PerformanceMultiplier;
	CachedStrikeComposite *= PRQBoost.StrengthMultiplier;

	const float PRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	PlayerMaxHealth = FELDojoNeuralTempest::ComputeMaxHealthFromPRQ(PRQ) * PRQBoost.PerformanceMultiplier;
	PlayerHealth = PlayerMaxHealth;
	PlayerCycloneEnergy = 0.f;
	CachedStrikeStrength = FELDojoNeuralTempest::ComputeStrikeStrength(PRQ, CachedStrikeComposite);

	bNotifiedH2HWin = false;
	bNotifiedH2HLoss = false;
	OpponentThinkAccum = 0.f;

	if (ActiveMode == EFELKarateLabMode::HeadToHeadStorm)
	{
		OpponentIntegrity = InitialOpponentIntegrity * FMath::Lerp(1.08f, 0.92f, PRQ * 0.01f);
		OpponentCycloneEnergy = 15.f;
		WaveIntegrityPool = 0.f;
		EndlessWaveIndex = 1;
	}
	else
	{
		OpponentIntegrity = 0.f;
		OpponentCycloneEnergy = 0.f;
		EndlessWaveIndex = 1;
		EndlessWaveMaxForNorm = EndlessWaveBaseIntegrity * FMath::Pow(1.1f, static_cast<float>(EndlessWaveIndex - 1));
		WaveIntegrityPool = EndlessWaveMaxForNorm;
	}

	bArenaActive = true;
	SetComponentTickEnabled(true);
}

void UFELKarateArenaModeComponent::StopKarateArena()
{
	bArenaActive = false;
	SetComponentTickEnabled(false);
}

void UFELKarateArenaModeComponent::SetPlayerSurgeChannelActive(const bool bActive)
{
	bPlayerSurge = bActive;
}

bool UFELKarateArenaModeComponent::TryPlayerTempestBurst(const float EnergyCost, float& OutDamageToTarget)
{
	OutDamageToTarget = 0.f;
	if (!bArenaActive || PlayerCycloneEnergy + KINDA_SMALL_NUMBER < EnergyCost)
	{
		return false;
	}
	const float Charge01 = FMath::Clamp(PlayerCycloneEnergy / 100.f, 0.f, 1.f);
	PlayerCycloneEnergy = FMath::Max(0.f, PlayerCycloneEnergy - EnergyCost);
	const float CostN = EnergyCost / FMath::Max(DefaultBurstEnergyCost, 5.f);
	OutDamageToTarget = CachedStrikeStrength * FMath::Lerp(0.75f, 1.3f, Charge01) * FMath::Clamp(CostN, 0.65f, 1.45f);

	if (ActiveMode == EFELKarateLabMode::HeadToHeadStorm)
	{
		OpponentIntegrity = FMath::Max(0.f, OpponentIntegrity - OutDamageToTarget);
		if (OpponentIntegrity <= KINDA_SMALL_NUMBER && !bNotifiedH2HWin)
		{
			bNotifiedH2HWin = true;
			OnHeadToHeadVictory.Broadcast();
			StopKarateArena();
		}
	}
	else
	{
		WaveIntegrityPool = FMath::Max(0.f, WaveIntegrityPool - OutDamageToTarget);
		if (WaveIntegrityPool <= KINDA_SMALL_NUMBER)
		{
			const float HealFrac = (ActiveMode == EFELKarateLabMode::MatrixRevolutionsSiege) ? 0.065f : 0.085f;
			const float Heal = PlayerMaxHealth * HealFrac * PRQBoost.PerformanceMultiplier;
			PlayerHealth = FMath::Min(PlayerMaxHealth, PlayerHealth + Heal);
			EndlessWaveIndex += 1;
			EndlessWaveMaxForNorm = EndlessWaveBaseIntegrity * FMath::Pow(1.1f, static_cast<float>(EndlessWaveIndex - 1));
			WaveIntegrityPool = EndlessWaveMaxForNorm;
			OnEndlessWaveAdvanced.Broadcast(EndlessWaveIndex);
		}
	}
	return true;
}

float UFELKarateArenaModeComponent::GetPlayerHealthNormalized() const
{
	return PlayerMaxHealth > KINDA_SMALL_NUMBER ? FMath::Clamp(PlayerHealth / PlayerMaxHealth, 0.f, 1.f) : 0.f;
}

float UFELKarateArenaModeComponent::GetPlayerCycloneNormalized() const
{
	return FMath::Clamp(PlayerCycloneEnergy / 100.f, 0.f, 1.f);
}

float UFELKarateArenaModeComponent::GetPrimaryTargetNormalized() const
{
	if (ActiveMode == EFELKarateLabMode::HeadToHeadStorm)
	{
		const float Den = FMath::Max(InitialOpponentIntegrity, 1.f);
		return FMath::Clamp(OpponentIntegrity / Den, 0.f, 1.f);
	}
	if (EndlessWaveMaxForNorm <= KINDA_SMALL_NUMBER)
	{
		return 0.f;
	}
	return FMath::Clamp(WaveIntegrityPool / EndlessWaveMaxForNorm, 0.f, 1.f);
}

void UFELKarateArenaModeComponent::TickComponent(
	const float DeltaTime,
	const ELevelTick TickType,
	FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if (!bArenaActive)
	{
		return;
	}
	if (ActiveMode == EFELKarateLabMode::HeadToHeadStorm)
	{
		TickHeadToHead(DeltaTime);
	}
	else
	{
		TickEndless(DeltaTime);
	}
}

void UFELKarateArenaModeComponent::TickHeadToHead(const float DeltaTime)
{
	const float PRQ = static_cast<float>(FMath::Clamp(CachedSnap.PRQScore, 0.0, 100.0));
	const float N = static_cast<float>(FMath::Clamp(CachedSnap.NeuralDrive, 0.0, 100.0));
	const float K = static_cast<float>(FMath::Clamp(CachedSnap.KineticLeakageMultiplier, 0.45, 1.0));
	const float Mitigate = FMath::Clamp(1.1f - PRQ * 0.004f, 0.62f, 1.1f) * PRQBoost.PerformanceMultiplier;
	const float Squall = BaseSquallDamagePerSecond * Mitigate * FMath::Lerp(1.12f, 0.86f, K);
	PlayerHealth = FMath::Max(0.f, PlayerHealth - Squall * DeltaTime);
	float Regen = FELDojoNeuralTempest::ComputeEnergyRegenPerSecond(PRQ, N, K, CachedEnergyComposite);
	if (bPlayerSurge)
	{
		Regen *= SurgeChannelRegenMultiplier;
	}
	PlayerCycloneEnergy = FMath::Clamp(PlayerCycloneEnergy + Regen * DeltaTime, 0.f, 100.f);

	// Opponent cyclone regen (slower than athlete with high PRQ)
	const float OppRegen = FMath::Max(0.8f, 3.2f - PRQ * 0.018f);
	OpponentCycloneEnergy = FMath::Clamp(OpponentCycloneEnergy + OppRegen * DeltaTime, 0.f, 100.f);
	TickOpponentAI(DeltaTime);

	if (PlayerHealth <= KINDA_SMALL_NUMBER && !bNotifiedH2HLoss)
	{
		bNotifiedH2HLoss = true;
		OnHeadToHeadDefeat.Broadcast();
		StopKarateArena();
	}
}

void UFELKarateArenaModeComponent::TickOpponentAI(const float DeltaTime)
{
	OpponentThinkAccum += DeltaTime;
	const float PRQ = static_cast<float>(FMath::Clamp(CachedSnap.PRQScore, 0.0, 100.0));
	const float Interval = FMath::Clamp(1.35f - PRQ * 0.0045f, 0.65f, 1.45f);
	if (OpponentThinkAccum < Interval)
	{
		return;
	}
	OpponentThinkAccum = 0.f;
	if (OpponentCycloneEnergy < 32.f || OpponentIntegrity <= KINDA_SMALL_NUMBER)
	{
		return;
	}
	OpponentCycloneEnergy = FMath::Max(0.f, OpponentCycloneEnergy - 28.f);
	const float OppStrike = FMath::Max(6.f, (11.f + (100.f - PRQ) * 0.12f) * FMath::FRandRange(0.88f, 1.08f));
	PlayerHealth = FMath::Max(0.f, PlayerHealth - OppStrike);
}

void UFELKarateArenaModeComponent::TickEndless(const float DeltaTime)
{
	const float PRQ = static_cast<float>(FMath::Clamp(CachedSnap.PRQScore, 0.0, 100.0));
	const float N = static_cast<float>(FMath::Clamp(CachedSnap.NeuralDrive, 0.0, 100.0));
	const float K = static_cast<float>(FMath::Clamp(CachedSnap.KineticLeakageMultiplier, 0.45, 1.0));
	const bool bMatrixSiege = (ActiveMode == EFELKarateLabMode::MatrixRevolutionsSiege);
	const float WaveT = static_cast<float>(EndlessWaveIndex - 1);
	const float WaveScale = 1.f + WaveT * (bMatrixSiege ? 0.095f : 0.065f);
	float Mitigate = FMath::Clamp(1.08f - PRQ * 0.0038f, 0.58f, 1.08f) * PRQBoost.PerformanceMultiplier;
	if (bMatrixSiege && bPlayerSurge)
	{
		Mitigate *= 0.76f;
	}
	const float SiegeHordeMul = bMatrixSiege ? (1.f + WaveT * 0.038f) : 1.f;
	const float SquallMul = bMatrixSiege ? 1.14f : 1.f;
	const float Squall = BaseSquallDamagePerSecond * Mitigate * WaveScale * SiegeHordeMul * SquallMul
		* FMath::Lerp(1.1f, 0.88f, K);
	PlayerHealth = FMath::Max(0.f, PlayerHealth - Squall * DeltaTime);
	float Regen = FELDojoNeuralTempest::ComputeEnergyRegenPerSecond(PRQ, N, K, CachedEnergyComposite);
	if (bPlayerSurge)
	{
		Regen *= SurgeChannelRegenMultiplier;
	}
	PlayerCycloneEnergy = FMath::Clamp(PlayerCycloneEnergy + Regen * DeltaTime, 0.f, 100.f);

	if (PlayerHealth <= KINDA_SMALL_NUMBER && !bNotifiedH2HLoss)
	{
		bNotifiedH2HLoss = true;
		OnHeadToHeadDefeat.Broadcast();
		StopKarateArena();
	}
}
