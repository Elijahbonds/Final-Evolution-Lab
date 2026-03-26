// Copyright (c) Final Evolution Lab.

#include "FELDojoNeuralTempest.h"
#include "UFELCreatorCard.h"
#include "Math/UnrealMathUtility.h"

float FELDojoNeuralTempest::ComputeMaxHealthFromPRQ(const float PRQ0to100)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	return FMath::Clamp(68.f + P * 0.38f, 72.f, 118.f);
}

float FELDojoNeuralTempest::ComputeStrikeStrength(const float PRQ0to100, const float CreatorStrikeComposite)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	const float C = FMath::Clamp(CreatorStrikeComposite, 0.75f, 1.35f);
	return FMath::Max(4.f, (9.f + P * 0.28f) * C);
}

float FELDojoNeuralTempest::ComputeEnergyRegenPerSecond(
	const float PRQ0to100,
	const float NeuralDrive0to100,
	const float KineticLeakageMultiplier,
	const float CreatorEnergyComposite)
{
	const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f) * 0.01f;
	const float N = FMath::Clamp(NeuralDrive0to100, 0.f, 100.f) * 0.01f;
	const float K = FMath::Clamp(KineticLeakageMultiplier, 0.45f, 1.f);
	const float C = FMath::Clamp(CreatorEnergyComposite, 0.7f, 1.4f);
	const float LeakDamp = FMath::Lerp(0.72f, 1.f, K);
	return FMath::Max(0.5f, (2.1f + N * 5.5f + P * 2.8f) * LeakDamp * C);
}

float FELDojoNeuralTempest::TempestCommitWindowMsFromPRQ(
	const float PRQ0to100,
	const float BaseWindowMs,
	const float PRQExpandMs)
{
	const float PRQ = FMath::Clamp(PRQ0to100, 0.f, 100.f);
	return BaseWindowMs + PRQ * 0.01f * PRQExpandMs;
}

static float HashStoodCardToComposite(const FString& Id)
{
	if (Id.IsEmpty())
	{
		return 1.f;
	}
	uint32 H = 2166136261u;
	for (const TCHAR* C = *Id; *C; ++C)
	{
		H ^= static_cast<uint32>(*C);
		H *= 16777619u;
	}
	const float T = static_cast<float>(H % 1000) / 1000.f;
	return FMath::Lerp(0.94f, 1.08f, T);
}

void FELDojoNeuralTempest::ResolveCreatorCardComposites(
	const FFELReadinessSnapshot& Snap,
	const UFELCreatorCard* OptionalCard,
	float& OutEnergyComposite,
	float& OutStrikeComposite)
{
	if (OptionalCard)
	{
		const float PrqM = FMath::Clamp(OptionalCard->PRQMultiplier, 0.75f, 1.35f);
		const float ArenaM = FMath::Clamp(OptionalCard->ArenaPerformanceMultiplier, 0.8f, 1.3f);
		const float HangM = FMath::Clamp(OptionalCard->HangTimeMultiplier, 0.85f, 1.25f);
		const float CourtM = FMath::Clamp(OptionalCard->CourtIQMultiplier, 0.85f, 1.25f);
		const float EReg = FMath::Clamp(OptionalCard->DojoTempestEnergyRegenScale, 0.75f, 1.4f);
		const float SStr = FMath::Clamp(OptionalCard->DojoTempestStrikePowerScale, 0.75f, 1.45f);
		OutEnergyComposite = FMath::Clamp(PrqM * FMath::Lerp(1.f, HangM, 0.45f) * FMath::Lerp(1.f, CourtM, 0.35f) * EReg, 0.65f, 1.5f);
		OutStrikeComposite = FMath::Clamp(PrqM * ArenaM * FMath::Lerp(1.f, HangM, 0.5f) * SStr, 0.65f, 1.55f);
		return;
	}
	const float H = HashStoodCardToComposite(Snap.StoodCreatorCardId);
	OutEnergyComposite = H;
	OutStrikeComposite = FMath::Lerp(H, 1.05f, 0.5f);
}

void FELDojoNeuralTempest::BuildHudPreviewLine(
	const FFELReadinessSnapshot& Snap,
	const UFELCreatorCard* OptionalCard,
	FString& OutLabel,
	FString& OutValue)
{
	float E = 1.f;
	float S = 1.f;
	ResolveCreatorCardComposites(Snap, OptionalCard, E, S);
	const float PRQ = static_cast<float>(FMath::Clamp(Snap.PRQScore, 0.0, 100.0));
	const float HP = ComputeMaxHealthFromPRQ(PRQ);
	const float Str = ComputeStrikeStrength(PRQ, S);
	const float Regen = ComputeEnergyRegenPerSecond(
		PRQ,
		static_cast<float>(FMath::Clamp(Snap.NeuralDrive, 0.0, 100.0)),
		static_cast<float>(FMath::Clamp(Snap.KineticLeakageMultiplier, 0.45, 1.0)),
		E);
	OutLabel = TEXT("Neural Tempest");
	OutValue = FString::Printf(TEXT("HP %.0f · Str %.0f · Cyclone +%.1f/s"), HP, Str, Regen);
}
