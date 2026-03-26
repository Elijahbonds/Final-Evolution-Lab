// Copyright (c) Final Evolution Lab.
// Joint flexion / extension (degrees) — Optimal (green), Moderate (amber), Deficit (red).
// Ranges are coaching-friendly defaults for vertical-athlete screening; tune per sport in data assets.

#pragma once

#include "CoreMinimal.h"

struct FELJointAngleThresholds
{
	/** Ankle dorsiflexion in sagittal load (degrees). */
	static constexpr double AnkleOptimalMin = 18.0;
	static constexpr double AnkleOptimalMax = 28.0;
	static constexpr double AnkleModerateLowMax = 18.0;
	static constexpr double AnkleModerateLowMin = 12.0;
	static constexpr double AnkleModerateHighMin = 28.0;
	static constexpr double AnkleModerateHighMax = 35.0;

	/** Knee flexion at takeoff (degrees). */
	static constexpr double KneeOptimalMin = 32.0;
	static constexpr double KneeOptimalMax = 42.0;
	static constexpr double KneeModerateLowMax = 32.0;
	static constexpr double KneeModerateLowMin = 24.0;
	static constexpr double KneeModerateHighMin = 42.0;
	static constexpr double KneeModerateHighMax = 52.0;

	/** Hip extension angle (degrees) — 180 = full extension; typical flight phase 165–178. */
	static constexpr double HipExtensionOptimalMin = 165.0;
	static constexpr double HipExtensionOptimalMax = 178.0;
	static constexpr double HipExtensionModerateLowMax = 165.0;
	static constexpr double HipExtensionModerateLowMin = 155.0;
	static constexpr double HipExtensionModerateHighMin = 178.0;
	static constexpr double HipExtensionModerateHighMax = 180.0;

	enum class EJointBand : uint8
	{
		Optimal,
		Moderate,
		Deficit
	};

	static EJointBand ClassifyAnkleDorsiflexionDeg(double Degrees)
	{
		if (!FMath::IsFinite(Degrees))
		{
			return EJointBand::Deficit;
		}
		if (Degrees >= AnkleOptimalMin && Degrees <= AnkleOptimalMax)
		{
			return EJointBand::Optimal;
		}
		if ((Degrees >= AnkleModerateLowMin && Degrees < AnkleOptimalMin) ||
			(Degrees > AnkleOptimalMax && Degrees <= AnkleModerateHighMax))
		{
			return EJointBand::Moderate;
		}
		return EJointBand::Deficit;
	}

	static EJointBand ClassifyKneeFlexionDeg(double Degrees)
	{
		if (!FMath::IsFinite(Degrees))
		{
			return EJointBand::Deficit;
		}
		if (Degrees >= KneeOptimalMin && Degrees <= KneeOptimalMax)
		{
			return EJointBand::Optimal;
		}
		if ((Degrees >= KneeModerateLowMin && Degrees < KneeOptimalMin) ||
			(Degrees > KneeOptimalMax && Degrees <= KneeModerateHighMax))
		{
			return EJointBand::Moderate;
		}
		return EJointBand::Deficit;
	}

	static EJointBand ClassifyHipExtensionDeg(double Degrees)
	{
		if (!FMath::IsFinite(Degrees))
		{
			return EJointBand::Deficit;
		}
		if (Degrees >= HipExtensionOptimalMin && Degrees <= HipExtensionOptimalMax)
		{
			return EJointBand::Optimal;
		}
		if ((Degrees >= HipExtensionModerateLowMin && Degrees < HipExtensionOptimalMin) ||
			(Degrees > HipExtensionOptimalMax && Degrees <= HipExtensionModerateHighMax))
		{
			return EJointBand::Moderate;
		}
		return EJointBand::Deficit;
	}
};
