// Copyright (c) Final Evolution Lab.
// Prescription Engine: kinetic heat (0–1) from System Scan → prioritized Academy modules.

#pragma once

#include "CoreMinimal.h"
#include "FELAcademyTypes.h"

namespace FELAcademyPrescription
{
	/** Heat bands aligned with Swift PRQManager joint heat mapping (0.12 primed … 0.88 leaking). */
	inline EFELJointLeakageBand BandFromHeat01(double Heat01)
	{
		const double H = FMath::Clamp(Heat01, 0.0, 1.0);
		if (H < 0.30)
		{
			return EFELJointLeakageBand::Primed;
		}
		if (H < 0.65)
		{
			return EFELJointLeakageBand::Moderate;
		}
		return EFELJointLeakageBand::Leaking;
	}

	/**
	 * Rules (Abstract: bridge Scan → prescribed training):
	 * - Moderate+ hip → prioritize Slings (mod5) + Correctives (mod6); add Movement Snacks (mod4) if leaking.
	 * - Moderate+ knee → Correctives + SFMA GPS.
	 * - Moderate+ ankle → CNS Freeway + RFD/ankle (mod8).
	 * - Any leaking joint → add Nutrition (mod11) as medium priority (systemic recovery).
	 */
	inline void ComputePrescription(double AnkleHeat01, double KneeHeat01, double HipHeat01, FFELAcademyPrescriptionResult& Out)
	{
		Out.HighPriorityModuleKeys.Reset();
		Out.MediumPriorityModuleKeys.Reset();

		const EFELJointLeakageBand A = BandFromHeat01(AnkleHeat01);
		const EFELJointLeakageBand K = BandFromHeat01(KneeHeat01);
		const EFELJointLeakageBand H = BandFromHeat01(HipHeat01);

		auto AddHigh = [&](const FString& Key)
		{
			if (!Out.HighPriorityModuleKeys.Contains(Key))
			{
				Out.HighPriorityModuleKeys.Add(Key);
			}
		};
		auto AddMed = [&](const FString& Key)
		{
			if (!Out.MediumPriorityModuleKeys.Contains(Key) && !Out.HighPriorityModuleKeys.Contains(Key))
			{
				Out.MediumPriorityModuleKeys.Add(Key);
			}
		};

		if (H == EFELJointLeakageBand::Moderate || H == EFELJointLeakageBand::Leaking)
		{
			AddHigh(TEXT("mod5"));
			AddHigh(TEXT("mod6"));
			if (H == EFELJointLeakageBand::Leaking)
			{
				AddHigh(TEXT("mod4"));
			}
		}

		if (K == EFELJointLeakageBand::Moderate || K == EFELJointLeakageBand::Leaking)
		{
			AddHigh(TEXT("mod6"));
			AddMed(TEXT("mod2"));
		}

		if (A == EFELJointLeakageBand::Moderate || A == EFELJointLeakageBand::Leaking)
		{
			AddHigh(TEXT("mod1"));
			AddMed(TEXT("mod8"));
		}

		const bool bAnyLeaking = (A == EFELJointLeakageBand::Leaking) || (K == EFELJointLeakageBand::Leaking) || (H == EFELJointLeakageBand::Leaking);
		if (bAnyLeaking)
		{
			AddMed(TEXT("mod11"));
		}

		if (Out.HighPriorityModuleKeys.Num() == 0 && Out.MediumPriorityModuleKeys.Num() == 0)
		{
			AddMed(TEXT("mod9"));
			AddMed(TEXT("mod10"));
			Out.Rationale = TEXT("Joints PRIMED — progress Elastic Engine and Flight Blueprint.");
		}
		else
		{
			Out.Rationale = TEXT("Prescription from kinetic heat map: prioritize high-leakage chains before max plyometric volume.");
		}
	}
}
