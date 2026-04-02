// Copyright Final Evolution Lab. All Rights Reserved.
// FELCreatorManager.h - Creator Card System Manager
// Phase 2: Creator Card System + Athletes

#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "FELCreatorProfile.h"
#include "FELCreatorManager.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCreatorProfileLoaded, const FCreatorProfile&, Profile);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOnCreatorSelected, const FString&, CreatorID);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FOnCreatorGalleryUpdated);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FOnCreatorChallengeCompleted, const FString&, CreatorID, const FString&, ChallengeID);

/**
 * UFELCreatorManager - Core subsystem managing all creator profiles,
 * selection, gallery display, and challenge tracking.
 * 
 * This subsystem loads creator data from CreatorProfiles.json and provides
 * Blueprint-callable functions for the Creator Card UI system.
 */
UCLASS()
class FINALEVOLUTIONLAB_API UFELCreatorManager : public UGameInstanceSubsystem
{
    GENERATED_BODY()

public:
    // ── Lifecycle ────────────────────────────────────────────────────────

    virtual void Initialize(FSubsystemCollectionBase& Collection) override;
    virtual void Deinitialize() override;
    virtual bool ShouldCreateSubsystem(UObject* Outer) const override { return true; }

    // ── Creator Profile Access ───────────────────────────────────────────

    /** Get a creator profile by ID */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    bool GetCreatorProfile(const FString& CreatorID, FCreatorProfile& OutProfile) const;

    /** Get all loaded creator profiles */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorProfile> GetAllCreators() const;

    /** Get only featured creators */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorProfile> GetFeaturedCreators() const;

    /** Get creators filtered by sport */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorProfile> GetCreatorsBySport(const FString& Sport) const;

    /** Get creators filtered by tier */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorProfile> GetCreatorsByTier(ECreatorTier Tier) const;

    /** Get the total number of loaded creators */
    UFUNCTION(BlueprintPure, Category = "FEL|Creators")
    int32 GetCreatorCount() const;

    /** Check if a creator exists */
    UFUNCTION(BlueprintPure, Category = "FEL|Creators")
    bool HasCreator(const FString& CreatorID) const;

    // ── Creator Selection ────────────────────────────────────────────────

    /** Select a creator (for "Play As" or profile view) */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    void SelectCreator(const FString& CreatorID);

    /** Get currently selected creator ID */
    UFUNCTION(BlueprintPure, Category = "FEL|Creators")
    FString GetSelectedCreatorID() const;

    /** Get currently selected creator profile */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    bool GetSelectedCreatorProfile(FCreatorProfile& OutProfile) const;

    // ── Highlights & Content ─────────────────────────────────────────────

    /** Get all highlights for a creator */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorHighlight> GetCreatorHighlights(const FString& CreatorID) const;

    /** Get highlights filtered by type (magic_reveal, dunk, gameplay, etc.) */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorHighlight> GetCreatorHighlightsByType(const FString& CreatorID, const FString& HighlightType) const;

    /** Get signature moves for a creator */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorSignatureMove> GetCreatorSignatureMoves(const FString& CreatorID) const;

    // ── Challenges ───────────────────────────────────────────────────────

    /** Get all challenges for a creator */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    TArray<FCreatorChallenge> GetCreatorChallenges(const FString& CreatorID) const;

    /** Mark a challenge as completed */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    void CompleteChallenge(const FString& CreatorID, const FString& ChallengeID);

    /** Check if a challenge is completed */
    UFUNCTION(BlueprintPure, Category = "FEL|Creators")
    bool IsChallengeCompleted(const FString& CreatorID, const FString& ChallengeID) const;

    /** Get completed challenge count for a creator */
    UFUNCTION(BlueprintPure, Category = "FEL|Creators")
    int32 GetCompletedChallengeCount(const FString& CreatorID) const;

    // ── 3D Model ─────────────────────────────────────────────────────────

    /** Check if a creator has a 3D model */
    UFUNCTION(BlueprintPure, Category = "FEL|Creators")
    bool CreatorHas3DModel(const FString& CreatorID) const;

    /** Get the skeletal mesh path for a creator's 3D model */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    FString GetCreatorModelPath(const FString& CreatorID) const;

    /** Load and return a creator's skeletal mesh (async-friendly) */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    USkeletalMesh* LoadCreatorModel(const FString& CreatorID);

    // ── Dynamic Creator Addition ─────────────────────────────────────────

    /** Add a new creator at runtime (from JSON string) */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    bool AddCreatorFromJSON(const FString& JSONString);

    /** Remove a creator at runtime */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    bool RemoveCreator(const FString& CreatorID);

    /** Reload all creator profiles from disk */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    void ReloadCreatorProfiles();

    // ── Serialization ────────────────────────────────────────────────────

    /** Export all creator data as JSON string */
    UFUNCTION(BlueprintCallable, Category = "FEL|Creators")
    FString ExportCreatorsAsJSON() const;

    // ── Delegates ────────────────────────────────────────────────────────

    UPROPERTY(BlueprintAssignable, Category = "FEL|Creators")
    FOnCreatorProfileLoaded OnCreatorProfileLoaded;

    UPROPERTY(BlueprintAssignable, Category = "FEL|Creators")
    FOnCreatorSelected OnCreatorSelected;

    UPROPERTY(BlueprintAssignable, Category = "FEL|Creators")
    FOnCreatorGalleryUpdated OnCreatorGalleryUpdated;

    UPROPERTY(BlueprintAssignable, Category = "FEL|Creators")
    FOnCreatorChallengeCompleted OnCreatorChallengeCompleted;

private:
    /** Load profiles from JSON file */
    bool LoadProfilesFromJSON(const FString& FilePath);

    /** Parse a single creator profile from JSON object */
    bool ParseCreatorProfile(const TSharedPtr<FJsonObject>& JsonObj, FCreatorProfile& OutProfile);

    /** All loaded creator profiles, keyed by CreatorID */
    UPROPERTY()
    TMap<FString, FCreatorProfile> CreatorProfiles;

    /** Currently selected creator ID */
    FString SelectedCreatorID;

    /** Completed challenges (CreatorID::ChallengeID) */
    TSet<FString> CompletedChallenges;

    /** Cached skeletal meshes for 3D models */
    UPROPERTY()
    TMap<FString, USkeletalMesh*> CachedModels;

    /** Featured creator order */
    TArray<FString> FeaturedOrder;
};
