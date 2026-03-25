// Copyright (c) Final Evolution Lab.
// System Scan — PRQ / vertical / flight derivation. Keep numeric policy aligned with Swift `PRQ.fromVerticalInches` + `SystemScanView.generateScanResult`.

#pragma once

#include "CoreMinimal.h"

namespace FELPRQScanFormula
{
	/**
	 * Weighted non-linear readiness from vertical potential (0–100).
	 * Smoothstep + sqrt blend: rewards mid–elite vertical with diminishing returns at extremes (Bonds Bounce calibration).
	 */
	inline double ScoreFromVerticalInches(double VerticalInches)
	{
		if (!FMath::IsFinite(VerticalInches) || VerticalInches < 0.0)
		{
			return 75.0;
		}
		const double V = FMath::Clamp(VerticalInches, 0.0, 55.0);
		const double T = (V - 15.0) / 35.0;
		const double S = FMath::Clamp(T, 0.0, 1.0);
		const double Smooth = S * S * (3.0 - 2.0 * S);
		const double Neural = FMath::Sqrt(S + 1e-6);
		const double Blend = 0.58 * Smooth + 0.42 * Neural;
		return FMath::Clamp(100.0 * Blend, 0.0, 100.0);
	}

	/** Goal tier 0 = generic, 1 = speed, 2 = jump, 3 = power — maps Swift goal strings. */
	inline int32 GoalTierFromString(const FString& Goal)
	{
		if (Goal.Contains(TEXT("Jump")) || Goal.Contains(TEXT("jump")))
		{
			return 2;
		}
		if (Goal.Contains(TEXT("Faster")) || Goal.Contains(TEXT("faster")))
		{
			return 1;
		}
		if (Goal.Contains(TEXT("Power")) || Goal.Contains(TEXT("power")))
		{
			return 3;
		}
		return 0;
	}

	/**
	 * Deterministic pseudo-random 0..1 from seed (replaces Swift `Double.random` for repeatable Unreal analysis).
	 */
	inline double Hash01(int32 Seed)
	{
		const uint32 U = static_cast<uint32>(Seed) * 2654435761u;
		return static_cast<double>(U & 0x00FFFFFFu) / static_cast<double>(0x01000000u);
	}

	/** Base vertical inches range by goal tier (aligned with Swift scan bands). */
	inline void GoalTierVerticalRange(int32 Tier, double& OutMin, double& OutMax)
	{
		switch (Tier)
		{
		case 2:
			OutMin = 22.0;
			OutMax = 32.0;
			break; // Jump Higher
		case 1:
			OutMin = 18.0;
			OutMax = 28.0;
			break; // Get Faster
		case 3:
			OutMin = 24.0;
			OutMax = 34.0;
			break; // Build Power
		default:
			OutMin = 20.0;
			OutMax = 28.0;
			break;
		}
	}

	/** Base flight seconds range by tier. */
	inline void GoalTierFlightRange(int32 Tier, double& OutMin, double& OutMax)
	{
		switch (Tier)
		{
		case 2:
			OutMin = 0.45;
			OutMax = 0.65;
			break;
		case 1:
			OutMin = 0.38;
			OutMax = 0.55;
			break;
		case 3:
			OutMin = 0.50;
			OutMax = 0.68;
			break;
		default:
			OutMin = 0.40;
			OutMax = 0.55;
			break;
		}
	}

	/**
	 * Core PRQ blend: vertical-driven score (Swift PRQ.fromVerticalInches) + flight reactivity + small goal tier bias.
	 * Optional video: refines flight from clip duration (Swift: clipFlight = clamp(duration * 0.4, 0.35, 0.9) * jitter).
	 */
	inline double ComputePRQ0to100(double VerticalInches, double FlightSeconds, int32 GoalTier, int32 DeterminismSeed)
	{
		double VMin = 20.0, VMax = 28.0;
		GoalTierVerticalRange(GoalTier, VMin, VMax);
		const double Vert = FMath::IsFinite(VerticalInches) ? FMath::Clamp(VerticalInches, VMin, VMax) : FMath::Lerp(VMin, VMax, Hash01(DeterminismSeed));

		double FMin = 0.4, FMax = 0.55;
		GoalTierFlightRange(GoalTier, FMin, FMax);
		double Flt = FMath::IsFinite(FlightSeconds) ? FMath::Clamp(FlightSeconds, 0.2, 1.2) : FMath::Lerp(FMin, FMax, Hash01(DeterminismSeed + 17));

		const double PqVert = ScoreFromVerticalInches(Vert);
		const double PqFlight = FMath::Clamp(Flt * 95.0, 0.0, 100.0);
		const double TierBias = static_cast<double>(GoalTier) * 2.5; // small nudge: power/jump tiers

		// Vertical potential + neural reactive power (flight) — single 0–100 readiness.
		double PRQ = 0.48 * PqVert + 0.42 * PqFlight + TierBias * 0.10;
		PRQ = FMath::Clamp(PRQ, 0.0, 100.0);
		return PRQ;
	}

	/** If optional video exists: flightSeconds ≈ clamp(duration * 0.4, 0.35, 0.9) * (0.92..1.08) — Swift SystemScanView. */
	inline double FlightFromVideoDurationSeconds(double DurationSeconds, int32 DeterminismSeed)
	{
		if (DurationSeconds <= 0.0 || !FMath::IsFinite(DurationSeconds))
		{
			return -1.0; // sentinel: caller uses tier default
		}
		const double ClipFlight = FMath::Clamp(DurationSeconds * 0.4, 0.35, 0.9);
		const double Jitter = 0.92 + 0.16 * Hash01(DeterminismSeed + 901);
		return FMath::Clamp(ClipFlight * Jitter, 0.2, 1.15);
	}

	inline FString MovementGradeFromPRQ(double PRQ)
	{
		if (PRQ >= 80.0)
		{
			return TEXT("ELITE POTENTIAL");
		}
		if (PRQ >= 65.0)
		{
			return TEXT("FLIGHT READY");
		}
		if (PRQ >= 50.0)
		{
			return TEXT("BUILDING BASE");
		}
		return TEXT("FOUNDATION PHASE");
	}

	inline FString RecommendedTrackFromTier(int32 GoalTier)
	{
		switch (GoalTier)
		{
		case 2:
			return TEXT("Flight");
		case 3:
			return TEXT("Elite");
		case 1:
			return TEXT("Foundations");
		default:
			return TEXT("Foundations");
		}
	}
}
