// Copyright (c) Final Evolution Lab. All rights reserved.
// Phase 4: Face Rig Type Definitions — Shared enums, structs, and ARKit blend shape data

#pragma once

#include "CoreMinimal.h"
#include "FELFaceRigTypes.generated.h"

// ──────────────────────────────────────────────────────────────────
// Character types for face rig selection
// ──────────────────────────────────────────────────────────────────

UENUM(BlueprintType)
enum class EFELCharacterType : uint8
{
    Player          UMETA(DisplayName = "Player Character"),
    ElijahBonds     UMETA(DisplayName = "Elijah Bonds"),
    AmirSmith       UMETA(DisplayName = "Amir Smith"),
    EricNash        UMETA(DisplayName = "Eric Nash"),
    NPC_TypeA       UMETA(DisplayName = "NPC Type A (Athletic)"),
    NPC_TypeB       UMETA(DisplayName = "NPC Type B (Crowd)"),
    NPC_TypeC       UMETA(DisplayName = "NPC Type C (Coach)")
};

// ──────────────────────────────────────────────────────────────────
// Expression presets
// ──────────────────────────────────────────────────────────────────

UENUM(BlueprintType)
enum class EFELExpression : uint8
{
    Neutral         UMETA(DisplayName = "Neutral"),
    Happy           UMETA(DisplayName = "Happy / Smile"),
    Determined      UMETA(DisplayName = "Determined / Focused"),
    Tired           UMETA(DisplayName = "Tired / Exhausted"),
    Celebrating     UMETA(DisplayName = "Celebrating"),
    Disappointed    UMETA(DisplayName = "Disappointed"),
    Angry           UMETA(DisplayName = "Angry / Intense"),
    Surprised       UMETA(DisplayName = "Surprised"),
    Talking_A       UMETA(DisplayName = "Talking Phoneme A"),
    Talking_E       UMETA(DisplayName = "Talking Phoneme E"),
    Talking_O       UMETA(DisplayName = "Talking Phoneme O"),
    Talking_U       UMETA(DisplayName = "Talking Phoneme U"),
    TrashTalk       UMETA(DisplayName = "Trash Talk Smirk"),
    Pain            UMETA(DisplayName = "Pain / Effort"),
    Recovery        UMETA(DisplayName = "Recovery / Relief")
};

// ──────────────────────────────────────────────────────────────────
// ARKit blend shape indices (52 total, matching Apple ARKit spec)
// ──────────────────────────────────────────────────────────────────

UENUM(BlueprintType)
enum class EFELARKitBlendShape : uint8
{
    // Eyes (14)
    EyeBlinkLeft = 0,
    EyeLookDownLeft,
    EyeLookInLeft,
    EyeLookOutLeft,
    EyeLookUpLeft,
    EyeSquintLeft,
    EyeWideLeft,
    EyeBlinkRight,
    EyeLookDownRight,
    EyeLookInRight,
    EyeLookOutRight,
    EyeLookUpRight,
    EyeSquintRight,
    EyeWideRight,
    // Jaw (4)
    JawForward,
    JawLeft,
    JawRight,
    JawOpen,
    // Mouth (23)
    MouthClose,
    MouthFunnel,
    MouthPucker,
    MouthLeft,
    MouthRight,
    MouthSmileLeft,
    MouthSmileRight,
    MouthFrownLeft,
    MouthFrownRight,
    MouthDimpleLeft,
    MouthDimpleRight,
    MouthStretchLeft,
    MouthStretchRight,
    MouthRollLower,
    MouthRollUpper,
    MouthShrugLower,
    MouthShrugUpper,
    MouthPressLeft,
    MouthPressRight,
    MouthLowerDownLeft,
    MouthLowerDownRight,
    MouthUpperUpLeft,
    MouthUpperUpRight,
    // Brow (5)
    BrowDownLeft,
    BrowDownRight,
    BrowInnerUp,
    BrowOuterUpLeft,
    BrowOuterUpRight,
    // Cheek (3)
    CheekPuff,
    CheekSquintLeft,
    CheekSquintRight,
    // Nose (2)
    NoseSneerLeft,
    NoseSneerRight,
    // Tongue (1)
    TongueOut,
    
