// Copyright (c) Final Evolution Lab.
// Dojo — "Neural Tempest" mini-game (original FEL design): survive a rising neural squall, bank Cyclone Energy,
// then commit bursts to break the storm. Not point sparring — storm-style pacing with PRQ + Creator Card scaling.

#pragma once

#include "CoreMinimal.h"
#include "FELReadinessTypes.h"

class UFELCreatorCard;

namespace FELDojoNeuralTempest
{
	/** Max player health scales with PRQ — higher readiness = wider buffer under pressure. */
	FINALEVOLUTIONLAB_API float ComputeMaxHealthFromPRQ(float PRQ0to100);

	/** Strike power for each Tempest Burst — PRQ + Creator Card strike lane. */
	FINALEVOLUTIONLAB_API float ComputeStrikeStrength(float PRQ0to100, float CreatorStrikeComposite);

	/**
	 * Cyclone Energy regen per second — Neural Drive fuels the meter; kinetic leakage dampens it;
	 * Creator Card energy lane widens the funnel.
	 */
	FINALEVOLUTIONLAB_API float ComputeEnergyRegenPerSecond(
		float PRQ0to100,
		float NeuralDrive0to100,
		float KineticLeakageMultiplier,
		float CreatorEnergyComposite);

	/** Commit window (ms) for releasing a burst at peak tension — PRQ widens the fair band. */
	FINALEVOLUTIONLAB_API float TempestCommitWindowMsFromPRQ(float PRQ0to100, float BaseWindowMs, float PRQExpandMs);

	/** Pull Creator Card composite multipliers; nullptr → derive mild variance from stood card id string. */
	FINALEVOLUTIONLAB_API void ResolveCreatorCardComposites(
		const FFELReadinessSnapshot& Snap,
		const UFELCreatorCard* OptionalCard,
		float& OutEnergyComposite,
		float& OutStrikeComposite);

	/** HUD preview: formatted tempest line without owning the component. */
	FINALEVOLUTIONLAB_API void BuildHudPreviewLine(const FFELReadinessSnapshot& Snap, const UFELCreatorCard* OptionalCard, FString& OutLabel, FString& OutValue);
}
