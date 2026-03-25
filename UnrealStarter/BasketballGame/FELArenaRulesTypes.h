// Copyright (c) Final Evolution Lab.
// Data-driven arena rules (loaded from ArenaSettings.json, merged with readiness `active_mode`).

#pragma once

#include "CoreMinimal.h"
#include "UObject/SoftObjectPtr.h"
#include "FELBasketballModes.h"
#include "FELJumpTimingTypes.h"
#include "FELArenaRulesTypes.generated.h"

class USkeletalMesh;
class UAnimInstance;
class UAnimSequence;

/** Per-mode neuro / biomechanics tuning (12 Arena modes — PROJECT_FLOWS / NEURO_MECHANIC_BRIDGE). */
USTRUCT(BlueprintType)
struct FFELSportNeuroConstants
{
	GENERATED_BODY()

	// --- Soccer / kick & cut ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float SoccerKickPower = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float SoccerLateralStrainThreshold = 0.52f;

	// --- Baseball / swing timing ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float BaseballSwingWindowMs = 85.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float BaseballPerfectWindowPRQExpandMs = 40.f;

	// --- Golf / ball flight ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float GolfSliceMultiplier = 1.f;

	// --- Tennis lateral load ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float TennisLateralStrainThreshold = 0.55f;

	// --- Football / cut ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float FootballLateralStrainThreshold = 0.58f;

	/** Shared: if lateral strain exceeds mode threshold and neuralDrive is below this, apply lateral walk penalty. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro", meta = (ClampMin = "0", ClampMax = "100"))
	float LateralNeuralDriveRequired = 72.f;

	/** Floor on MaxWalkSpeed multiplier when lateral penalty applies (ankle/knee instability). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro", meta = (ClampMin = "0.35", ClampMax = "1"))
	float LateralWalkPenaltyMin = 0.68f;

	// --- Karate / strike ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float KarateStrikeWindowMs = 70.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float KaratePerfectWindowPRQExpandMs = 45.f;

	// --- Volleyball / reaction ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float VolleyballReactionWindowMs = 175.f;

	// --- Gymnastics / tempo ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float GymnasticsTempoScale = 1.f;

	// --- Brain Brawl ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float BrainBrawlCognitionWeight = 1.f;

	// --- Basketball (shared) explosion feel ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	float BasketballDriveExplosionScale = 1.f;

	/**
	 * Production avatar for exercise demonstration (Meshy/Hyperhuman → import under /Game/Models/Avatar/).
	 * Assign per-mode overrides in ArenaSettings.json or the registry factory.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Demonstration")
	TSoftObjectPtr<USkeletalMesh> DemonstratorSkeletalMesh;

	/**
	 * AnimBlueprint-generated class (subclass of UAnimInstance). Runtime does not reference UAnimBlueprint directly.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Demonstration")
	TSoftClassPtr<UAnimInstance> DemonstratorAnimInstanceClass;

	/**
	 * DeepMotion / mocap takeoff clips keyed by Bonds Bounce timing band (Perfect vs leaky early/late).
	 * Assign imported FBX as UAnimSequence; AnimBP uses Motion Warping sync markers targeting `FELMotionWarping::JumpAlignTargetName`.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap|Jump")
	TMap<EFELJumpTimingBand, TSoftObjectPtr<UAnimSequence>> JumpTimingTakeoffSequences;

	/** Optional additive / full-body "fatigued" clip (heavy limbs, reduced hip extension) — layer weight from `FELNeuroAnimLayerBlend`. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap|NeuroLayers")
	TSoftObjectPtr<UAnimSequence> FatiguedLocomotionAdditive;

	/** Optional "primed / elite" additive — blends in as PRQ rises. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap|NeuroLayers")
	TSoftObjectPtr<UAnimSequence> PrimedLocomotionAdditive;

	/** Z offset (cm) from hoop actor origin to hands-at-apex warp point (tune per rim mesh). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Mocap|MotionWarp", meta = (ClampMin = "-80", ClampMax = "120"))
	float DunkJumpWarpZOffsetCM = 28.f;
};

/** How basketball props spawn for this mode (data-driven). */
UENUM(BlueprintType)
enum class EFELArenaBallSpawnType : uint8
{
	None UMETA(DisplayName = "No ball (e.g. quiz / UI-only)"),
	SingleAtPrimary UMETA(DisplayName = "Single at primary offset"),
	DualHalfCourt UMETA(DisplayName = "Dual (half-court second ball)"),
};

/**
 * Runtime rules for one Arena mode — used by AFELBasketballGameMode + neuro bridge.
 * Non-basketball sports still map to a basketball "slice" for this Unreal vertical slice.
 */
USTRUCT(BlueprintType)
struct FFELArenaRules
{
	GENERATED_BODY()

	/** HUD / GameState label (e.g. "Street Ball", "Dunk Contest"). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	FString ModeDisplayName = TEXT("Street Ball");

	/** Spawn pattern; pair with BallCount in ArenaSettings.json when needed. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	EFELArenaBallSpawnType BallSpawnType = EFELArenaBallSpawnType::SingleAtPrimary;

	/** True for Swift Dunk Contest / Lab dunk parity (NeuroKineticLeakage + Unreal physics slice). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	bool bIsDunkContest = false;

	/** Which Unreal basketball rules slice to run (prototype maps all 12 into this enum). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	EFELBasketballPlayMode UnrealBasketballSlice = EFELBasketballPlayMode::StreetBall;

	/** Match time limit in seconds (0 = no clock / GameState default). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	float TimeLimitSeconds = 0.f;

	/** Basketballs to spawn (e.g. Half-Court Shootout = 2). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena", meta = (ClampMin = "0", UIMin = "0"))
	int32 BallCount = 1;

	/** First-to-N buckets when scoring uses a target (0 = mode default / endless practice). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena", meta = (ClampMin = "0", UIMin = "0"))
	int32 TargetScore = 0;

	/** Applied after NeuroMechanic base + FELKineticLeakage (data tuning). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	float PhysicsJumpScale = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	float PhysicsWalkScale = 1.f;

	/** When false, scoring rounds are disabled (e.g. practice / quiz stub). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	bool bScoringEnabled = true;

	/**
	 * Arena Dunk vs Lab Dunk (GAMEPLAY_STATUS): both must use the same FELKineticLeakage path in ApplyReadiness.
	 * JSON should keep this true for `basketball_dunk`; registry defaults enforce for dunk modes.
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	bool bNeuroKineticLeakageForDunkParity = true;

	/** Sport-specific neuro tuning (kick power, lateral cut thresholds, swing windows, etc.). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro")
	FFELSportNeuroConstants SportNeuro;
};
