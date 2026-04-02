// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorProfile.h - Creator Profile Data Structures
// Part of Phase 2: Creator Card System

#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "FELCreatorProfile.generated.h"

/**
 * Represents a single signature move or highlight for a creator.
 */
USTRUCT(BlueprintType)
struct FCreatorSignatureMove
{
    GENERATED_BODY()

    /** Unique identifier for the move */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString MoveID;

    /** Display name of the signature move */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString DisplayName;

    /** Description of the move */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Description;

    /** Animation montage path for this move */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString AnimMontage;

    /** Difficulty rating (1-5) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator", meta = (ClampMin = 1, ClampMax = 5))
    int32 DifficultyRating = 3;

    /** Category: dunk, crossover, fadeaway, etc. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Category;
};

/**
 * Represents a highlight video or media clip for a creator.
 */
USTRUCT(BlueprintType)
struct FCreatorHighlight
{
    GENERATED_BODY()

    /** Unique identifier */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString HighlightID;

    /** Display title */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Title;

    /** Path to the video file */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString VideoPath;

    /** Thumbnail image path */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString ThumbnailPath;

    /** Duration in seconds */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    float DurationSeconds = 0.f;

    /** Location where the highlight was filmed */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Location;

    /** Type: magic_reveal, dunk, training, gameplay */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString HighlightType;
};

/**
 * Creator stat entry (key-value pair for flexible stats).
 */
USTRUCT(BlueprintType)
struct FCreatorStat
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString StatName;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString StatValue;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString IconPath;
};

/**
 * Social media link for a creator.
 */
USTRUCT(BlueprintType)
struct FCreatorSocialLink
{
    GENERATED_BODY()

    /** Platform name: instagram, twitter, youtube, tiktok */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Platform;

    /** Handle/username */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Handle;

    /** Full URL */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString URL;

    /** Follower count (for display) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    int32 FollowerCount = 0;
};

/**
 * Creator challenge definition.
 */
USTRUCT(BlueprintType)
struct FCreatorChallenge
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString ChallengeID;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString DisplayName;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Description;

    /** Game mode this challenge belongs to */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString GameMode;

    /** Difficulty: Easy, Medium, Hard, Legendary */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Difficulty;

    /** Reward description */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FString Reward;

    /** Required score or condition to complete */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    int32 RequiredScore = 0;
};

/**
 * Enum for creator status/tier.
 */
UENUM(BlueprintType)
enum class ECreatorTier : uint8
{
    Featured     UMETA(DisplayName = "Featured"),
    Verified     UMETA(DisplayName = "Verified"),
    Community    UMETA(DisplayName = "Community"),
    ComingSoon   UMETA(DisplayName = "Coming Soon")
};

/**
 * Enum for creator card display style.
 */
UENUM(BlueprintType)
enum class ECreatorCardStyle : uint8
{
    Standard     UMETA(DisplayName = "Standard"),
    Premium      UMETA(DisplayName = "Premium"),
    Legendary    UMETA(DisplayName = "Legendary"),
    Holographic  UMETA(DisplayName = "Holographic")
};

/**
 * Complete creator profile - the main data structure for a creator.
 */
USTRUCT(BlueprintType)
struct FCreatorProfile
{
    GENERATED_BODY()

    // ── Identity ──────────────────────────────────────────────────────

    /** Unique creator identifier (e.g., "elijah_bonds") */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString CreatorID;

    /** Display name */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString DisplayName;

    /** Short tagline */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString Tagline;

    /** Full biography */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString Bio;

    /** Home location */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString Location;

    /** Primary sport */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString PrimarySport;

    /** Position played */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString Position;

    /** Height display string */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString Height;

    /** Weight display string */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Identity")
    FString Weight;

    // ── Visual Assets ─────────────────────────────────────────────────

    /** Circular profile image path (512x512) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Visuals")
    FString ProfileImagePath;

    /** Banner image path (1920x400) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Visuals")
    FString BannerImagePath;

    /** Card background image */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Visuals")
    FString CardBackgroundPath;

    /** 3D player model path (skeletal mesh) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Visuals")
    FString PlayerModelPath;

    /** Whether this creator has a 3D model available */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Visuals")
    bool bHas3DModel = false;

    // ── Content ────────────────────────────────────────────────────────

    /** Highlight videos */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Content")
    TArray<FCreatorHighlight> Highlights;

    /** Signature moves */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Content")
    TArray<FCreatorSignatureMove> SignatureMoves;

    /** Creator challenges */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Content")
    TArray<FCreatorChallenge> Challenges;

    // ── Stats ──────────────────────────────────────────────────────────

    /** Flexible stats display */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Stats")
    TArray<FCreatorStat> Stats;

    // ── Social ─────────────────────────────────────────────────────────

    /** Social media links */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Social")
    TArray<FCreatorSocialLink> SocialLinks;

    // ── Meta ───────────────────────────────────────────────────────────

    /** Creator tier */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Meta")
    ECreatorTier Tier = ECreatorTier::Community;

    /** Card display style */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Meta")
    ECreatorCardStyle CardStyle = ECreatorCardStyle::Standard;

    /** Whether this creator is currently featured */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Meta")
    bool bIsFeatured = false;

    /** Whether the player can play as this creator */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Meta")
    bool bIsPlayable = false;

    /** Sort order for gallery display */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Meta")
    int32 SortOrder = 0;

    /** Date added (ISO 8601) */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Meta")
    FString DateAdded;
};

/**
 * Data table row for creator profiles.
 */
USTRUCT(BlueprintType)
struct FCreatorProfileRow : public FTableRowBase
{
    GENERATED_BODY()

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Creator")
    FCreatorProfile Profile;
};