    MAX UMETA(Hidden)
};

// ──────────────────────────────────────────────────────────────────
// Face rig configuration per character
// ──────────────────────────────────────────────────────────────────

USTRUCT(BlueprintType)
struct FFELFaceRigConfig
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FaceRig")
    EFELCharacterType CharacterType = EFELCharacterType::Player;

    /** Number of active blend shapes (52 for full, reduced for LOD). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FaceRig")
    int32 ActiveBlendShapeCount = 52;

    /** Morph target name prefix on the skeletal mesh. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FaceRig")
    FString MorphTargetPrefix = TEXT("ARKit_");

    /** Per-blend-shape intensity multipliers. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FaceRig")
    TMap<FName, float> BlendShapeMultipliers;

    /** Signature expressions this character uses most (for AI fallback). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FaceRig")
    TArray<EFELExpression> SignatureExpressions;

    /** Custom blend shape curve overrides (for unique facial features). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|FaceRig")
    TMap<FName, float> CustomCurveOverrides;
};

// ──────────────────────────────────────────────────────────────────
// Expression blend shape data — preset values for each expression
// ──────────────────────────────────────────────────────────────────

USTRUCT(BlueprintType)
struct FFELExpressionData
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    EFELExpression Expression = EFELExpression::Neutral;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    TMap<FName, float> BlendShapeValues;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    float DefaultBlendTime = 0.3f;
};

// ──────────────────────────────────────────────────────────────────
// Expression trigger for gameplay events
// ──────────────────────────────────────────────────────────────────

UENUM(BlueprintType)
enum class EFELGameplayEvent : uint8
{
    ScoreBasket         UMETA(DisplayName = "Score Basket"),
    MissShot            UMETA(DisplayName = "Miss Shot"),
    GetBlocked          UMETA(DisplayName = "Get Blocked"),
    BlockOpponent       UMETA(DisplayName = "Block Opponent"),
    Steal               UMETA(DisplayName = "Steal Ball"),
    GetStolen           UMETA(DisplayName = "Ball Stolen"),
    WinGame             UMETA(DisplayName = "Win Game"),
    LoseGame            UMETA(DisplayName = "Lose Game"),
    CompleteWorkout     UMETA(DisplayName = "Complete Workout"),
    FailExercise        UMETA(DisplayName = "Fail Exercise"),
    StartExercise       UMETA(DisplayName = "Start Exercise"),
    MaxEffort           UMETA(DisplayName = "Max Effort"),
    Recovery            UMETA(DisplayName = "Recovery"),
    Taunt               UMETA(DisplayName = "Taunt / Trash Talk"),
    CutsceneDialogue    UMETA(DisplayName = "Cutscene Dialogue"),
    CutsceneReaction    UMETA(DisplayName = "Cutscene Reaction"),
    ScoreGoal           UMETA(DisplayName = "Score Goal (Soccer)"),
    KnockOut            UMETA(DisplayName = "Knock Out (Boxing/MMA)"),
    PerfectLanding      UMETA(DisplayName = "Perfect Landing"),
    FoulCommitted       UMETA(DisplayName = "Foul Committed")
};

USTRUCT(BlueprintType)
struct FFELExpressionTrigger
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    EFELGameplayEvent Event = EFELGameplayEvent::ScoreBasket;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    EFELExpression Expression = EFELExpression::Celebrating;

    /** How long the expression lasts before returning to default. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    float Duration = 2.0f;

    /** Blend time into the expression. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    float BlendInTime = 0.2f;

    /** Blend time out of the expression. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    float BlendOutTime = 0.5f;

    /** Priority (higher overrides lower). */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FEL|Expression")
    int32 Priority = 0;
};
