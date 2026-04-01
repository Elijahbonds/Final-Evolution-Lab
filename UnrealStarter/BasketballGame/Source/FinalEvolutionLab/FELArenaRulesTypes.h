// Copyright (c) Final Evolution Lab.
// Data-driven arena rules (loaded from ArenaSettings.json, merged with readiness `active_mode`).

#pragma once

#include "CoreMinimal.h"
#include "UObject/SoftObjectPtr.h"
#include "FELBasketballModes.h"
#include "FELJumpTimingTypes.h"
#include "FELKarateLabModes.h"
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

	// --- Dunk Contest — NBA Live-style presentation + THPS-style style meter / chain multiplier ---
	/** Style meter decay per second when idle (THPS “lose the line” pressure). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0"))
	float DunkContestStyleDecayPerSecond = 0.38f;

	/** Perfect gather → style meter gain (scaled by PRQ + Creator Card composite). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0"))
	float DunkContestStyleGainPerfect = 20.f;

	/** Good gather → smaller style gain. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0"))
	float DunkContestStyleGainGood = 8.f;

	/** Early / Late leaky approaches drain style slightly (skate-sim penalty). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0"))
	float DunkContestStyleLeakPenalty = 6.f;

	/** Seconds to keep a chain alive after a qualifying approach (THPS combo grace). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0.1", UIMin = "0.1"))
	float DunkContestChainGraceSeconds = 2.85f;

	/** Base max score multiplier from style (before PRQ ceiling lift). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "1"))
	float DunkContestMultiplierCapBase = 3.2f;

	/** Added to cap for each PRQ point (0–100) — high PRQ raises ceiling. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0"))
	float DunkContestMultiplierCapPerPRQPoint = 0.018f;

	/** PRQ scales how much each Perfect fills the meter (NBA Live “in the zone” feel). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|DunkContest", meta = (ClampMin = "0"))
	float DunkContestPRQStyleFillBonus = 0.22f;

	// --- Street basketball (H2H / 3v3) — sim base + Vol.2-style trick meter, combos, gamebreaker bonus ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamTrickDecayPerSecond = 0.22f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamTrickGainGatherPerfect = 12.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamTrickGainGatherGood = 5.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamTrickLeakPenalty = 4.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0.1", UIMin = "0.1"))
	float StreetJamGatherChainGraceSeconds = 2.4f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamTrickGainOnBucket = 9.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0.1", UIMin = "0.1"))
	float StreetJamBucketChainGraceSeconds = 3.5f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "1"))
	float StreetJamMultiplierCapBase = 2.65f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamMultiplierCapPerPRQPoint = 0.016f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamPRQTrickFillBonus = 0.2f;

	/** Flat points when a banked gamebreaker pays out on the next made bucket. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|StreetJam", meta = (ClampMin = "0"))
	float StreetJamGamebreakerBonusPoints = 4.f;

	// --- Switch Sports (Tennis / Volleyball) — Nintendo Switch Sports–style generous windows; PRQ + Creator Card ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "0"))
	float SwitchTennisExtraConeDeg = 0.85f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "0"))
	float SwitchTennisConeBonusPerPRQDeg = 0.014f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "0"))
	float SwitchVolleyballExtraSpikeMarginMs = 14.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "0"))
	float SwitchVolleyballSpikeMarginPerPRQMs = 0.12f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "0.8", ClampMax = "1.05"))
	float SwitchCreatorTimingMin = 0.9f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "1", ClampMax = "1.2"))
	float SwitchCreatorTimingMax = 1.12f;

	/** Max added walk-speed fraction at PRQ=100 and max Creator timing (applied on tennis/volleyball courts). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|SwitchSports", meta = (ClampMin = "0", ClampMax = "0.12"))
	float SwitchCourtWalkBonusMax = 0.042f;

	// --- Football kick return wave sim — turn-based vs ghost opponent, PRQ speed + durability ---
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "1"))
	float KickReturnBaseYardsPerSecond = 12.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0"))
	float KickReturnPRQSpeedCoef = 0.45f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0"))
	float KickReturnPRQDurabilityCoef = 0.55f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0"))
	float KickReturnGaugeFillPerSecond = 0.22f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0"))
	float KickReturnWaveRamp = 0.065f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0.5", ClampMax = "1"))
	float KickReturnTackleDurabilityMult = 0.88f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0", ClampMax = "0.5"))
	float KickReturnTdDurabilityRecover = 0.14f;

	/** Ghost opponent PRQ (until multiplayer feeds real profile). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|SportNeuro|KickReturn", meta = (ClampMin = "0", ClampMax = "100"))
	float KickReturnGhostOpponentPRQ = 72.f;

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

	/** True for Dunk Contest / Lab dunk (NeuroKineticLeakage + Unreal physics slice). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	bool bIsDunkContest = false;

	/**
	 * Head-to-head / 3v3 arcade layer: trick meter, bucket combos, PRQ/Creator scaling, gamebreaker bonus (mutually exclusive with dunk contest).
	 */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena")
	bool bStreetJamArcade = false;

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

	/** When `EFELArenaMode::Karate` — which C++ / BP Karate loop to run (H2H storm vs endless agents). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Arena|Karate")
	EFELKarateLabMode KarateLabMode = EFELKarateLabMode::HeadToHeadStorm;
};
