// Copyright (c) Final Evolution Lab.
// PRQ-driven difficulty: weaker motion-warp pull + heavier "leaky" animation when readiness is low.

#pragma once

#include "CoreMinimal.h"

namespace FELArenaDifficultyScaling
{
	/**
	 * Sovereign Skins / shard gear — 1.0–1.05 multiplier on motion-warp pull and jump velocity (MyTeam economy).
	 * `gearJumpVelocityMultiplier` in `readiness_snapshot.json` should mirror these ids when exporting;
	 * `AFELBasketballCharacter::ApplyReadiness` applies C++ `CalculateGearBoost` from jersey/shoe paths
	 * so JumpZ uses the same physical scale in the 3D arena.
	 */
	struct FGearBoostMultipliers
	{
		float MotionWarpMagnetismMult = 1.f;
		float JumpVelocityScaleMult = 1.f;
	};

	/** Maps marketplace gear id (e.g. `gear_jersey_cyan_pulse`) to small buffs; unknown → identity. */
	inline FGearBoostMultipliers CalculateGearBoost(const FString& GearId)
	{
		FGearBoostMultipliers Out;
		// Texture paths from the Sovereign marketplace often include "Sovereign" / folder segments — apply jump scale for equipped jersey/shoes.
		if (GearId.Contains(TEXT("sovereign")) || GearId.Contains(TEXT("Sovereign")))
		{
			Out.MotionWarpMagnetismMult = 1.04f;
			Out.JumpVelocityScaleMult = 1.04f;
		}
		else if (GearId.Contains(TEXT("jersey_cyan")) || GearId.Contains(TEXT("gear_jersey_cyan")))
		{
			Out.MotionWarpMagnetismMult = 1.03f;
			Out.JumpVelocityScaleMult = 1.02f;
		}
		else if (GearId.Contains(TEXT("shoes_signal")) || GearId.Contains(TEXT("gear_shoes_signal")))
		{
			Out.MotionWarpMagnetismMult = 1.02f;
			Out.JumpVelocityScaleMult = 1.04f;
		}
		else if (GearId.Contains(TEXT("outfit_neon")) || GearId.Contains(TEXT("neon")))
		{
			Out.MotionWarpMagnetismMult = 1.02f;
			Out.JumpVelocityScaleMult = 1.02f;
		}
		else if (GearId.Contains(TEXT("outfit_gold")) || GearId.Contains(TEXT("gold")))
		{
			Out.MotionWarpMagnetismMult = 1.05f;
			Out.JumpVelocityScaleMult = 1.05f;
		}
		return Out;
	}

	/**
	 * Sovereign Skins: each equipped jersey/shoe/outfit reduces kinetic leakage by ~1–5% (multiplier toward 1.0 from scan baseline).
	 * Values are per-gear factors in (0.95, 1.0] — multiply together, then clamp to [0.95, 1.0].
	 */
	inline float SkinKineticLeakageScaleFromGearId(const FString& GearId)
	{
		if (GearId.Contains(TEXT("sovereign")) || GearId.Contains(TEXT("Sovereign")))
		{
			return 0.97f;
		}
		if (GearId.Contains(TEXT("jersey_cyan")) || GearId.Contains(TEXT("gear_jersey_cyan")))
		{
			return 0.98f;
		}
		if (GearId.Contains(TEXT("shoes_signal")) || GearId.Contains(TEXT("gear_shoes_signal")))
		{
			return 0.99f;
		}
		if (GearId.Contains(TEXT("outfit_neon")) || GearId.Contains(TEXT("neon")))
		{
			return 0.99f;
		}
		if (GearId.Contains(TEXT("outfit_gold")) || GearId.Contains(TEXT("gold")))
		{
			return 0.95f;
		}
		if (GearId.Contains(TEXT("outfit_shadow")))
		{
			return 0.995f;
		}
		if (GearId.Contains(TEXT("outfit_chrome")))
		{
			return 0.992f;
		}
		return 1.f;
	}

	/** Creator Card “Stand” — extra jump / neural presentation (matches `stoodCard*` readiness export). */
	inline void StoodCardPhysicsFromId(const FString& CardId, float& OutJumpScale, float& OutNeuralAlpha)
	{
		OutJumpScale = 1.f;
		OutNeuralAlpha = 1.f;
		if (CardId.Contains(TEXT("coach_v")))
		{
			OutJumpScale = 1.045f;
			OutNeuralAlpha = 1.08f;
		}
		else if (CardId.Contains(TEXT("bonds_bounce")))
		{
			OutJumpScale = 1.055f;
			OutNeuralAlpha = 1.06f;
		}
		else if (CardId.Contains(TEXT("flight_lab")))
		{
			OutJumpScale = 1.04f;
			OutNeuralAlpha = 1.07f;
		}
		else if (CardId.Contains(TEXT("neural_max")))
		{
			OutJumpScale = 1.03f;
			OutNeuralAlpha = 1.12f;
		}
		OutJumpScale = FMath::Clamp(OutJumpScale, 1.f, 1.08f);
		OutNeuralAlpha = FMath::Clamp(OutNeuralAlpha, 1.f, 1.15f);
	}

	/** Aggregated MyTeam asset boosts — Sovereign Gear leakage reduction + Stood Card jump / neural alpha. */
	struct FAssetBoostResult
	{
		float KineticLeakageScale = 1.f;
		float JumpVelocityScale = 1.f;
		float NeuralDriveAlpha = 1.f;
	};

	inline FAssetBoostResult CalculateAssetBoosts(const TArray<FString>& SovereignSkinGearIds, const FString& StoodCreatorCardId)
	{
		FAssetBoostResult R;
		for (const FString& Id : SovereignSkinGearIds)
		{
			if (Id.IsEmpty())
			{
				continue;
			}
			R.KineticLeakageScale *= SkinKineticLeakageScaleFromGearId(Id);
			const FGearBoostMultipliers G = CalculateGearBoost(Id);
			R.JumpVelocityScale *= G.JumpVelocityScaleMult;
		}
		R.KineticLeakageScale = FMath::Clamp(R.KineticLeakageScale, 0.95f, 1.f);
		R.JumpVelocityScale = FMath::Clamp(R.JumpVelocityScale, 1.f, 1.08f);

		float JS = 1.f;
		float NA = 1.f;
		StoodCardPhysicsFromId(StoodCreatorCardId, JS, NA);
		R.JumpVelocityScale *= JS;
		R.NeuralDriveAlpha = NA;
		R.JumpVelocityScale = FMath::Clamp(R.JumpVelocityScale, 1.f, 1.12f);
		return R;
	}

	/** 0–100 PRQ → 0.35–1.0 magnetism toward full warp targets (rim/goal). Below 60, pull is softened. */
	inline float MotionWarpMagnetismFromPRQ(float PRQ0to100)
	{
		const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f);
		if (P >= 60.f)
		{
			return 1.f;
		}
		return FMath::Lerp(0.35f, 1.f, P / 60.f);
	}

	/** When PRQ < 60, extra reduction of "primed" layer alpha (more fatigued / leaky blend). 0 at PRQ ≥ 60. */
	inline float LeakyAnimLayerExtraFromPRQ(float PRQ0to100)
	{
		const float P = FMath::Clamp(PRQ0to100, 0.f, 100.f);
		if (P >= 60.f)
		{
			return 0.f;
		}
		return FMath::Clamp((60.f - P) / 60.f, 0.f, 1.f) * 0.5f;
	}
}
