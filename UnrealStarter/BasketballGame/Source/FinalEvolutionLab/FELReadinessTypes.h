// Copyright (c) Final Evolution Lab.
// Mirrors FinalEvolutionLab/Models/PerformanceMetrics.swift (Codable keys).

#pragma once

#include "CoreMinimal.h"
#include "FELKarateLabModes.h"
#include "FELReadinessTypes.generated.h"

/** Creator Card → Arena signature move (Economy pillar; parsed from `signature_trait_id` in readiness JSON). */
UENUM(BlueprintType)
enum class EFELSignatureTrait : uint8
{
	None UMETA(DisplayName = "None"),
	Bonds_Apex_Ignition UMETA(DisplayName = "Bonds Apex Ignition"),
	Dojo_Ghost_Strike UMETA(DisplayName = "Dojo Ghost Strike"),
	Neuro_Flow_Teleport UMETA(DisplayName = "Neuro Flow Teleport"),
};

FORCEINLINE EFELSignatureTrait FEL_ParseSignatureTraitId(const FString& Id)
{
	FString L = Id;
	L.ToLowerInline();
	if (L == TEXT("bonds_apex_ignition"))
	{
		return EFELSignatureTrait::Bonds_Apex_Ignition;
	}
	if (L == TEXT("dojo_ghost_strike"))
	{
		return EFELSignatureTrait::Dojo_Ghost_Strike;
	}
	if (L == TEXT("neuro_flow_teleport"))
	{
		return EFELSignatureTrait::Neuro_Flow_Teleport;
	}
	return EFELSignatureTrait::None;
}

USTRUCT(BlueprintType)
struct FFELReadinessSnapshot
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double EfficiencyScore = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double PRQScore = 75.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double ReadinessScore = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double VerticalPotential = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double NeuralDrive = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	double PopForce = 0.0;

	/** Scan-derived vertical estimate (inches). Swift `SystemScanResult.verticalEstimateInches`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	double VerticalEstimateInches = 0.0;

	/** 0.75–1.15 typical; scales hang-time / jump apex feel from PRQ + flight time. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	double HangTimeScale = 1.0;

	/** 0.55–1.0; reduces effective verticality when ankle/knee/hip scan status is not PRIMED. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|NeuroMechanic")
	double KineticLeakageMultiplier = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL")
	FString CurrentOutfit = TEXT("standard");

	/** Swift `GameModeId.rawValue` — drives ArenaSettings + Unreal rules (e.g. `basketball_dunk`, `brain_brawl`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	FString ActiveArenaMode = TEXT("basketball_h2h");

	/**
	 * Karate lab variant when `active_mode` resolves to `karate` (or aliases `karate_h2h`, `karate_endless`).
	 * Also set from JSON key `karateLabMode`: `h2h` | `head_to_head` | `endless` | `agents`.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena|Karate")
	EFELKarateLabMode KarateLabVariant = EFELKarateLabMode::HeadToHeadStorm;

	/** True when `karateLabMode` or a `karate_*` active_mode alias set the variant — else ArenaSettings.json may own it. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena|Karate")
	bool bKarateLabVariantFromHost = false;

	// --- System Scan / Athlete Hub (optional keys; Swift `FELBirthReadinessWriter` / extended PRQ export) ---

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	FString MovementGrade;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double FlightTimeSeconds = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	bool bAthletePrimed = false;

	/** 0 = cool (primed joint), 1 = hot (leakage) — Ankle / Knee / Hip kinetic map. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double KineticHeatAnkle = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double KineticHeatKnee = 0.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Scan")
	double KineticHeatHip = 0.0;

	/** Vertical Velocity Academy — Plyos (`mod9`) mastery: +2% neuro potential in Dunk Contest. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Academy")
	double AcademyPlyosMasteryBonus = 0.0;

	// --- Lab aesthetic / Vault (Swift profile → soft content paths; optional in readiness_snapshot.json) ---

	/** Content path to UTexture2D for Neuro-Mechanic banner/floor (e.g. `/Game/FEL/UI/Brand/T_NeuroMechanic_Logo.T_NeuroMechanic_Logo`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Brand")
	FString NeuroMechanicLogoTexturePath;

	/** Bonds Bounce Blueprint logo for Lab court / decals. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Brand")
	FString BondsBounceLogoTexturePath;

	/** Up to 3 Creator Card textures for Vault hologram terminal (highest vertical, etc.). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Vault")
	TArray<FString> CreatorCardTexturePaths;

	/** Swift one-shot: first Bio-Sync / twin reveal — `UFELCinematicCameraComponent` orbit + Neuro-Flow ignition. Consumed by bridge after play. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Onboarding")
	bool bPlayTwinBirthCinematicOnce = false;

	/** Holographic welcome line on `AFELVaultHologramTerminalActor` (e.g. shard grant). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Onboarding")
	FString LabWelcomeToast;

	/** Shard marketplace exclusive gear — material texture paths for digital twin (Swift `equippedGearTexturePaths`). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	FString JerseyTexturePath;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	FString ShoeTexturePath;

	/** Aggregated gear buffs from Swift MyTeam economy (1.0–1.05). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	double GearMotionWarpMultiplier = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Economy")
	double GearJumpVelocityMultiplier = 1.0;

	/** Creator Card "stand" in Lab — drives Neuro-Flow presentation scale. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCreatorCardId;

	/** Optional `/Game/.../AssetName.AssetName` for `UFELCreatorCard` (1v1/3v3 Street Jam + PRQ/court scaling). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCreatorCardDataAssetPath;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	double NeuroFlowIntensityScale = 1.0;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCreatorCardTraitLine;

	/** Stood Creator Card — extra jump scale (1.0–1.12) layered after gear jump mult. Swift `stoodCardJumpScale`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	double StoodCardJumpScale = 1.0;

	/** Stood Creator Card — scales primed / neural anim layer alpha (1.0–1.15). Swift `stoodCardNeuralDriveAlpha`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	double StoodCardNeuralDriveAlpha = 1.0;

	/** `standard` | `gold` | `diamond` — Neuro-Flow aura + Vault terminal tint. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam")
	FString StoodCardTier = TEXT("standard");

	/** Swift `signature_trait_id` — unlocks `AFELBasketballCharacter::ExecuteSignatureMove` for equipped Creator Card. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|MyTeam|Signature")
	EFELSignatureTrait SignatureTrait = EFELSignatureTrait::None;

	/** Swift `AvatarSkinConfig.heightScale` — vertical scale on skeletal mesh (Z) vs `readiness_snapshot.json` digital twin. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Avatar")
	double AvatarHeightScale = 1.0;

	/** Swift `AvatarSkinConfig.weightScale` — horizontal blend (X/Y) on mesh for rig parity. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Lab|Avatar")
	double AvatarWeightScale = 1.0;

	/** Swift `sfmaMultiSegmentalRotationPassed` in readiness JSON — drives UFELBiometricOverlays congestion. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SFMA")
	bool bSFMASpiralRotationScreenPass = true;

	/** Free-text interest (Coursebox-style prompt) → guided Brain Brawl path via keyword map in `UFELBrainBrawlAcademySubsystem`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl|Academy")
	FString BrainBrawlInterestPrompt;

	/** Optional friend's curriculum path id from `BrainBrawlCurriculum.json` (parallel-path duel). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|BrainBrawl|Academy")
	FString BrainBrawlOpponentPathId;
};
